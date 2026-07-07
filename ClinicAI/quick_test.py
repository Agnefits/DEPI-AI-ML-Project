import argparse
import random
import sys
import time
import cv2
import timm
import albumentations as A
from albumentations.pytorch import ToTensorV2
from pathlib import Path
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score

# ===========================================================================
# 1. Config System & Rebuilding Model
# ===========================================================================
class Config:
    def __init__(self, d=None):
        self.CLASSES = ["Atelectasis", "Cardiomegaly", "Effusion", "Infiltration", "Mass", "Nodule", "Pneumonia", "Pneumothorax", "Consolidation", "Edema", "Emphysema", "Fibrosis", "Pleural_Thickening", "Hernia"]
        self.NUM_CLASSES, self.IMG_SIZE, self.MEAN, self.STD = 14, 320, [0.485, 0.456, 0.406], [0.229, 0.224, 0.225]
        self.BACKBONE, self.DROP_RATE, self.DROP_PATH_RATE, self.PRETRAINED = "convnext_base", 0.2, 0.1, False
        self.DEFAULT_THRESHOLDS = {
            "Atelectasis": 0.40, "Cardiomegaly": 0.35, "Effusion": 0.40, "Infiltration": 0.45,
            "Mass": 0.35, "Nodule": 0.35, "Pneumonia": 0.20, "Pneumothorax": 0.30,
            "Consolidation": 0.30, "Edema": 0.25, "Emphysema": 0.30, "Fibrosis": 0.25,
            "Pleural_Thickening": 0.25, "Hernia": 0.25
        }
        if d:
            for k, v in d.items(): setattr(self, k, v)


class ChestXrayModel(nn.Module):
    def __init__(self, cfg):
        super().__init__()
        self.backbone = timm.create_model(cfg.BACKBONE, pretrained=cfg.PRETRAINED, num_classes=0, global_pool="avg", drop_rate=cfg.DROP_RATE, drop_path_rate=cfg.DROP_PATH_RATE)
        self.head = nn.Sequential(
            nn.LayerNorm(self.backbone.num_features), nn.Dropout(p=cfg.DROP_RATE),
            nn.Linear(self.backbone.num_features, 512), nn.GELU(),
            nn.Dropout(p=cfg.DROP_RATE / 2), nn.Linear(512, cfg.NUM_CLASSES)
        )
    def forward(self, x): return self.head(self.backbone(x))


class NIHTestDataset(Dataset):
    def __init__(self, df, image_map, transform, cfg):
        self.df, self.image_map, self.transform, self.cfg = df.reset_index(drop=True), image_map, transform, cfg
        self.labels = df[cfg.CLASSES].values.astype(np.float32)
    def __len__(self): return len(self.df)
    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        img_path = self.image_map[row["Image Index"]]
        img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
        if img is None: raise FileNotFoundError(f"Failed to read: {img_path}")
        return self.transform(image=cv2.cvtColor(img, cv2.COLOR_GRAY2RGB))["image"], torch.tensor(self.labels[idx])


# ===========================================================================
# 2. Dynamic BFS File & Image Resolver (Up to Depth 8)
# ===========================================================================
def find_file(names, roots):
    for root in roots:
        if not root.exists(): continue
        queue = [root]
        for _ in range(8):
            next_queue = []
            for cur in queue:
                if cur.name in ("notebooks", "working", "checkpoints") or cur.name.startswith("."):
                    continue
                for name in names:
                    p = cur / name
                    if p.is_file(): return p
                try:
                    for child in cur.iterdir():
                        if child.is_dir(): next_queue.append(child)
                except Exception: pass
            queue = next_queue
    return None


def get_image_map(csv_path, custom_dir=None):
    image_map = {}
    if custom_dir:
        d = Path(custom_dir)
        for f in d.iterdir():
            if f.is_file() and f.suffix.lower() in (".png", ".jpg", ".jpeg"):
                image_map[f.name] = f
        return image_map

    if not csv_path:
        return image_map
        
    dataset_root = Path(csv_path).parent
    
    # Check flat images directory
    flat_dir = dataset_root / "images"
    if flat_dir.is_dir():
        for f in flat_dir.iterdir():
            if f.is_file() and f.suffix.lower() in (".png", ".jpg", ".jpeg"):
                image_map[f.name] = f
        if image_map:
            return image_map

    # Check distributed directories
    for i in range(1, 13):
        for sub in [f"images_{i:03d}/images", f"images_{i:03d}"]:
            d = dataset_root / sub
            if d.is_dir():
                for f in d.iterdir():
                    if f.is_file() and f.suffix.lower() in (".png", ".jpg", ".jpeg"):
                        image_map[f.name] = f
                break
    return image_map


