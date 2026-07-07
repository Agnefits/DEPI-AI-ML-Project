import os
import sys
import json
import torch
import torch.nn as nn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict
from transformers import AutoTokenizer, AutoModel
from nltk.tokenize import RegexpTokenizer

# Add project root to python path to allow importing models
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from models.verify_pipeline import BiLSTM_CRF, get_crf_mask

app = FastAPI(title="ClinicAI NLP Service")

# Load Vocabularies
checkpoints_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "checkpoints")
checkpoints_dir = os.path.abspath(checkpoints_dir)

# 1. Loading configuration files
try:
    with open(os.path.join(checkpoints_dir, "tag_to_ix.json"), "r") as f:
        tag_to_ix = json.load(f)
    ix_to_tag = {v: k for k, v in tag_to_ix.items()}

    with open(os.path.join(checkpoints_dir, "word_to_ix.json"), "r") as f:
        word_to_ix = json.load(f)

    with open(os.path.join(checkpoints_dir, "icd_codes.json"), "r") as f:
        icd_codes = json.load(f)
except FileNotFoundError as e:
    print(f"Error loading vocabulary files from {checkpoints_dir}: {e}")
    tag_to_ix = {}
    ix_to_tag = {}
    word_to_ix = {}
    icd_codes = []

# 2. Define CNN Classifier Architecture (Fix 2: BN + Dropout)
class CNNClassifier(nn.Module):
    def __init__(self, vocab_size, embedding_dim=300, num_classes=50, filter_sizes=[3, 4, 5], num_filters=64, dropout_rate=0.6):
        super(CNNClassifier, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim)
        self.embed_dropout = nn.Dropout(0.3)
        self.convs = nn.ModuleList([
            nn.Conv1d(in_channels=embedding_dim, out_channels=num_filters, kernel_size=fs)
            for fs in filter_sizes
        ])
        self.bn = nn.BatchNorm1d(len(filter_sizes) * num_filters)
        self.fc = nn.Linear(len(filter_sizes) * num_filters, num_classes)
        self.dropout = nn.Dropout(dropout_rate)

    def forward(self, input_ids):
        x = self.embedding(input_ids)
        x = self.embed_dropout(x)
        x = x.permute(0, 2, 1)
        pooled_outputs = []
        for conv in self.convs:
            c = torch.relu(conv(x))
            pooled = torch.max(c, dim=2)[0]
            pooled_outputs.append(pooled)
        flat = torch.cat(pooled_outputs, dim=1)
        flat = self.bn(flat)
        logits = self.fc(self.dropout(flat))
        return logits

# 3. Model Initializations
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

tokenizer = None
biobert_model = None
ner_model = None
cnn_model = None

def init_models():
    global tokenizer, biobert_model, ner_model, cnn_model
    
    # HF Cached files or online download
    local_tokenizer_path = os.path.join(checkpoints_dir, "biobert_tokenizer")
    local_model_path = os.path.join(checkpoints_dir, "biobert_model")
    
    if os.path.exists(local_tokenizer_path) and os.path.exists(local_model_path):
        tokenizer = AutoTokenizer.from_pretrained(local_tokenizer_path)
        biobert_model = AutoModel.from_pretrained(local_model_path)
    else:
        # Online fallback
        tokenizer = AutoTokenizer.from_pretrained("dmis-lab/biobert-v1.1")
        biobert_model = AutoModel.from_pretrained("dmis-lab/biobert-v1.1")
        
    ner_model = BiLSTM_CRF(biobert_model, len(tag_to_ix), is_transformer=True)
    ner_model.load_state_dict(torch.load(os.path.join(checkpoints_dir, "ner_biobert_bilstm_crf.pt"), map_location=device))
    ner_model.to(device).eval()
    
    cnn_model = CNNClassifier(len(word_to_ix), num_classes=len(icd_codes))
    cnn_model.load_state_dict(torch.load(os.path.join(checkpoints_dir, "cnn_icd10_classifier.pt"), map_location=device))
    cnn_model.to(device).eval()

class NoteRequest(BaseModel):
    prompt: str

def clean_text(text):
    import re
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

@app.on_event("startup")
def startup_event():
    try:
        init_models()
        print("[+] Models successfully loaded.")
    except Exception as e:
        print(f"[!] Warning: Could not load models during startup: {e}")

@app.post("/analyze")
def analyze_note(request: NoteRequest):
    if tokenizer is None or ner_model is None or cnn_model is None:
        raise HTTPException(status_code=503, detail="Models are not initialized yet.")
        
    text = request.prompt
    if not text.strip():
        raise HTTPException(status_code=400, detail="Empty prompt text.")
        
    cleaned = clean_text(text)
    
    # 1. Run NER
    encoded = tokenizer(cleaned, return_offsets_mapping=True, add_special_tokens=True)
    input_ids = torch.tensor([encoded["input_ids"]], dtype=torch.long, device=device)
    attention_mask = torch.tensor([encoded["attention_mask"]], dtype=torch.long, device=device)
    offsets = encoded["offset_mapping"]
    
    with torch.no_grad():
        paths = ner_model.decode(input_ids, attention_mask)
        best_path = paths[0]
        
    crf_mask = get_crf_mask(attention_mask, labels=None)
    active_offsets = [offsets[idx] for idx, val in enumerate(crf_mask[0]) if val.item() == 1]
    
    entities = []
    current_ent = None
    
    for idx, tag_id in enumerate(best_path):
        if idx >= len(active_offsets): break
        s, e = active_offsets[idx]
        tag = ix_to_tag[tag_id]
        
        # Post-processing: Promote orphan I- tags to B- tags (Fix 4)
        if tag.startswith("I-"):
            tag_type = tag.split("-")[1]
            if current_ent is None or current_ent["type"] != tag_type:
                tag = "B-" + tag_type
                
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
        
    # 2. Run CNN classification
    word_tokenizer = RegexpTokenizer(r'\w+|[^\w\s]')
    tokens = word_tokenizer.tokenize(cleaned.lower())
    cnn_tokens = [word_to_ix.get(w, word_to_ix["<UNK>"]) for w in tokens[:128]]
    if len(cnn_tokens) < 128:
        cnn_tokens += [0] * (128 - len(cnn_tokens))
    cnn_input_ids = torch.tensor([cnn_tokens], dtype=torch.long, device=device)
    
    with torch.no_grad():
        logits = cnn_model(cnn_input_ids)
        probs = torch.sigmoid(logits)[0]
        
    predictions = []
    for i, code in enumerate(icd_codes):
        predictions.append({
            "code": code,
            "confidence": float(probs[i].item())
        })
    predictions = sorted(predictions, key=lambda x: x["confidence"], reverse=True)[:3]
    
    return {
        "text": text,
        "entities": entities,
        "diagnoses": predictions
    }
