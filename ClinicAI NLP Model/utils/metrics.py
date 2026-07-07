import numpy as np
import torch
from sklearn.metrics import accuracy_score, hamming_loss, f1_score, classification_report, multilabel_confusion_matrix, confusion_matrix

# Use Agg backend for matplotlib to prevent blocking interactive GUI displays in non-desktop runs
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns

def get_entities_bio(seq):
    """
    Extracts entities from a sequence of BIO tags.
    
    Args:
        seq: List of tag strings (e.g., ['B-Chemical', 'I-Chemical', 'O'])
    Returns:
        List of tuples: (start_idx, end_idx, entity_type)
    """
    entities = []
    curr_type = None
    curr_start = None
    for i, tag in enumerate(seq):
        if tag == 'O':
            if curr_type is not None:
                entities.append((curr_start, i - 1, curr_type))
                curr_type = None
                curr_start = None
        elif tag.startswith('B-'):
            if curr_type is not None:
                entities.append((curr_start, i - 1, curr_type))
            curr_type = tag.split('-')[1]
            curr_start = i
        elif tag.startswith('I-'):
            tag_type = tag.split('-')[1]
            if curr_type is not None:
                if tag_type != curr_type:
                    entities.append((curr_start, i - 1, curr_type))
                    curr_type = tag_type
                    curr_start = i
            else:
                curr_type = tag_type
                curr_start = i
    if curr_type is not None:
        entities.append((curr_start, len(seq) - 1, curr_type))
    return entities

def decode_model(model, input_ids, mask, labels=None):
    """
    Decodes predictions from a model, handling potential DataParallel wrapper.
    """
    if hasattr(model, 'module'):
        return model.module.decode(input_ids, mask, labels)
    return model.decode(input_ids, mask, labels)

def evaluate_ner_seqeval(model, dataloader, ix_to_tag_local, device):
    """
    Runs entity-level (micro) evaluation for NER taggers.
    Computes precision, recall, F1, and prints a classification report.
    """
    model.eval()
    true_tags_all = []
    pred_tags_all = []

    with torch.no_grad():
        for batch in dataloader:
            input_ids = batch["input_ids"].to(device)
            mask = batch["attention_mask"].to(device)
            labels = batch["labels"].to(device)
            
            paths = decode_model(model, input_ids, mask, labels)

            for i, path in enumerate(paths):
                # Filter out padding tokens coded as -100
                gold = [g for g in labels[i].tolist() if g != -100]
                gold_strs = [ix_to_tag_local.get(g, "O") for g in gold]
                pred_strs = [ix_to_tag_local.get(p, "O") for p in path]

                # Align sizes
                if len(pred_strs) < len(gold_strs):
                    pred_strs += ["O"] * (len(gold_strs) - len(pred_strs))
                else:
                    pred_strs = pred_strs[:len(gold_strs)]

                true_tags_all.append(gold_strs)
                pred_tags_all.append(pred_strs)

    true_entities_count = 0
    pred_entities_count = 0
    true_positives = 0
    types = set()
    true_by_type = {}
    pred_by_type = {}
    tp_by_type = {}

    for true_seq, pred_seq in zip(true_tags_all, pred_tags_all):
        true_ents = get_entities_bio(true_seq)
        pred_ents = get_entities_bio(pred_seq)
        true_entities_count += len(true_ents)
        pred_entities_count += len(pred_ents)
        
        true_set = set(true_ents)
        pred_set = set(pred_ents)
        tp = len(true_set.intersection(pred_set))
        true_positives += tp
        
        for ent in true_ents:
            etype = ent[2]
            types.add(etype)
            true_by_type[etype] = true_by_type.get(etype, 0) + 1
        for ent in pred_ents:
            etype = ent[2]
            types.add(etype)
            pred_by_type[etype] = pred_by_type.get(etype, 0) + 1
        for ent in true_set.intersection(pred_set):
            etype = ent[2]
            tp_by_type[etype] = tp_by_type.get(etype, 0) + 1

    precision = true_positives / pred_entities_count if pred_entities_count > 0 else 0.0
    recall = true_positives / true_entities_count if true_entities_count > 0 else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0

    report_lines = []
    report_lines.append(f"{'Entity Type':<20} {'Precision':<10} {'Recall':<10} {'F1-Score':<10} {'Support':<10}")
    report_lines.append('-' * 65)
    for etype in sorted(list(types)):
        tp_t = tp_by_type.get(etype, 0)
        true_t = true_by_type.get(etype, 0)
        pred_t = pred_by_type.get(etype, 0)
        p_t = tp_t / pred_t if pred_t > 0 else 0.0
        r_t = tp_t / true_t if true_t > 0 else 0.0
        f1_t = 2 * p_t * r_t / (p_t + r_t) if (p_t + r_t) > 0 else 0.0
        report_lines.append(f"{etype:<20} {p_t:<10.4f} {r_t:<10.4f} {f1_t:<10.4f} {true_t:<10}")
    report_lines.append('-' * 65)
    report_lines.append(f"{'micro avg':<20} {precision:<10.4f} {recall:<10.4f} {f1:<10.4f} {true_entities_count:<10}")
    report = '\n'.join(report_lines)
    
    return f1, precision, recall, report