# ===========================================================================
# 3. Metrics Evaluation
# ===========================================================================
def compute_metrics(y_true, y_pred, y_prob, classes):
    per_class, valid_aucs, class_weights = {}, [], []
    for i, cls in enumerate(classes):
        yt, yp, ypr = y_true[:, i], y_pred[:, i], y_prob[:, i]
        acc, prec, rec, f1 = accuracy_score(yt, yp), precision_score(yt, yp, zero_division=0), recall_score(yt, yp, zero_division=0), f1_score(yt, yp, zero_division=0)
        auc_str = "N/A"
        if len(np.unique(yt)) > 1:
            auc = roc_auc_score(yt, ypr)
            valid_aucs.append(auc)
            class_weights.append(yt.sum())
            auc_str = f"{auc:.4f}"
        per_class[cls] = {"accuracy": acc, "precision": prec, "recall": rec, "f1": f1, "auc": auc_str}
        
    macro = np.mean(valid_aucs) if valid_aucs else 0.0
    weighted = sum(a * w for a, w in zip(valid_aucs, class_weights)) / sum(class_weights) if valid_aucs and sum(class_weights) > 0 else macro
    try: micro = roc_auc_score(y_true.ravel(), y_prob.ravel())
    except ValueError: micro = 0.0
    return accuracy_score(y_true, y_pred) * 100, (y_true == y_pred).mean() * 100, per_class, macro, micro, weighted


