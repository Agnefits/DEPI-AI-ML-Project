import os
import sys
import json
import argparse
import torch
import torch.nn as nn
from nltk.tokenize import RegexpTokenizer

# Import custom package structures
from data.parser import clean_text
from models.bilstm_crf import BiLSTM_CRF_NER, get_crf_mask
from models.cnn_classifier import CNNClassifier
from utils.embeddings import load_biobert_embeddings

def get_device():
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")

def main():
    parser = argparse.ArgumentParser(description="Clinical Note NLP Inference Analyzer")
    parser.add_argument("--note", type=str, default=None, help="Patient note text to analyze")
    parser.add_argument("--checkpoints_dir", type=str, default="checkpoints", help="Directory where model checkpoints are saved")
    args = parser.parse_args()

    # Define checkpoint paths
    tag_to_ix_path = os.path.join(args.checkpoints_dir, "tag_to_ix.json")
    word_to_ix_path = os.path.join(args.checkpoints_dir, "word_to_ix.json")
    icd_codes_path = os.path.join(args.checkpoints_dir, "icd_codes.json")
    ner_weights_path = os.path.join(args.checkpoints_dir, "ner_biobert_bilstm_crf.pt")
    cnn_weights_path = os.path.join(args.checkpoints_dir, "cnn_icd10_classifier.pt")
    thresholds_path = os.path.join(args.checkpoints_dir, "tuned_thresholds.json")

    # Check if vocabulary logs exist
    if not (os.path.exists(tag_to_ix_path) and os.path.exists(word_to_ix_path) and os.path.exists(icd_codes_path)):
        print("[!] Missing vocabulary mapping checkpoints. Please run train.py first to build vocabularies and train the models.")
        sys.exit(1)

    # 1. Load mappings
    print("[*] Loading vocabularies and configurations...")
    with open(tag_to_ix_path, "r") as f:
        tag_to_ix = json.load(f)
    ix_to_tag = {i: tag for tag, i in tag_to_ix.items()}

    with open(word_to_ix_path, "r") as f:
        word_to_ix = json.load(f)
        
    with open(icd_codes_path, "r") as f:
        icd_codes = json.load(f)

    # Load tuned thresholds if available, else default to 0.5
    tuned_thresholds = {}
    if os.path.exists(thresholds_path):
        with open(thresholds_path, "r") as f:
            tuned_thresholds = json.load(f)

    # 2. Instantiate and load model architectures
    device = get_device()
    print(f"[*] Instantiating model architectures on device: {device}...")
    
    # Load BioBERT components
    tokenizer, embedding_model = load_biobert_embeddings(args.checkpoints_dir)
    
    # Load NER model
    ner_model = BiLSTM_CRF_NER(embedding_model, num_tags=len(tag_to_ix), fine_tune=False).to(device)
    if os.path.exists(ner_weights_path):
        print(f"[+] Loading NER weights from {ner_weights_path}...")
        # Handle weights saved with DataParallel wrapper
        state_dict = torch.load(ner_weights_path, map_location=device)
        cleaned_state_dict = {}
        for k, v in state_dict.items():
            if k.startswith("module."):
                cleaned_state_dict[k[7:]] = v
            else:
                cleaned_state_dict[k] = v
        ner_model.load_state_dict(cleaned_state_dict)
    else:
        print("[!] NER checkpoint weights file not found. Running inference with randomized weights.")

    # Load CNN classifier model
    cnn_model = CNNClassifier(vocab_size=len(word_to_ix), embedding_dim=300, num_classes=len(icd_codes)).to(device)
    if os.path.exists(cnn_weights_path):
        print(f"[+] Loading CNN classification weights from {cnn_weights_path}...")
        state_dict = torch.load(cnn_weights_path, map_location=device)
        cleaned_state_dict = {}
        for k, v in state_dict.items():
            if k.startswith("module."):
                cleaned_state_dict[k[7:]] = v
            else:
                cleaned_state_dict[k] = v
        cnn_model.load_state_dict(cleaned_state_dict)
    else:
        print("[!] CNN Classifier checkpoint weights file not found. Running inference with randomized weights.")

    ner_model.eval()
    cnn_model.eval()
    word_tokenizer = RegexpTokenizer(r'\w+|[^\w\s]')

    def analyze_note(text):
        cleaned = clean_text(text)
        
        # --- A. Named Entity Recognition (NER) inference ---
        encoded = tokenizer(cleaned, return_offsets_mapping=True, add_special_tokens=True)
        input_ids = torch.tensor([encoded["input_ids"]], dtype=torch.long, device=device)
        attention_mask = torch.tensor([encoded["attention_mask"]], dtype=torch.long, device=device)
        offsets = encoded["offset_mapping"]

        # CRF active tokens mask excluding CLS and SEP boundaries
        crf_mask = get_crf_mask(attention_mask, labels=None)
        
        # Viterbi decoding
        with torch.no_grad():
            if hasattr(ner_model, 'module'):
                paths = ner_model.module.decode(input_ids, attention_mask)
            else:
                paths = ner_model.decode(input_ids, attention_mask)
        best_path = paths[0]

        # Extract spans mapping
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

        # --- B. Diagnostic ICD-10 Classification inference ---
        tokens = word_tokenizer.tokenize(cleaned.lower())
        cnn_tokens = [word_to_ix.get(w, word_to_ix["<UNK>"]) for w in tokens[:128]]
        if len(cnn_tokens) < 128:
            cnn_tokens += [0] * (128 - len(cnn_tokens))
        else:
            cnn_tokens = cnn_tokens[:128]
        cnn_input_ids = torch.tensor([cnn_tokens], dtype=torch.long, device=device)

        with torch.no_grad():
            logits = cnn_model(cnn_input_ids)
            probs = torch.sigmoid(logits)[0]

        print("\n" + "="*24 + " CLINICAL ANALYSIS REPORT " + "="*24)
        print(f"Source Text:\n  {text}\n")
        
        print("--- Extracted Medical Entities ---")
        if not entities:
            print("  No medical entities detected.")
        for ent in entities:
            print(f"  - {ent['entity']} ({ent['type']}) | character span: {ent['start']}-{ent['end']}")
            
        print("\n--- Diagnostic ICD-10 Code Predictions ---")
        predictions = []
        for i, code in enumerate(icd_codes):
            predictions.append((code, probs[i].item()))
            
        sorted_preds = sorted(predictions, key=lambda x: x[1], reverse=True)
        top_k = 5
        count = 0
        for code, conf in sorted_preds:
            threshold = tuned_thresholds.get(code, 0.5)
            # Tag codes that exceed decision threshold, or show top items
            flag = " [EXCEEDS THRESHOLD]" if conf >= threshold else ""
            print(f"  - Code {code:<8} | Confidence: {conf*100:6.2f}% | threshold: {threshold*100:2.0f}%{flag}")
            count += 1
            if count >= top_k:
                break
        print("="*74)

    # 3. Analyze note passed as argument, or enter interactive shell loop
    if args.note:
        analyze_note(args.note)
    else:
        print("\n[+] Entering interactive mode. Type patient symptoms notes to analyze. Type 'exit' to quit.")
        while True:
            try:
                note_input = input("\nEnter clinical text: ").strip()
                if not note_input:
                    continue
                if note_input.lower() in ["exit", "quit"]:
                    print("Exiting.")
                    break
                analyze_note(note_input)
            except KeyboardInterrupt:
                print("\nExiting.")
                break

if __name__ == "__main__":
    main()
