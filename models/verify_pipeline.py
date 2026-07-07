import torch
import torch.nn as nn
import numpy as np

# --- 1. CRF Implementation ---
class CRF(nn.Module):
    def __init__(self, num_tags):
        super(CRF, self).__init__()
        self.num_tags = num_tags
        self.transitions = nn.Parameter(torch.randn(num_tags, num_tags))
        self.START_TAG = num_tags - 2
        self.STOP_TAG = num_tags - 1

        # Prevent transitioning to START and from STOP
        self.transitions.data[self.START_TAG, :] = -10000.0
        self.transitions.data[:, self.STOP_TAG] = -10000.0

    def _forward_alg(self, feats, mask):
        batch_size, seq_len, num_tags = feats.size()
        init_alphas = torch.full((batch_size, num_tags), -10000.0, device=feats.device)
        init_alphas[:, self.START_TAG] = 0.0
        forward_var = init_alphas

        for i in range(seq_len):
            feat = feats[:, i, :]
            mask_i = mask[:, i].unsqueeze(-1)
            next_tag_var = forward_var.unsqueeze(1) + self.transitions.unsqueeze(0) + feat.unsqueeze(2)
            alpha_t = torch.logsumexp(next_tag_var, dim=2)
            forward_var = torch.where(mask_i.bool(), alpha_t, forward_var)

        terminal_vars = forward_var + self.transitions[self.STOP_TAG].unsqueeze(0)
        alpha = torch.logsumexp(terminal_vars, dim=1)
        return alpha

    def _score_sentence(self, feats, tags, mask):
        batch_size, seq_len, num_tags = feats.size()
        score = torch.zeros(batch_size, device=feats.device)

        start_tags = torch.full((batch_size, 1), self.START_TAG, dtype=torch.long, device=feats.device)
        tags = torch.cat([start_tags, tags], dim=1)

        for i in range(seq_len):
            mask_i = mask[:, i]
            feat = feats[:, i, :]
            emit_score = feat.gather(1, tags[:, i+1].unsqueeze(1)).squeeze(1)
            trans_score = self.transitions[tags[:, i+1], tags[:, i]]
            score = score + (emit_score + trans_score) * mask_i

        last_indices = mask.sum(dim=1).long()
        last_tags = tags.gather(1, last_indices.unsqueeze(1)).squeeze(1)
        trans_score = self.transitions[self.STOP_TAG, last_tags]
        score = score + trans_score
        return score

    def forward(self, feats, tags, mask):
        forward_score = self._forward_alg(feats, mask)
        gold_score = self._score_sentence(feats, tags, mask)
        return torch.mean(forward_score - gold_score)

    def decode(self, feats, mask):
        batch_size, seq_len, num_tags = feats.size()
        init_vvars = torch.full((batch_size, num_tags), -10000.0, device=feats.device)
        init_vvars[:, self.START_TAG] = 0.0
        forward_var = init_vvars
        backpointers = []

        for i in range(seq_len):
            feat = feats[:, i, :]
            mask_i = mask[:, i].unsqueeze(-1)
            next_tag_var = forward_var.unsqueeze(1) + self.transitions.unsqueeze(0)
            max_vars, bptrs = torch.max(next_tag_var, dim=2)
            viterbi_vars = max_vars + feat
            forward_var = torch.where(mask_i.bool(), viterbi_vars, forward_var)
            backpointers.append(bptrs)

        terminal_vars = forward_var + self.transitions[self.STOP_TAG].unsqueeze(0)
        best_tag_ids = torch.argmax(terminal_vars, dim=1)

        best_paths = []
        for b in range(batch_size):
            best_tag_id = best_tag_ids[b].item()
            path = [best_tag_id]
            seq_len_b = int(mask[b].sum().item())
            if seq_len_b == 0:
                best_paths.append([])
                continue
            for bptrs_t in reversed(backpointers[:seq_len_b]):
                best_tag_id = bptrs_t[b, best_tag_id].item()
                path.append(best_tag_id)
            start = path.pop()
            assert start == self.START_TAG, f"CRF decode: expected START_TAG boundary but got {start}"
            path.reverse()
            best_paths.append(path)

        return best_paths


# --- 2. Helper for CRF Mask Retrieval ---
def get_crf_mask(attention_mask, labels=None):
    if labels is not None:
        return (labels != -100) & (attention_mask.bool())
    else:
        # Inference: mask out CLS (index 0) and SEP (last active index)
        mask = attention_mask.bool().clone()
        batch_size, seq_len = mask.size()
        for b in range(batch_size):
            mask[b, 0] = False
            active_indices = torch.where(mask[b])[0]
            if len(active_indices) > 0:
                last_idx = active_indices[-1].item()
                mask[b, last_idx] = False
        return mask


