import os
import sys
import json
import random
import argparse
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from sklearn.metrics import classification_report

# Import custom packages
from data.parser import parse_pubtator_file, process_blurb_bc2gm
from data.dataset import ClinicalDataset, ClinicalWordDataset, ClinicalCNNDataset
from models.bilstm_crf import BiLSTM_CRF_NER, BiLSTM_CRF_GloVe
from models.cnn_classifier import CNNClassifier
from utils.embeddings import load_biobert_embeddings, load_glove_embeddings
from utils.metrics import (
    evaluate_ner_seqeval,
    tune_cnn_thresholds,
    evaluate_cnn_classifier,
    save_confusion_matrices,
    get_ner_flat_predictions,
    save_ner_confusion_matrices
)

# Seed for reproducibility
def set_seeds(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)

def seed_worker(worker_id):
    worker_seed = torch.initial_seed() % 2**32
    np.random.seed(worker_seed)
    random.seed(worker_seed)

def get_device():
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")

def create_synthetic_data(num_samples=100):
    """
    Generates synthetic clinical records if real dataset files are not available.
    Ensures the pipeline is fully runnable in headless/empty workspaces.
    """
    print(f"[*] Generating {num_samples} synthetic clinical records for fallback...")
    
    mock_notes = [
        "Patient has a history of type 2 diabetes and hypertension. Prescribed Metformin and Lisinopril.",
        "The subject was diagnosed with acute myocardial infarction last night. Given Aspirin immediately.",
        "DNA analysis showed mutations in BRCA1 and BRCA2 genes associated with breast cancer risks.",
        "A 45-year-old female presents with severe chest pain. Cardiac enzymes suggest ischemic heart disease.",
        "Prescribed Atorvastatin to manage hyperlipidemia. Side effects of muscle pain were noted.",
        "Examination reveals metastatic melanoma. Initiating immunotherapy targeting PD-1 receptors.",
        "Diagnosed with rheumatoid arthritis. Started on Methotrexate therapy.",
        "No evidence of genetic anomalies in EGFR or ALK mutations for lung adenocarcinoma."
    ]
    
    # Pre-defined mock annotations
    mock_entities_choices = [
        [
            {"entity": "diabetes", "type": "Disease", "start": 26, "end": 34},
            {"entity": "hypertension", "type": "Disease", "start": 39, "end": 51},
            {"entity": "Metformin", "type": "Chemical", "start": 64, "end": 73},
            {"entity": "Lisinopril", "type": "Chemical", "start": 78, "end": 88}
        ],
        [
            {"entity": "acute myocardial infarction", "type": "Disease", "start": 30, "end": 57},
            {"entity": "Aspirin", "type": "Chemical", "start": 76, "end": 83}
        ],
        [
            {"entity": "BRCA1", "type": "Gene", "start": 38, "end": 43},
            {"entity": "BRCA2", "type": "Gene", "start": 48, "end": 53},
            {"entity": "breast cancer", "type": "Disease", "start": 71, "end": 84}
        ],
        [
            {"entity": "chest pain", "type": "Disease", "start": 37, "end": 47},
            {"entity": "ischemic heart disease", "type": "Disease", "start": 73, "end": 95}
        ],
        [
            {"entity": "Atorvastatin", "type": "Chemical", "start": 11, "end": 23},
            {"entity": "hyperlipidemia", "type": "Disease", "start": 34, "end": 48}
        ],
        [
            {"entity": "metastatic melanoma", "type": "Disease", "start": 20, "end": 39},
            {"entity": "PD-1", "type": "Gene", "start": 74, "end": 78}
        ],
        [
            {"entity": "rheumatoid arthritis", "type": "Disease", "start": 15, "end": 35},
            {"entity": "Methotrexate", "type": "Chemical", "start": 48, "end": 60}
        ],
        [
            {"entity": "EGFR", "type": "Gene", "start": 35, "end": 39},
            {"entity": "ALK", "type": "Gene", "start": 43, "end": 46},
            {"entity": "lung adenocarcinoma", "type": "Disease", "start": 57, "end": 76}
        ]
    ]
    
    mock_icd_choices = [
        ["E11.9", "I10"],
        ["I21.9"],
        ["C50.9"],
        ["I25.9"],
        ["E78.5"],
        ["C43.9"],
        ["M06.9"],
        ["C34.9"]
    ]

    data = []
    for i in range(num_samples):
        idx = i % len(mock_notes)
        data.append({
            "text": mock_notes[idx],
            "entities": mock_entities_choices[idx],
            "icd10": mock_icd_choices[idx]
        })
    return data

