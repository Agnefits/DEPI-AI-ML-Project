import torch
import torch.nn as nn

class CRF(nn.Module):
    """
    Conditional Random Field (CRF) layer module.
    Calculates sequence joint transition likelihoods and performs
    Viterbi decoding for optimal tag sequence extraction.
    """
    def __init__(self, num_tags):
        super(CRF, self).__init__()
        self.num_tags = num_tags
        # Transitions matrix transitions[i, j] is the score of transitioning from tag j to tag i.
        self.transitions = nn.Parameter(torch.randn(num_tags, num_tags))
        
        # Add START and STOP boundary tags to transitions constraints
        self.START_TAG = num_tags - 2
        self.STOP_TAG = num_tags - 1
        
        # Enforce boundary constraints: cannot transition to START, and cannot transition from STOP.
        self.transitions.data[self.START_TAG, :] = -10000.0
        self.transitions.data[:, self.STOP_TAG] = -10000.0

    def _forward_alg(self, feats, mask):
        """
        Computes the partition function (total score of all paths) using the forward algorithm.
        """
        batch_size, seq_len, num_tags = feats.size()
        init_alphas = torch.full((batch_size, num_tags), -10000.0, device=feats.device)
        init_alphas[:, self.START_TAG] = 0.0
        forward_var = init_alphas

        for i in range(seq_len):
            feat = feats[:, i, :]
            mask_i = mask[:, i].unsqueeze(-1)
            
            # Broadcast transition scores across tag states
            next_tag_var = forward_var.unsqueeze(1) + self.transitions.unsqueeze(0) + feat.unsqueeze(2)
            alpha_t = torch.logsumexp(next_tag_var, dim=2)
            
            # Apply mask to preserve values for masked-out steps (padding)
            forward_var = torch.where(mask_i.bool(), alpha_t, forward_var)

        terminal_vars = forward_var + self.transitions[self.STOP_TAG].unsqueeze(0)
        alpha = torch.logsumexp(terminal_vars, dim=1)
        return alpha

    def _score_sentence(self, feats, tags, mask):
        """
        Computes the score of the gold-standard sequence paths.
        """
        batch_size, seq_len, num_tags = feats.size()
        score = torch.zeros(batch_size, device=feats.device)
        start_tags = torch.full((batch_size, 1), self.START_TAG, dtype=torch.long, device=feats.device)
        tags = torch.cat([start_tags, tags], dim=1)

        for i in range(seq_len):
            mask_i = mask[:, i]
            feat = feats[:, i, :]
            
            # Emit score for gold tag at step i
            emit_score = feat.gather(1, tags[:, i+1].unsqueeze(1)).squeeze(1)
            # Transition score from tag at step i to step i+1
            trans_score = self.transitions[tags[:, i+1], tags[:, i]]
            
            score = score + (emit_score + trans_score) * mask_i

        # Transition to STOP tag at the end of the unmasked sequence
        last_indices = mask.sum(dim=1).long()
        last_tags = tags.gather(1, last_indices.unsqueeze(1)).squeeze(1)
        trans_score = self.transitions[self.STOP_TAG, last_tags]
        score = score + trans_score
        return score

    def forward(self, feats, tags, mask):
        """
        Computes the negative log-likelihood loss for sequence classification.
        """
        forward_score = self._forward_alg(feats, mask)
        gold_score = self._score_sentence(feats, tags, mask)
        return torch.mean(forward_score - gold_score)

    def decode(self, feats, mask):
        """
        Performs Viterbi decoding to search for the highest-scoring sequence of tags.
        """
        batch_size, seq_len, num_tags = feats.size()
        init_vvars = torch.full((batch_size, num_tags), -10000.0, device=feats.device)
        init_vvars[:, self.START_TAG] = 0.0
        forward_var = init_vvars
        backpointers = []

        for i in range(seq_len):
            feat = feats[:, i, :]
            mask_i = mask[:, i].unsqueeze(-1)
            
            # Compute best transition path to each tag at current step
            next_tag_var = forward_var.unsqueeze(1) + self.transitions.unsqueeze(0)
            max_vars, bptrs = torch.max(next_tag_var, dim=2)
            viterbi_vars = max_vars + feat
            
            forward_var = torch.where(mask_i.bool(), viterbi_vars, forward_var)
            backpointers.append(bptrs)

        # Transition to STOP tag
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
            
            # Traverse backpointers in reverse order to reconstruct path
            for bptrs_t in reversed(backpointers[:seq_len_b]):
                best_tag_id = bptrs_t[b, best_tag_id].item()
                path.append(best_tag_id)
                
            start = path.pop()
            assert start == self.START_TAG
            path.reverse()
            best_paths.append(path)
        return best_paths