# --- 3. Unified BiLSTM_CRF Tagger ---
class BiLSTM_CRF(nn.Module):
    def __init__(self, embedding_module, num_tags, embedding_dim=768, hidden_dim=128, is_transformer=True, fine_tune=True):
        super(BiLSTM_CRF, self).__init__()
        self.embedding_module = embedding_module
        self.is_transformer = is_transformer
        self.fine_tune = fine_tune
        self.lstm = nn.LSTM(embedding_dim, hidden_dim // 2, num_layers=1, bidirectional=True, batch_first=True)
        self.dropout = nn.Dropout(0.3)
        self.hidden2tag = nn.Linear(hidden_dim, num_tags)
        self.crf = CRF(num_tags)

    def get_lstm_features(self, input_ids, attention_mask):
        if self.is_transformer:
            if self.fine_tune:
                embeds = self.embedding_module(input_ids, attention_mask=attention_mask).last_hidden_state
            else:
                with torch.no_grad():
                    embeds = self.embedding_module(input_ids, attention_mask=attention_mask).last_hidden_state
        else:
            if self.fine_tune:
                embeds = self.embedding_module(input_ids)
            else:
                with torch.no_grad():
                    embeds = self.embedding_module(input_ids)
        
        lstm_out, _ = self.lstm(self.dropout(embeds))
        return self.hidden2tag(self.dropout(lstm_out))

    def _get_active_features(self, feats, mask, tags=None):
        batch_size, seq_len, num_tags = feats.size()
        active_feats_list = []
        active_tags_list = []
        max_active_len = 0

        for b in range(batch_size):
            b_mask = mask[b].bool()
            b_feats = feats[b][b_mask]
            active_feats_list.append(b_feats)
            max_active_len = max(max_active_len, b_feats.size(0))
            if tags is not None:
                active_tags_list.append(tags[b][b_mask])

        if max_active_len == 0:
            max_active_len = 1

        padded_feats = []
        padded_masks = []
        padded_tags = []
        
        for b in range(batch_size):
            b_len = active_feats_list[b].size(0)
            pad_len = max_active_len - b_len
            
            if pad_len > 0:
                b_feats_pad = torch.cat([
                    active_feats_list[b],
                    torch.zeros(pad_len, num_tags, device=feats.device)
                ], dim=0)
                b_mask_pad = torch.cat([
                    torch.ones(b_len, device=mask.device),
                    torch.zeros(pad_len, device=mask.device)
                ], dim=0)
                padded_feats.append(b_feats_pad)
                padded_masks.append(b_mask_pad)
                if tags is not None:
                    b_tags_pad = torch.cat([
                        active_tags_list[b],
                        torch.zeros(pad_len, dtype=torch.long, device=tags.device)
                    ], dim=0)
                    padded_tags.append(b_tags_pad)
            else:
                padded_feats.append(active_feats_list[b])
                padded_masks.append(torch.ones(b_len, device=mask.device))
                if tags is not None:
                    padded_tags.append(active_tags_list[b])

        padded_feats = torch.stack(padded_feats, dim=0)
        padded_masks = torch.stack(padded_masks, dim=0)
        
        if tags is not None:
            padded_tags = torch.stack(padded_tags, dim=0)
            return padded_feats, padded_masks, padded_tags
        return padded_feats, padded_masks

    def forward(self, input_ids, attention_mask, labels):
        feats = self.get_lstm_features(input_ids, attention_mask)
        crf_mask = get_crf_mask(attention_mask, labels)
        
        clean_labels = labels.clone()
        clean_labels[clean_labels == -100] = 0
        
        padded_feats, padded_masks, padded_tags = self._get_active_features(feats, crf_mask, clean_labels)
        loss = self.crf(padded_feats, padded_tags, padded_masks)
        return loss

    def decode(self, input_ids, attention_mask, labels=None):
        feats = self.get_lstm_features(input_ids, attention_mask)
        crf_mask = get_crf_mask(attention_mask, labels)
        padded_feats, padded_masks = self._get_active_features(feats, crf_mask)
        padded_paths = self.crf.decode(padded_feats, padded_masks)
        return padded_paths


# --- Verification Tests ---
def test_pipeline():
    print("[*] Running Pipeline Verification Tests...")
    
    # 1. Mock Transformer Embedding
    class MockTransformer(nn.Module):
        def __init__(self):
            super().__init__()
            self.emb = nn.Embedding(100, 768)
        def forward(self, input_ids, attention_mask=None):
            class Out:
                def __init__(self, val):
                    self.last_hidden_state = val
            return Out(self.emb(input_ids))

    num_tags = 9
    model = BiLSTM_CRF(
        embedding_module=MockTransformer(),
        num_tags=num_tags,
        embedding_dim=768,
        hidden_dim=32,
        is_transformer=True
    )

    # 2. Mock inputs (Batch size = 2, Seq len = 6)
    # [CLS], token1, token2, [SEP], [PAD], [PAD]
    input_ids = torch.tensor([
        [1, 10, 11, 2, 0, 0],
        [1, 15, 20, 2, 0, 0]
    ], dtype=torch.long)
    
    attention_mask = torch.tensor([
        [1, 1, 1, 1, 0, 0],
        [1, 1, 1, 1, 0, 0]
    ], dtype=torch.long)
    
    # Labels with -100 at special/pad positions
    labels = torch.tensor([
        [-100, 3, 4, -100, -100, -100],
        [-100, 0, 3, -100, -100, -100]
    ], dtype=torch.long)

    # 3. Test forward pass
    loss = model(input_ids, attention_mask, labels)
    print(f"[OK] Forward pass successful. Loss: {loss.item():.4f}")
    assert loss.item() > 0, "Loss should be positive scalar"

    # 4. Test decode (evaluation mode - with labels)
    paths = model.decode(input_ids, attention_mask, labels)
    print(f"[OK] Decode (eval) successful. Path lengths: {[len(p) for p in paths]}")
    for idx, path in enumerate(paths):
        num_active = int((labels[idx] != -100).sum().item())
        assert len(path) == num_active, f"Decoded path length {len(path)} != gold active length {num_active}"

    # 5. Test decode (inference mode - without labels)
    inf_paths = model.decode(input_ids, attention_mask)
    print(f"[OK] Decode (inference) successful. Path lengths: {[len(p) for p in inf_paths]}")
    for idx, path in enumerate(inf_paths):
        # Without labels, we expect active tokens excluding CLS (index 0) and SEP (index 3)
        expected_len = int(attention_mask[idx].sum().item()) - 2
        assert len(path) == expected_len, f"Inference path length {len(path)} != expected active length {expected_len}"

    print("\n[ALL TESTS PASSED SUCCESSFULLY!]")

if __name__ == '__main__':
    test_pipeline()
