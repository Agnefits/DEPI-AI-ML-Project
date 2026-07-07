import torch
import torch.nn as nn
import cv2
import numpy as np
from pathlib import Path
from typing import Dict
import json
import re
from transformers import AutoTokenizer, AutoModel

# استدعاء الأساسيات من الملف اللي لسه عاملينه
from Model_Core import Config, ChestXrayModel, get_inference_transforms

class APIInferenceManager:
    def __init__(self, model_path: str):
        self.cfg = Config()
        self.device = torch.device("cpu") # تشغيل إجباري على CPU لتناسب إمكانيات الجهاز
        
        # 1. تعريف الموديل
        self.model = ChestXrayModel(self.cfg).to(self.device)
        self.model.eval()
        
        # 2. تحميل الأوزان بأمان
        if Path(model_path).exists():
            try:
                globals_to_add = [np.dtype]
                if hasattr(np, "dtypes"):
                    for name in dir(np.dtypes):
                        attr = getattr(np.dtypes, name)
                        if isinstance(attr, type):
                            globals_to_add.append(attr)
                if hasattr(np, "_core") and hasattr(np._core, "multiarray"):
                    globals_to_add.append(np._core.multiarray.scalar)
                elif hasattr(np, "core") and hasattr(np.core, "multiarray"):
                    globals_to_add.append(np.core.multiarray.scalar)
                torch.serialization.add_safe_globals(globals_to_add)
            except Exception:
                pass
            # weights_only=True لحماية الـ API من ثغرات الـ Pickle 
            ckpt = torch.load(model_path, map_location=self.device, weights_only=True)
            # استخراج أوزان الـ EMA[cite: 1]
            self.model.load_state_dict(ckpt.get("ema", ckpt.get("model", ckpt))) 
        else:
            raise FileNotFoundError(f"Model weights not found at: {model_path}")
            
        # 3. إعداد الـ Thresholds (تقدر تعدلها بالأرقام المحسنة من Youden's J لاحقاً)[cite: 1]
        self.thresholds = np.full(self.cfg.NUM_CLASSES, 0.5)
        
        # 4. تجهيز الـ Transforms الخاص بـ Albumentations[cite: 1]
        self.transform = get_inference_transforms(self.cfg)

    def predict_from_bytes(self, image_bytes: bytes) -> Dict:
        # تحويل الصورة القادمة من الـ API إلى مصفوفة قابلة للقراءة
        np_arr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)
        
        if img is None:
            raise ValueError("Invalid image format or corrupted file.")
            
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
        
        # تطبيق المعالجة وتحويلها لـ Tensor
        tensor = self.transform(image=img)["image"].unsqueeze(0).to(self.device)
        
        # المعالجة واستخراج التوقعات
        with torch.no_grad():
            logits = self.model(tensor)
            probs = torch.sigmoid(logits).numpy().squeeze()
            
        predictions = (probs >= self.thresholds).astype(int)
        detected = [
            {"label": cls, "probability": round(float(prob), 4)}
            for cls, pred, prob in zip(self.cfg.CLASSES, predictions, probs)
            if pred
        ]
        
        return {
            "probabilities": dict(zip(self.cfg.CLASSES, probs.tolist())),
            "predictions": dict(zip(self.cfg.CLASSES, predictions.tolist())),
            "detected_labels": detected if detected else [{"label": "No Finding", "probability": 0.0}]
        }

# تهيئة الـ Manager (تأكد إن مسار الموديل صحيح)
ai_manager = APIInferenceManager("checkpoint/CV/best_model.pth")

# ==================== NLP CLINICAL NOTE ANALYSIS SETUP ====================

tag_to_ix = {
    "O": 0,
    "B-Chemical": 1, "I-Chemical": 2,
    "B-Disease": 3, "I-Disease": 4,
    "B-Gene": 5, "I-Gene": 6,
    "<START>": 7, "<STOP>": 8
}
ix_to_tag = {i: tag for tag, i in tag_to_ix.items()}

def clean_text(text: str) -> str:
    return re.sub(r'\s+', ' ', text).strip()