def tune_cnn_thresholds(model, dataloader, device):
    """
    Computes class-specific decision thresholds optimizing validation F1.
    """
    model.eval()
    all_probs = []
    all_targets = []
    
    with torch.no_grad():
        for batch in dataloader:
            input_ids = batch["input_ids"].to(device)
            targets = batch["labels"].to(device)
            logits = model(input_ids)
            probs = torch.sigmoid(logits)
            all_probs.append(probs.cpu().numpy())
            all_targets.append(targets.cpu().numpy())
    
    all_probs = np.concatenate(all_probs, axis=0)
    all_targets = np.concatenate(all_targets, axis=0)
    
    num_classes = all_probs.shape[1]
    best_thresholds = np.full(num_classes, 0.5)
    
    for c in range(num_classes):
        best_f1 = -1.0
        best_t = 0.5
        for t in np.arange(0.1, 0.91, 0.05):
            preds = (all_probs[:, c] >= t).astype(int)
            f1 = f1_score(all_targets[:, c], preds, zero_division=0)
            if f1 > best_f1:
                best_f1 = f1
                best_t = t
        best_thresholds[c] = best_t
        
    return best_thresholds

def evaluate_cnn_classifier(model, dataloader, thresholds, label_list, device):
    """
    Runs multi-label evaluation checks on the CNN classifier on a test set.
    """
    model.eval()
    all_probs = []
    all_targets = []
    with torch.no_grad():
        for batch in dataloader:
            input_ids = batch["input_ids"].to(device)
            targets = batch["labels"].to(device)
            logits = model(input_ids)
            probs = torch.sigmoid(logits)
            all_probs.append(probs.cpu().numpy())
            all_targets.append(targets.cpu().numpy())
            
    all_probs = np.concatenate(all_probs, axis=0)
    all_targets = np.concatenate(all_targets, axis=0)
    
    # Apply class-specific thresholds
    all_preds = np.zeros_like(all_probs)
    for c in range(all_probs.shape[1]):
        all_preds[:, c] = (all_probs[:, c] >= thresholds[c]).astype(int)
        
    sub_acc = accuracy_score(all_targets, all_preds)
    h_loss = hamming_loss(all_targets, all_preds)
    f1_micro = f1_score(all_targets, all_preds, average='micro', zero_division=0)
    f1_macro = f1_score(all_targets, all_preds, average='macro', zero_division=0)
    f1_weighted = f1_score(all_targets, all_preds, average='weighted', zero_division=0)

    print("=== CNN ICD-10 Classifier Test Metrics ===")
    print(f"Subset Accuracy: {sub_acc*100:.2f}%")
    print(f"Hamming Loss: {h_loss:.4f}")
    print(f"Micro F1: {f1_micro*100:.2f}%")
    print(f"Macro F1: {f1_macro*100:.2f}%")
    print(f"Weighted F1: {f1_weighted*100:.2f}%")
    print("\nClassification Report (per class):")
    print(classification_report(all_targets, all_preds, target_names=label_list, zero_division=0))
    
    return all_targets, all_preds