def load_data_splits(args):
    """
    Loads training, validation, and test datasets.
    Checks environment for CDR and BLURB sources, falling back to mock files if offline/local.
    """
    IS_KAGGLE = os.path.exists("/kaggle")
    
    if IS_KAGGLE:
        bc5cdr_src_dir = "/kaggle/input/datasets/ahmedadelrasmy/cdr-dataset/CDR_Data"
        bc5cdr_dst_dir = "./bc5cdr_data"
        import shutil
        shutil.copytree(bc5cdr_src_dir, bc5cdr_dst_dir, dirs_exist_ok=True)
        data_dir = os.path.join(bc5cdr_dst_dir, "CDR.Corpus.v010516")
        if not os.path.exists(data_dir):
            data_dir = bc5cdr_dst_dir
    else:
        # User defined folder or default path
        data_dir = args.data_dir
        
    bc5_train_path = os.path.join(data_dir, "CDR_TrainingSet.PubTator.txt")
    
    # Check if files exist, else fallback
    if not os.path.exists(bc5_train_path):
        print(f"[!] BC5CDR training files not found at: {bc5_train_path}")
        synthetic_data = create_synthetic_data(120)
        # Split synthetic data into train/val/test
        random.seed(42)
        random.shuffle(synthetic_data)
        n = len(synthetic_data)
        train = synthetic_data[:int(0.8*n)]
        val = synthetic_data[int(0.8*n):int(0.9*n)]
        test = synthetic_data[int(0.9*n):]
        return train, val, test

    try:
        # Load BC5CDR datasets
        print(f"[*] Reading PubTator datasets from: {data_dir} ...")
        bc5_train = parse_pubtator_file(bc5_train_path)
        bc5_val = parse_pubtator_file(os.path.join(data_dir, "CDR_DevelopmentSet.PubTator.txt"))
        bc5_test = parse_pubtator_file(os.path.join(data_dir, "CDR_TestSet.PubTator.txt"))
        
        # Load BLURB/BC2GM
        blurb_train, blurb_val, blurb_test = [], [], []
        blurb_parquet = "/kaggle/input/datasets/ahmedadelrasmy/lr-dataset/0000.parquet"
        if os.path.exists(blurb_parquet):
            print(f"[*] Loading BLURB Parquet dataset from: {blurb_parquet} ...")
            df_blurb = pd.read_parquet(blurb_parquet)
            indices = df_blurb.index.tolist()
            random.seed(42)
            random.shuffle(indices)
            n = len(indices)
            train_idx = indices[:int(0.8*n)]
            val_idx = indices[int(0.8*n):int(0.9*n)]
            test_idx = indices[int(0.9*n):]
            blurb_train = process_blurb_bc2gm(df_blurb.loc[train_idx])
            blurb_val = process_blurb_bc2gm(df_blurb.loc[val_idx])
            blurb_test = process_blurb_bc2gm(df_blurb.loc[test_idx])
            
        clinical_notes_raw = bc5_train + blurb_train
        clinical_notes_val = bc5_val + blurb_val
        clinical_notes_test = bc5_test + blurb_test
        
        print(f"[+] Loaded splits successfully:")
        print(f"    Train: {len(clinical_notes_raw)} | Val: {len(clinical_notes_val)} | Test: {len(clinical_notes_test)}")
        return clinical_notes_raw, clinical_notes_val, clinical_notes_test
    except Exception as e:
        print(f"[!] Error processing real datasets ({e}). Falling back to synthetic...")
        synthetic_data = create_synthetic_data(120)
        random.seed(42)
        random.shuffle(synthetic_data)
        n = len(synthetic_data)
        return synthetic_data[:int(0.8*n)], synthetic_data[int(0.8*n):int(0.9*n)], synthetic_data[int(0.9*n):]