# ===========================================================================
# 4. Core Evaluation Runner
# ===========================================================================
def run_evaluation():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=str, default=None)
    parser.add_argument("--csv", type=str, default=None)
    parser.add_argument("--image-dir", type=str, default=None)
    parser.add_argument("--num-samples", type=int, default=1000)
    parser.add_argument("--threshold", type=float, default=None, help="Custom global threshold override. If not set, uses checkpoint values or custom class-specific defaults.")
    parser.add_argument("--device", type=str, default="cuda" if torch.cuda.is_available() else "cpu")
    args, _ = parser.parse_known_args()
    
    device = torch.device(args.device)
    
    # ── Resolve Checkpoint ──────────────────────────────────────────────────
    ckpt_path = Path("/kaggle/input/notebooks/agnefits/clinicai-v2-0/checkpoints/best_model.pth")
    if args.checkpoint:
        ckpt_path = Path(args.checkpoint)
    elif not ckpt_path.exists():
        # Fallback roots
        ckpt_roots = [Path("/kaggle/working/checkpoints"), Path("checkpoints"), Path(".")]
        found_ckpt = find_file(["best_model.pth"], ckpt_roots)
        if found_ckpt: ckpt_path = found_ckpt
        
    if not ckpt_path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {ckpt_path}")
        
    print(f"Checkpoint loaded: {ckpt_path}")
    checkpoint = torch.load(ckpt_path, map_location=device, weights_only=False)
    cfg = Config(checkpoint.get("cfg", {}) if isinstance(checkpoint, dict) else {})
    
    # ── Rebuild Model & State Dict ──────────────────────────────────────────
    model = ChestXrayModel(cfg).to(device)
    state = checkpoint.get("ema") or checkpoint.get("model") or checkpoint if isinstance(checkpoint, dict) else checkpoint
    state = {k.replace("_orig_mod.", ""): v for k, v in state.items()}
    try: model.load_state_dict(state)
    except Exception as e:
        print(f"ERROR: Failed to load state_dict: {e}"); sys.exit(1)
    model.eval()
    
    # ── Resolve Thresholds ──────────────────────────────────────────────────
    thresholds = None
    if args.threshold is not None:
        thresholds = np.full(cfg.NUM_CLASSES, args.threshold)
        print(f"Using custom global threshold: {args.threshold:.4f}")
    else:
        if isinstance(checkpoint, dict):
            for k in ["thresholds", "metrics", "cfg"]:
                v = checkpoint.get(k)
                if v:
                    thresholds = v.get("thresholds") if k in ["metrics", "cfg"] and isinstance(v, dict) else v
                    if thresholds is not None: break
        if thresholds is None:
            thresholds = np.array([cfg.DEFAULT_THRESHOLDS.get(c, 0.5) for c in cfg.CLASSES])
            print("Using default class-specific thresholds based on optimal results.")
        else:
            thresholds = np.array([thresholds.get(c, 0.5) for c in cfg.CLASSES]) if isinstance(thresholds, dict) else np.array(thresholds)
    
    # ── Resolve Map & Metadata ──────────────────────────────────────────────
    csv_path = find_file([args.csv] if args.csv else ["Data_Entry_2017.csv", "Data_Entry_2017_v2020.csv"], [Path("/kaggle/input"), Path("."), Path("..")])
    if not csv_path:
        print("ERROR: Metadata CSV file not found. Stopping."); sys.exit(1)
    image_map = get_image_map(csv_path, args.image_dir)
        
    df = pd.read_csv(csv_path)
    for c in cfg.CLASSES: df[c] = df["Finding Labels"].apply(lambda x: 1 if c in x.split("|") else 0)
    
    skipped = [n for n in df["Image Index"].tolist() if n not in image_map]
    df_existing = df[df["Image Index"].isin(image_map)].reset_index(drop=True)
    if len(df_existing) == 0:
        print("ERROR: 0 images physically found on disk. Stopping."); sys.exit(1)
        
    df_eval = df_existing.sample(n=min(args.num_samples, len(df_existing)), random_state=42).reset_index(drop=True)
    for _, r in df_eval.iterrows():
        if not image_map[r["Image Index"]].exists():
            print(f"ERROR: File vanished from disk: {image_map[r['Image Index']]}"); sys.exit(1)
            
    # ── Inference Loop ──────────────────────────────────────────────────────
    transform = A.Compose([A.Resize(cfg.IMG_SIZE, cfg.IMG_SIZE), A.Normalize(mean=cfg.MEAN, std=cfg.STD), ToTensorV2()])
    ds = NIHTestDataset(df_eval, image_map, transform, cfg)
    loader = DataLoader(ds, batch_size=64, shuffle=False, num_workers=4, pin_memory=True, persistent_workers=True)
    
    all_probs, all_labels = [], []
    start = time.time()
    with torch.inference_mode():
        autocast_enabled = (device.type == "cuda")
        for x, y in loader:
            x = x.to(device)
            with torch.amp.autocast('cuda', enabled=autocast_enabled): logits = model(x)
            all_probs.append(torch.sigmoid(logits).cpu().numpy())
            all_labels.append(y.numpy())
            
    elapsed = time.time() - start
    all_probs, all_labels = np.concatenate(all_probs), np.concatenate(all_labels)
    all_preds = (all_probs >= thresholds).astype(np.float32)
    
    # ── Compute and Print Report ────────────────────────────────────────────
    sub, ham, per, macro, micro, weighted = compute_metrics(all_labels, all_preds, all_probs, cfg.CLASSES)
    
    print(f"Number of images tested: {len(df_eval)}")
    print(f"Inference time: {elapsed:.2f} seconds | Images/sec: {len(df_eval) / elapsed:.2f}\n")
    print("=" * 90)
    print(f"  {'Pathology Class':<22} | {'Accuracy':<8} | {'Precision':<9} | {'Recall':<8} | {'F1':<8} | {'ROC-AUC':<8} | {'Threshold':<9}")
    print("-" * 90)
    for i, c in enumerate(cfg.CLASSES):
        m = per[c]
        print(f"  {c:<22} | {m['accuracy']:<8.2%} | {m['precision']:<9.4f} | {m['recall']:<8.4f} | {m['f1']:<8.4f} | {m['auc']:<8} | {thresholds[i]:<9.4f}")
    print("-" * 90)
    print(f"  {'OVERALL MICRO':<22} | {'-':<8} | {'-':<9} | {'-':<8} | {'-':<8} | {micro:<8.4f} | {'-':<9}")
    print(f"  {'OVERALL MACRO':<22} | {'-':<8} | {'-':<9} | {'-':<8} | {'-':<8} | {macro:<8.4f} | {'-':<9}")
    print(f"  {'OVERALL WEIGHTED':<22} | {'-':<8} | {'-':<9} | {'-':<8} | {'-':<8} | {weighted:<8.4f} | {'-':<9}")
    print("-" * 90)
    print(f"  Subset Accuracy: {sub:.2f}%  |  Hamming Accuracy: {ham:.2f}%")
    print("=" * 90)
    
    print("\n[DEBUGGING SUMMARY]")
    print(f"  Number of images found: {len(df) - len(skipped)}")
    print(f"  Number skipped: {len(skipped)} | Number evaluated: {len(df_eval)}")
    if skipped:
        print("First 20 skipped filenames:")
        for name in skipped[:20]: print(f"  - {name}")
    print("=" * 60)


if __name__ == "__main__":
    run_evaluation()