def tokenize_words(text: str) -> list[str]:
    # Match alphanumeric words or single punctuation characters (same as NLTK's RegexpTokenizer(r'\w+|[^\w\s]'))
    return re.findall(r'\w+|[^\w\s]', text)

class CRF(nn.Module):
    def __init__(self, num_tags):
        super(CRF, self).__init__()
        self.num_tags = num_tags
        self.transitions = nn.Parameter(torch.randn(num_tags, num_tags))
        self.START_TAG = num_tags - 2
        self.STOP_TAG = num_tags - 1
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
            assert start == self.START_TAG
            path.reverse()
            best_paths.append(path)
        return best_paths

def get_crf_mask(attention_mask, labels=None):
    if labels is not None:
        return (labels != -100) & (attention_mask.bool())
    else:
        mask = attention_mask.bool().clone()
        batch_size, seq_len = mask.size()
        for b in range(batch_size):
            mask[b, 0] = False
            active_indices = torch.where(mask[b])[0]
            if len(active_indices) > 0:
                last_idx = active_indices[-1].item()
                mask[b, last_idx] = False
        return mask

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
        feats = self.get_lstm_features(input_ids, attention_mask)
        crf_mask = get_crf_mask(attention_mask, labels)
        clean_labels = labels.clone()
        clean_labels[clean_labels == -100] = 0
        padded_feats, padded_masks, padded_tags = self._get_active_features(feats, crf_mask, clean_labels)
        return self.crf(padded_feats, padded_tags, padded_masks)

    def decode(self, input_ids, attention_mask, labels=None):
        feats = self.get_lstm_features(input_ids, attention_mask)
        crf_mask = get_crf_mask(attention_mask, labels)
        padded_feats, padded_masks = self._get_active_features(feats, crf_mask)
        return self.crf.decode(padded_feats, padded_masks)

class BiLSTM_CRF_NER(BiLSTM_CRF):
    def __init__(self, embedding_model, num_tags, embedding_dim=768, hidden_dim=128, fine_tune=True):
        super().__init__(embedding_module=embedding_model, num_tags=num_tags, embedding_dim=embedding_dim, hidden_dim=hidden_dim, is_transformer=True, fine_tune=fine_tune)

class CNNClassifier(nn.Module):
    def __init__(self, vocab_size, embedding_dim=300, num_classes=50, filter_sizes=[3, 4, 5], num_filters=64):
        super(CNNClassifier, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim)
        self.convs = nn.ModuleList([
            nn.Conv1d(in_channels=embedding_dim, out_channels=num_filters, kernel_size=fs)
            for fs in filter_sizes
        ])
        self.fc = nn.Linear(len(filter_sizes) * num_filters, num_classes)
        self.dropout = nn.Dropout(0.5)

    def forward(self, input_ids):
        x = self.embedding(input_ids)
        x = x.permute(0, 2, 1)
        pooled_outputs = []
        for conv in self.convs:
            c = torch.relu(conv(x))
            pooled = torch.max(c, dim=2)[0]
            pooled_outputs.append(pooled)
        flat = torch.cat(pooled_outputs, dim=1)
        logits = self.fc(self.dropout(flat))
        return logits

def decode_model(model, input_ids, mask, labels=None):
    if hasattr(model, 'module'):
        return model.module.decode(input_ids, mask, labels)
    return model.decode(input_ids, mask, labels)