def main():
    parser = argparse.ArgumentParser(description="Clinical NLP Pipeline Training orchestrator")
    parser.add_argument("--data_dir", type=str, default="./bc5cdr_data/CDR.Corpus.v010516", help="Directory of BC5CDR files")
    parser.add_argument("--checkpoints_dir", type=str, default="checkpoints", help="Directory to save checkpoints")
    parser.add_argument("--epochs_biobert", type=int, default=10, help="BioBERT training epochs")
    parser.add_argument("--epochs_glove", type=int, default=25, help="GloVe training epochs")
    parser.add_argument("--epochs_cnn", type=int, default=30, help="CNN Classifier training epochs")
    parser.add_argument("--batch_size", type=int, default=8, help="Batch size for training loaders")
    parser.add_argument("--patience", type=int, default=3, help="Early stopping patience")
    args = parser.parse_args()

    set_seeds()
    device = get_device()
    print(f"[*] Executing pipeline on device: {device}")
    
    os.makedirs(args.checkpoints_dir, exist_ok=True)
    
    # 1. Load Data
    train_data, val_data, test_data = load_data_splits(args)

    # 2. Tag Vocabulary Definitions
    ENTITY_TYPES = ["Chemical", "Disease", "Gene"]
    tag_list = ["O"]
    for etype in ENTITY_TYPES:
        tag_list += [f"B-{etype}", f"I-{etype}"]
    tag_list += ["<START>", "<STOP>"]  # CRF tags
    tag_to_ix = {tag: i for i, tag in enumerate(tag_list)}
    ix_to_tag  = {i: tag for tag, i in tag_to_ix.items()}

    # 3. ICD and Word Vocabularies
    from collections import Counter, defaultdict
    from nltk.tokenize import RegexpTokenizer
    word_tokenizer = RegexpTokenizer(r'\w+|[^\w\s]')

    # Collect diagnostic ICD/MeSH tags
    all_icd = [code for doc in train_data for code in doc["icd10"] if code.strip()]
    # Restrict to top 50 codes for model training
    icd_codes = [c for c, cnt in Counter(all_icd).most_common(50)]
    if not icd_codes:
        # Fallback codes if none found
        icd_codes = [f"Mock-ICD-{i}" for i in range(10)]
    icd_to_ix = {c: i for i, c in enumerate(icd_codes)}

    # Build word dictionary for static embeddings
    word_freq = defaultdict(int)
    for doc in train_data:
        from data.parser import clean_text
        text_clean = clean_text(doc["text"])
        tokens = word_tokenizer.tokenize(text_clean.lower())
        for w in tokens:
            word_freq[w] += 1

    vocab = ["<PAD>", "<UNK>"] + [w for w, f in sorted(word_freq.items(), key=lambda x: -x[1]) if f >= 2]
    word_to_ix = {w: i for i, w in enumerate(vocab)}
    vocab_size = len(word_to_ix)

    print(f"[+] Vocabulary built: {len(icd_codes)} ICD codes | {vocab_size} unique words.")

    # 4. Save metadata maps for downstream inference
    with open(os.path.join(args.checkpoints_dir, "tag_to_ix.json"), "w") as f:
        json.dump(tag_to_ix, f)
    with open(os.path.join(args.checkpoints_dir, "word_to_ix.json"), "w") as f:
        json.dump(word_to_ix, f)
    with open(os.path.join(args.checkpoints_dir, "icd_codes.json"), "w") as f:
        json.dump(icd_codes, f)

    # Dataloader configurations
    num_workers = min(2, os.cpu_count() or 1)
    pin_memory = torch.cuda.is_available()
    g = torch.Generator()
    g.manual_seed(42)

    # ----------------------------------------------------
    # CONFIG B: BioBERT BiLSTM-CRF NER Pipeline
    # ----------------------------------------------------
    print("\n" + "="*50 + "\n[*] Phase A: Config B (BioBERT BiLSTM-CRF NER) training\n" + "="*50)
    tokenizer, embedding_model = load_biobert_embeddings(args.checkpoints_dir)
    
    train_dataset = ClinicalDataset(train_data, tokenizer, tag_to_ix, icd_codes)
    val_dataset = ClinicalDataset(val_data, tokenizer, tag_to_ix, icd_codes)
    
    train_loader = DataLoader(train_dataset, batch_size=args.batch_size, shuffle=True, num_workers=num_workers, pin_memory=pin_memory, worker_init_fn=seed_worker, generator=g)
    val_loader = DataLoader(val_dataset, batch_size=args.batch_size, num_workers=num_workers, pin_memory=pin_memory)
    
    ner_model = BiLSTM_CRF_NER(embedding_model, num_tags=len(tag_to_ix), fine_tune=True).to(device)
    if torch.cuda.device_count() > 1:
        ner_model = nn.DataParallel(ner_model)

    optimizer = optim.AdamW(ner_model.parameters(), lr=2e-5)
    
    from transformers import get_linear_schedule_with_warmup
    total_steps = len(train_loader) * args.epochs_biobert
    scheduler = get_linear_schedule_with_warmup(optimizer, num_warmup_steps=int(0.1 * total_steps), num_training_steps=total_steps)

    best_f1 = -1.0
    patience_counter = 0
    
    for epoch in range(args.epochs_biobert):
        ner_model.train()
        total_loss = 0
        for batch in train_loader:
            input_ids = batch["input_ids"].to(device)
            mask = batch["attention_mask"].to(device)
            labels = batch["labels"].to(device)
            
            optimizer.zero_grad()
            loss = ner_model(input_ids, mask, labels)
            
            if loss.dim() > 0:
                loss = loss.mean()
            
            loss.backward()
            torch.nn.utils.clip_grad_norm_(ner_model.parameters(), max_norm=1.0)
            optimizer.step()
            scheduler.step()
            total_loss += loss.item()
            
        val_f1, val_prec, val_rec, _ = evaluate_ner_seqeval(ner_model, val_loader, ix_to_tag, device)
        print(f"BioBERT NER Epoch {epoch+1}/{args.epochs_biobert} | Loss: {total_loss:.4f} | Val F1: {val_f1*100:.2f}% | Val Prec: {val_prec*100:.2f}% | Val Rec: {val_rec*100:.2f}%")
        
        if val_f1 > best_f1:
            best_f1 = val_f1
            torch.save(ner_model.state_dict(), os.path.join(args.checkpoints_dir, "ner_biobert_bilstm_crf.pt"))
            patience_counter = 0
            print(f"  [+] Validation F1 improved. Saved weights.")
        else:
            patience_counter += 1
            if patience_counter >= args.patience:
                print(f"  [!] Early stopping triggered.")
                break

    # Load best weights
    best_biobert_pt = os.path.join(args.checkpoints_dir, "ner_biobert_bilstm_crf.pt")
    if os.path.exists(best_biobert_pt):
        ner_model.load_state_dict(torch.load(best_biobert_pt))

    # ----------------------------------------------------
    # CONFIG A: GloVe BiLSTM-CRF NER Baseline Pipeline
    # ----------------------------------------------------
    print("\n" + "="*50 + "\n[*] Phase B: Config A (GloVe BiLSTM-CRF NER) training\n" + "="*50)
    glove_embedding_layer, embedding_matrix = load_glove_embeddings(args.checkpoints_dir, vocab_size, word_to_ix)
    
    train_word_dataset = ClinicalWordDataset(train_data, word_to_ix, tag_to_ix)
    val_word_dataset = ClinicalWordDataset(val_data, word_to_ix, tag_to_ix)
    
    train_word_loader = DataLoader(train_word_dataset, batch_size=args.batch_size, shuffle=True, num_workers=num_workers, pin_memory=pin_memory, worker_init_fn=seed_worker, generator=g)
    val_word_loader = DataLoader(val_word_dataset, batch_size=args.batch_size, num_workers=num_workers, pin_memory=pin_memory)
    
    ner_model_glove = BiLSTM_CRF_GloVe(num_tags=len(tag_to_ix), embedding_layer=glove_embedding_layer).to(device)
    if torch.cuda.device_count() > 1:
        ner_model_glove = nn.DataParallel(ner_model_glove)

    optimizer_glove = optim.AdamW(ner_model_glove.parameters(), lr=1e-3)
    scheduler_glove = optim.lr_scheduler.CosineAnnealingLR(optimizer_glove, T_max=args.epochs_glove)

    best_f1_glove = -1.0
    patience_counter = 0
    
    for epoch in range(args.epochs_glove):
        ner_model_glove.train()
        total_loss = 0
        for batch in train_word_loader:
            input_ids = batch["input_ids"].to(device)
            mask = batch["attention_mask"].to(device)
            labels = batch["labels"].to(device)
            
            optimizer_glove.zero_grad()
            loss = ner_model_glove(input_ids, mask, labels)
            if loss.dim() > 0:
                loss = loss.mean()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(ner_model_glove.parameters(), max_norm=1.0)
            optimizer_glove.step()
            total_loss += loss.item()
            
        scheduler_glove.step()
        val_f1, val_prec, val_rec, _ = evaluate_ner_seqeval(ner_model_glove, val_word_loader, ix_to_tag, device)
        print(f"GloVe NER Epoch {epoch+1}/{args.epochs_glove} | Loss: {total_loss:.4f} | Val F1: {val_f1*100:.2f}% | Val Prec: {val_prec*100:.2f}% | Val Rec: {val_rec*100:.2f}%")
        
        if val_f1 > best_f1_glove:
            best_f1_glove = val_f1
            torch.save(ner_model_glove.state_dict(), os.path.join(args.checkpoints_dir, "ner_glove_bilstm_crf.pt"))
            patience_counter = 0
            print(f"  [+] Validation F1 improved. Saved weights.")
        else:
            patience_counter += 1
            if patience_counter >= args.patience + 2:
                print(f"  [!] Early stopping triggered.")
                break

    best_glove_pt = os.path.join(args.checkpoints_dir, "ner_glove_bilstm_crf.pt")
    if os.path.exists(best_glove_pt):
        ner_model_glove.load_state_dict(torch.load(best_glove_pt))

    # ----------------------------------------------------
    # CNN Classifier Multi-Label ICD-10 Classification
    # ----------------------------------------------------
    print("\n" + "="*50 + "\n[*] Phase C: CNN Classifier (ICD-10 classification) training\n" + "="*50)
    
    # Class imbalance computation
    num_docs = len(train_data)
    num_classes = len(icd_codes)
    class_pos_counts = np.zeros(num_classes)
    for doc in train_data:
        for code in doc["icd10"]:
            if code in icd_to_ix:
                class_pos_counts[icd_to_ix[code]] += 1
                
    class_pos_counts = np.clip(class_pos_counts, 1, None)
    pos_weights = np.clip((num_docs - class_pos_counts) / class_pos_counts, 1.0, 50.0)
    pos_weight_tensor = torch.tensor(pos_weights, dtype=torch.float, device=device)

    cnn_model = CNNClassifier(vocab_size=vocab_size, embedding_dim=300, num_classes=num_classes)
    cnn_model.embedding = nn.Embedding.from_pretrained(torch.tensor(embedding_matrix, dtype=torch.float), freeze=False)
    cnn_model = cnn_model.to(device)
    if torch.cuda.device_count() > 1:
        cnn_model = nn.DataParallel(cnn_model)

    cnn_optimizer = optim.AdamW(cnn_model.parameters(), lr=1e-3)
    cnn_scheduler = optim.lr_scheduler.CosineAnnealingLR(cnn_optimizer, T_max=args.epochs_cnn)
    bce_loss = nn.BCEWithLogitsLoss(pos_weight=pos_weight_tensor)

    cnn_train_dataset = ClinicalCNNDataset(train_data, word_to_ix, icd_codes)
    cnn_val_dataset = ClinicalCNNDataset(val_data, word_to_ix, icd_codes)
    
    cnn_train_loader = DataLoader(cnn_train_dataset, batch_size=32, shuffle=True, num_workers=num_workers, pin_memory=pin_memory, worker_init_fn=seed_worker, generator=g)
    cnn_val_loader = DataLoader(cnn_val_dataset, batch_size=32, num_workers=num_workers, pin_memory=pin_memory)

    best_macro_f1 = -1.0
    patience_counter = 0
    
    for epoch in range(args.epochs_cnn):
        cnn_model.train()
        total_loss = 0
        for batch in cnn_train_loader:
            input_ids = batch["input_ids"].to(device)
            targets = batch["labels"].to(device)

            cnn_optimizer.zero_grad()
            logits = cnn_model(input_ids)
            loss = bce_loss(logits, targets)
            if loss.dim() > 0:
                loss = loss.mean()
            loss.backward()
            cnn_optimizer.step()
            total_loss += loss.item()
            
        cnn_scheduler.step()
        
        # Calculate Validation metrics
        cnn_model.eval()
        all_val_probs = []
        all_val_targets = []
        with torch.no_grad():
            for batch in cnn_val_loader:
                input_ids = batch["input_ids"].to(device)
                targets = batch["labels"].to(device)
                logits = cnn_model(input_ids)
                probs = torch.sigmoid(logits)
                all_val_probs.append(probs.cpu().numpy())
                all_val_targets.append(targets.cpu().numpy())
                
        all_val_probs = np.concatenate(all_val_probs, axis=0)
        all_val_targets = np.concatenate(all_val_targets, axis=0)
        
        val_preds = (all_val_probs >= 0.5).astype(int)
        from sklearn.metrics import f1_score as sk_f1_score
        val_macro_f1 = sk_f1_score(all_val_targets, val_preds, average='macro', zero_division=0)
        
        print(f"CNN Epoch {epoch+1}/{args.epochs_cnn} | Loss: {total_loss/len(cnn_train_loader):.4f} | Val Macro-F1: {val_macro_f1*100:.2f}%")
        
        if val_macro_f1 > best_macro_f1:
            best_macro_f1 = val_macro_f1
            torch.save(cnn_model.state_dict(), os.path.join(args.checkpoints_dir, "cnn_icd10_classifier.pt"))
            patience_counter = 0
            print(f"  [+] Validation Macro-F1 improved. Saved weights.")
        else:
            patience_counter += 1
            if patience_counter >= args.patience:
                print(f"  [!] Early stopping triggered.")
                break

    best_cnn_pt = os.path.join(args.checkpoints_dir, "cnn_icd10_classifier.pt")
    if os.path.exists(best_cnn_pt):
        cnn_model.load_state_dict(torch.load(best_cnn_pt))

    # ----------------------------------------------------
    # Model Evaluations on Test Set
    # ----------------------------------------------------
    print("\n" + "="*50 + "\n[*] Phase D: Final evaluation on Test Splits\n" + "="*50)
    
    # 1. Evaluate BioBERT NER
    test_dataset = ClinicalDataset(test_data, tokenizer, tag_to_ix, icd_codes)
    test_loader = DataLoader(test_dataset, batch_size=args.batch_size, num_workers=num_workers, pin_memory=pin_memory)
    config_b_f1, config_b_prec, config_b_rec, config_b_report = evaluate_ner_seqeval(ner_model, test_loader, ix_to_tag, device)
    
    # 2. Evaluate GloVe NER
    test_word_dataset = ClinicalWordDataset(test_data, word_to_ix, tag_to_ix)
    test_word_loader = DataLoader(test_word_dataset, batch_size=args.batch_size, num_workers=num_workers, pin_memory=pin_memory)
    config_a_f1, config_a_prec, config_a_rec, config_a_report = evaluate_ner_seqeval(ner_model_glove, test_word_loader, ix_to_tag, device)

    print("=== Config B (BioBERT) Evaluation Report ===")
    print(config_b_report)
    print("\n=== Config A (GloVe) Evaluation Report ===")
    print(config_a_report)

    # Print Comparison Table
    print("\n=== Embedding Comparison Table ===")
    print(f"| Metric     | Config A (GloVe) | Config B (BioBERT) | Delta    |")
    print(f"|------------|------------------|--------------------|----------|")
    print(f"| Precision  | {config_a_prec*100:.2f}%           | {config_b_prec*100:.2f}%             | {((config_b_prec - config_a_prec)*100):+.2f}%  |")
    print(f"| Recall     | {config_a_rec*100:.2f}%           | {config_b_rec*100:.2f}%             | {((config_b_rec - config_a_rec)*100):+.2f}%  |")
    print(f"| Entity F1  | {config_a_f1*100:.2f}%           | {config_b_f1*100:.2f}%             | {((config_b_f1 - config_a_f1)*100):+.2f}%  |")

    # Generate NER confusion matrices heatmaps on disk
    y_true_a, y_pred_a = get_ner_flat_predictions(ner_model_glove, test_word_loader, ix_to_tag, device)
    y_true_b, y_pred_b = get_ner_flat_predictions(ner_model, test_loader, ix_to_tag, device)
    
    ner_classes = [tag for tag in tag_list if tag not in ["<START>", "<STOP>"]]
    save_ner_confusion_matrices(y_true_a, y_pred_a, y_true_b, y_pred_b, ner_classes, os.path.join(args.checkpoints_dir, "ner_confusion_matrices.png"))

    # 3. Evaluate CNN classifier with tuned thresholds
    cnn_test_dataset = ClinicalCNNDataset(test_data, word_to_ix, icd_codes)
    cnn_test_loader = DataLoader(cnn_test_dataset, batch_size=32, num_workers=num_workers, pin_memory=pin_memory)
    
    print("\n[*] Tuning CNN thresholds on validation split...")
    tuned_thresholds = tune_cnn_thresholds(cnn_model, cnn_val_loader, device)
    
    # Save tuned thresholds
    with open(os.path.join(args.checkpoints_dir, "tuned_thresholds.json"), "w") as f:
        json.dump(dict(zip(icd_codes, [float(t) for t in tuned_thresholds])), f)
        
    print("\n[*] Evaluating CNN classifier on test split...")
    all_targets, all_preds = evaluate_cnn_classifier(cnn_model, cnn_test_loader, tuned_thresholds, icd_codes, device)
    
    # Save CNN classification matrices heatmap on disk
    save_confusion_matrices(all_targets, all_preds, icd_codes, os.path.join(args.checkpoints_dir, "cnn_confusion_matrices.png"))
    
    print("\n[+] Training and evaluation stages successfully finished.")

if __name__ == "__main__":
    main()
