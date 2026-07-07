import torch
import torch.nn as nn
from models.crf import CRF

def get_crf_mask(attention_mask, labels=None):
    """
    Computes a boolean mask indicating active tokens for sequence labeling.
    Masks out special tokens (like [CLS], [SEP]) and padded tokens.
    """
    if labels is not None:
        # Ignore subword padding (coded as -100) and respect attention mask
        return (labels != -100) & (attention_mask.bool())
    else:
        mask = attention_mask.bool().clone()
        batch_size, seq_len = mask.size()
        for b in range(batch_size):
            # Mask out the CLS token (index 0)
            mask[b, 0] = False
            active_indices = torch.where(mask[b])[0]
            if len(active_indices) > 0:
                # Mask out the trailing SEP token
                last_idx = active_indices[-1].item()
                mask[b, last_idx] = False
        return mask

class BiLSTM_CRF(nn.Module):
    """
    A Bidirectional LSTM sequence tagger with a CRF classification layer.
    """
    def __init__(self, embedding_module, num_tags, embedding_dim=768, hidden_dim=128, is_transformer=True, fine_tune=True):
        super(BiLSTM_CRF, self).__init__()
        self.embedding_module = embedding_module
        self.is_transformer = is_transformer
        self.fine_tune = fine_tune
        
        # Bidirectional LSTM layer
        self.lstm = nn.LSTM(
            embedding_dim, 
            hidden_dim // 2, 
            num_layers=1, 
            bidirectional=True, 
            batch_first=True
        )
        self.dropout = nn.Dropout(0.3)
        self.hidden2tag = nn.Linear(hidden_dim, num_tags)
        self.crf = CRF(num_tags)

    def get_lstm_features(self, input_ids, attention_mask=None):
        """
        Extracts contextualized sequence features via embeddings and BiLSTM layers.
        """
        if self.is_transformer:
            # Handle Transformer outputs
            if self.fine_tune:
                embeds = self.embedding_module(input_ids, attention_mask=attention_mask).last_hidden_state
            else:
                with torch.no_grad():
                    embeds = self.embedding_module(input_ids, attention_mask=attention_mask).last_hidden_state
        else:
            # Handle Static Embedding matrix (GloVe)
            if self.fine_tune:
                embeds = self.embedding_module(input_ids)
            else:
                with torch.no_grad():
                    embeds = self.embedding_module(input_ids)
                    
        lstm_out, _ = self.lstm(self.dropout(embeds))
        return self.hidden2tag(self.dropout(lstm_out))

    def _get_active_features(self, feats, mask, tags=None):
        """
        Aligns raw sequences by filtering out pad / masked tokens (-100 labels)
        and creating a compact, batch-padded tensor for input to the CRF layer.
        """
        batch_size, seq_len, num_tags = feats.size()
        active_feats_list = []
        active_tags_list = []
        max_active_len = 0

        # Extract only active elements per batch item
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
        
        # Pad filtered features to the max active sequence length in current batch
        for b in range(batch_size):
            b_len = active_feats_list[b].size(0)
            pad_len = max_active_len - b_len
            
            if pad_len > 0:
                b_feats_pad = torch.cat([active_feats_list[b], torch.zeros(pad_len, num_tags, device=feats.device)], dim=0)
                b_mask_pad = torch.cat([torch.ones(b_len, device=mask.device), torch.zeros(pad_len, device=mask.device)], dim=0)
                padded_feats.append(b_feats_pad)
                padded_masks.append(b_mask_pad)
                if tags is not None:
                    b_tags_pad = torch.cat([active_tags_list[b], torch.zeros(pad_len, dtype=torch.long, device=tags.device)], dim=0)
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
        """
        Forward step calculating negative log-likelihood (NLL) loss.
        """
        feats = self.get_lstm_features(input_ids, attention_mask)
        crf_mask = get_crf_mask(attention_mask, labels)
        
        # Replace padding index of -100 to avoid gathering errors in CRF
        clean_labels = labels.clone()
        clean_labels[clean_labels == -100] = 0
        
        padded_feats, padded_masks, padded_tags = self._get_active_features(feats, crf_mask, clean_labels)
        return self.crf(padded_feats, padded_tags, padded_masks)

    def decode(self, input_ids, attention_mask, labels=None):
        """
        Viterbi decode step to output label predictions sequence.
        """
        feats = self.get_lstm_features(input_ids, attention_mask)
        crf_mask = get_crf_mask(attention_mask, labels)
        padded_feats, padded_masks = self._get_active_features(feats, crf_mask)
        return self.crf.decode(padded_feats, padded_masks)

class BiLSTM_CRF_NER(BiLSTM_CRF):
    """
    BiLSTM-CRF sequence tagger configured to fine-tune contextual Hugging Face model embeddings.
    """
    def __init__(self, embedding_model, num_tags, embedding_dim=768, hidden_dim=128, fine_tune=True):
        super(BiLSTM_CRF_NER, self).__init__(
            embedding_module=embedding_model, 
            num_tags=num_tags, 
            embedding_dim=embedding_dim, 
            hidden_dim=hidden_dim, 
            is_transformer=True, 
            fine_tune=fine_tune
        )

class BiLSTM_CRF_GloVe(BiLSTM_CRF):
    """
    BiLSTM-CRF sequence tagger utilizing static GloVe word vectors.
    """
    def __init__(self, num_tags, embedding_layer, embedding_dim=300, hidden_dim=128):
        super(BiLSTM_CRF_GloVe, self).__init__(
            embedding_module=embedding_layer, 
            num_tags=num_tags, 
            embedding_dim=embedding_dim, 
            hidden_dim=hidden_dim, 
            is_transformer=False, 
            fine_tune=True
        )