class NLPInferenceManager:
    def __init__(self, base_dir: str = "checkpoint/NLP"):
        self.device = torch.device("cpu")
        base_path = Path(base_dir)

        # 1. Load Vocabs & Configs
        with open(base_path / "word_to_ix.json", "r", encoding="utf-8") as f:
            self.word_to_ix = json.load(f)
        with open(base_path / "icd_codes.json", "r", encoding="utf-8") as f:
            self.icd_codes = json.load(f)

        # 2. Initialize Tokenizer & Embedding Model
        self.tokenizer = AutoTokenizer.from_pretrained(str(base_path / "biobert_tokenizer"))
        self.biobert_model = AutoModel.from_pretrained(str(base_path / "biobert_model"))

        # 3. Load & Initialize NER Model
        self.ner_model = BiLSTM_CRF_NER(self.biobert_model, num_tags=len(tag_to_ix), fine_tune=True).to(self.device)
        ner_checkpoint = torch.load(base_path / "ner_biobert_bilstm_crf.pt", map_location=self.device, weights_only=True)
        # Strip DataParallel 'module.' prefix if present
        clean_ner_state = {k[7:] if k.startswith("module.") else k: v for k, v in ner_checkpoint.items()}
        self.ner_model.load_state_dict(clean_ner_state)
        self.ner_model.eval()

        # 4. Load & Initialize CNN Classifier
        self.cnn_model = CNNClassifier(vocab_size=len(self.word_to_ix), embedding_dim=300, num_classes=len(self.icd_codes)).to(self.device)
        cnn_checkpoint = torch.load(base_path / "cnn_icd10_classifier.pt", map_location=self.device, weights_only=True)
        clean_cnn_state = {k[7:] if k.startswith("module.") else k: v for k, v in cnn_checkpoint.items()}
        self.cnn_model.load_state_dict(clean_cnn_state)
        self.cnn_model.eval()

    def analyze_note(self, text: str) -> dict:
        cleaned = clean_text(text)
        if not cleaned:
            return {"text": text, "entities": [], "icd10_diagnostics": []}

        # --- NER INFERENCE ---
        encoded = self.tokenizer(cleaned, return_offsets_mapping=True, add_special_tokens=True)
        input_ids = torch.tensor([encoded["input_ids"]], dtype=torch.long, device=self.device)
        attention_mask = torch.tensor([encoded["attention_mask"]], dtype=torch.long, device=self.device)
        offsets = encoded["offset_mapping"]

        crf_mask = get_crf_mask(attention_mask, labels=None)
        paths = decode_model(self.ner_model, input_ids, attention_mask)
        best_path = paths[0]
        active_offsets = [offsets[idx] for idx, val in enumerate(crf_mask[0]) if val.item() == 1]

        entities = []
        current_ent = None

        for idx, tag_id in enumerate(best_path):
            if idx >= len(active_offsets):
                break
            s, e = active_offsets[idx]
            tag = ix_to_tag[tag_id]
            if tag.startswith("B-"):
                if current_ent:
                    entities.append(current_ent)
                current_ent = {
                    "entity": cleaned[s:e],
                    "type": tag.split("-")[1],
                    "start": s,
                    "end": e
                }
            elif tag.startswith("I-") and current_ent and tag.split("-")[1] == current_ent["type"]:
                current_ent["entity"] += cleaned[current_ent["end"]:e]
                current_ent["end"] = e
            else:
                if current_ent:
                    entities.append(current_ent)
                    current_ent = None
        if current_ent:
            entities.append(current_ent)

        # --- CNN CLASSIFICATION INFERENCE ---
        tokens = tokenize_words(cleaned.lower())
        cnn_tokens = [self.word_to_ix.get(w, self.word_to_ix["<UNK>"]) for w in tokens[:128]]
        if len(cnn_tokens) < 128:
            cnn_tokens += [0] * (128 - len(cnn_tokens))
        cnn_input_ids = torch.tensor([cnn_tokens], dtype=torch.long, device=self.device)

        with torch.no_grad():
            logits = self.cnn_model(cnn_input_ids)
            probs = torch.sigmoid(logits)[0]

        predictions = []
        for i, code in enumerate(self.icd_codes):
            predictions.append({"code": code, "probability": round(float(probs[i].item()), 4)})

        # Sort by confidence descending
        sorted_predictions = sorted(predictions, key=lambda x: x["probability"], reverse=True)

        return {
            "text": text,
            "entities": entities,
            "icd10_diagnostics": sorted_predictions[:5] # Return top 5 diagnostics
        }

# تهيئة الـ NLP Manager
nlp_manager = NLPInferenceManager("checkpoint/NLP")