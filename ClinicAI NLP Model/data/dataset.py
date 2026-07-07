import torch
from torch.utils.data import Dataset
from data.parser import clean_text, align_tokens_and_tags
from nltk.tokenize import RegexpTokenizer

class ClinicalDataset(Dataset):
    """
    PyTorch Dataset for fine-tuning Transformer (e.g. BioBERT) model
    for NER and multi-label classification.
    """
    def __init__(self, data_list, tokenizer, tag_to_ix, label_list, max_len=512):
        self.data = data_list
        self.tokenizer = tokenizer
        self.tag_to_ix = tag_to_ix
        # Build mapping for ICD/MeSH codes
        self.label_to_ix = {lbl: idx for idx, lbl in enumerate(label_list)}
        self.max_len = max_len

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        item = self.data[idx]
        text = clean_text(item["text"])
        
        # Tokenize and align labels
        input_ids, attention_mask, labels = align_tokens_and_tags(
            text, item["entities"], self.tokenizer, self.tag_to_ix, self.max_len
        )

        # Multi-label diagnostic code targets (1.0 active, 0.0 inactive)
        icd_labels = [0.0] * len(self.label_to_ix)
        for code in item["icd10"]:
            if code in self.label_to_ix:
                icd_labels[self.label_to_ix[code]] = 1.0

        # Perform padding up to max_len
        pad_len = self.max_len - len(input_ids)
        if pad_len > 0:
            input_ids += [self.tokenizer.pad_token_id] * pad_len
            attention_mask += [0] * pad_len
            labels += [-100] * pad_len
        else:
            # Enforce max length truncation
            input_ids = input_ids[:self.max_len]
            attention_mask = attention_mask[:self.max_len]
            labels = labels[:self.max_len]

        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.tensor(attention_mask, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
            "icd_labels": torch.tensor(icd_labels, dtype=torch.float)
        }

class ClinicalWordDataset(Dataset):
    """
    PyTorch Dataset for GloVe Word-level embeddings BiLSTM-CRF sequence tagging.
    """
    def __init__(self, data_list, word_to_ix, tag_to_ix, max_len=128):
        self.data = data_list
        self.word_to_ix = word_to_ix
        self.tag_to_ix = tag_to_ix
        self.max_len = max_len
        # Shared word tokenizer separating punctuation
        self.tokenizer = RegexpTokenizer(r'\w+|[^\w\s]')

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        item = self.data[idx]
        text = clean_text(item["text"])
        
        # Extract token spans on raw character index level
        spans = list(self.tokenizer.span_tokenize(text))[:self.max_len]
        tokens = [text[s:e] for s, e in spans]
        
        # Convert tokens to index IDs
        input_ids = [self.word_to_ix.get(t.lower(), self.word_to_ix["<UNK>"]) for t in tokens]
        attention_mask = [1] * len(input_ids)
        labels = [self.tag_to_ix["O"]] * len(input_ids)
        
        # Map raw character spans of entities to token index tags
        for ent in item.get("entities", []):
            start_char, end_char = ent["start"], ent["end"]
            ent_type = ent["type"]
            b_idx = self.tag_to_ix.get(f"B-{ent_type}", 0)
            i_idx = self.tag_to_ix.get(f"I-{ent_type}", 0)
            
            first = True
            for w_idx, (s, e) in enumerate(spans):
                if s >= start_char and e <= end_char:
                    if first:
                        labels[w_idx] = b_idx
                        first = False
                    else:
                        labels[w_idx] = i_idx
                        
        # Pad sequences up to max_len
        pad_len = self.max_len - len(input_ids)
        if pad_len > 0:
            input_ids += [0] * pad_len  # 0 maps to <PAD>
            attention_mask += [0] * pad_len
            labels += [-100] * pad_len
        else:
            input_ids = input_ids[:self.max_len]
            attention_mask = attention_mask[:self.max_len]
            labels = labels[:self.max_len]
            
        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.tensor(attention_mask, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long)
        }

class ClinicalCNNDataset(Dataset):
    """
    PyTorch Dataset for CNN ICD-10 multi-label text classification.
    """
    def __init__(self, data_list, word_to_ix, label_list, max_len=128):
        self.data = data_list
        self.word_to_ix = word_to_ix
        self.label_to_ix = {lbl: idx for idx, lbl in enumerate(label_list)}
        self.max_len = max_len
        self.tokenizer = RegexpTokenizer(r'\w+|[^\w\s]')

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        item = self.data[idx]
        text = clean_text(item["text"])
        tokens = self.tokenizer.tokenize(text.lower())[:self.max_len]
        input_ids = [self.word_to_ix.get(w, self.word_to_ix["<UNK>"]) for w in tokens]

        # Padding
        pad_len = self.max_len - len(input_ids)
        if pad_len > 0:
            input_ids += [0] * pad_len  # 0 maps to <PAD>
        else:
            input_ids = input_ids[:self.max_len]

        # Multi-label diagnostic target array
        icd_labels = [0.0] * len(self.label_to_ix)
        for code in item["icd10"]:
            if code in self.label_to_ix:
                icd_labels[self.label_to_ix[code]] = 1.0

        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "labels": torch.tensor(icd_labels, dtype=torch.float)
        }