def save_confusion_matrices(all_targets, all_preds, label_list, output_path="checkpoints/cnn_confusion_matrices.png"):
    """
    Saves heatmap confusion matrices for the top 15 most frequent classes to disk.
    """
    mcm = multilabel_confusion_matrix(all_targets, all_preds)
    class_frequencies = all_targets.sum(axis=0)
    top_15_indices = np.argsort(class_frequencies)[::-1][:15]
    
    fig, axes = plt.subplots(3, 5, figsize=(18, 11))
    axes = axes.flatten()
    
    for idx, class_idx in enumerate(top_15_indices):
        matrix = mcm[class_idx]
        code_name = label_list[class_idx]
        support = class_frequencies[class_idx]
        
        sns.heatmap(matrix, annot=True, fmt='d', cmap='Oranges', cbar=False,
                    xticklabels=['Negative', 'Positive'], yticklabels=['Negative', 'Positive'], ax=axes[idx])
        axes[idx].set_title(f"Code: {code_name} (Support: {int(support)})")
        axes[idx].set_ylabel('True Label')
        axes[idx].set_xlabel('Predicted Label')
        
    for idx in range(len(top_15_indices), len(axes)):
        axes[idx].axis('off')
        
    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()
    print(f"[+] Multi-label confusion matrices saved to: {output_path}")

def get_ner_flat_predictions(model, dataloader, ix_to_tag_local, device):
    """
    Extracts flat sequences of true and predicted tags for token-level validation.
    """
    model.eval()
    y_true = []
    y_pred = []
    with torch.no_grad():
        for batch in dataloader:
            input_ids = batch["input_ids"].to(device)
            mask = batch["attention_mask"].to(device)
            labels = batch["labels"].to(device)
            paths = decode_model(model, input_ids, mask, labels)
            for i, path in enumerate(paths):
                gold = [g for g in labels[i].tolist() if g != -100]
                gold_strs = [ix_to_tag_local.get(g, "O") for g in gold]
                pred_strs = [ix_to_tag_local.get(p, "O") for p in path]
                if len(pred_strs) < len(gold_strs):
                    pred_strs += ["O"] * (len(gold_strs) - len(pred_strs))
                else:
                    pred_strs = pred_strs[:len(gold_strs)]
                y_true.extend(gold_strs)
                y_pred.extend(pred_strs)
    return y_true, y_pred

def save_ner_confusion_matrices(y_true_a, y_pred_a, y_true_b, y_pred_b, ner_classes, output_path="checkpoints/ner_confusion_matrices.png"):
    """
    Saves a side-by-side token confusion matrix comparison between Config A and Config B.
    """
    cm_a = confusion_matrix(y_true_a, y_pred_a, labels=ner_classes)
    cm_b = confusion_matrix(y_true_b, y_pred_b, labels=ner_classes)
    
    fig, axes = plt.subplots(1, 2, figsize=(16, 7))
    sns.heatmap(cm_a, annot=True, fmt='d', xticklabels=ner_classes, yticklabels=ner_classes, cmap='Blues', ax=axes[0])
    axes[0].set_title('Config A (GloVe) NER Token-level Confusion Matrix')
    axes[0].set_ylabel('True Tag')
    axes[0].set_xlabel('Predicted Tag')
    
    sns.heatmap(cm_b, annot=True, fmt='d', xticklabels=ner_classes, yticklabels=ner_classes, cmap='Greens', ax=axes[1])
    axes[1].set_title('Config B (BioBERT) NER Token-level Confusion Matrix')
    axes[1].set_ylabel('True Tag')
    axes[1].set_xlabel('Predicted Tag')
    
    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()
    print(f"[+] NER token-level confusion matrices saved to: {output_path}")
