import argparse
import random
import os
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
from sklearn.metrics import precision_score, recall_score, f1_score, roc_auc_score

# ===========================================================================
# 1. Config System
# ===========================================================================
class Config:
    """
    Configuration hyperparameters for loading model & running inference.
    Aligned with clinicai_v2.0 configurations.
    """
    CLASSES = [
        "Atelectasis", "Cardiomegaly", "Effusion", "Infiltration",
        "Mass", "Nodule", "Pneumonia", "Pneumothorax",
        "Consolidation", "Edema", "Emphysema", "Fibrosis",
        "Pleural_Thickening", "Hernia",
    ]
    NUM_CLASSES = len(CLASSES)
    
    # Image parameters
    IMG_SIZE = 320
    MEAN = [0.485, 0.456, 0.406]
    STD = [0.229, 0.224, 0.225]
    
    # Backbone parameters
    BACKBONE = "convnext_base"
    PRETRAINED = False # Set to False by default for inference testing to avoid redownloading ImageNet weights
    DROP_RATE = 0.2
    DROP_PATH_RATE = 0.1
    
    # Default Paths
    DATA_DIR = Path("/kaggle/input/nih-chest-xrays-data")
    IMAGE_DIR = DATA_DIR / "images"
    META_CSV = DATA_DIR / "Data_Entry_2017_v2020.csv"


# ===========================================================================
# 2. Model Architecture
# ===========================================================================
class ChestXrayModel(nn.Module):
    """
    Modular multi-label classification head on top of a timm backbone.
    """
    def __init__(self, cfg: Config):
        super().__init__()
        self.cfg = cfg

        # Build backbone via timm
        self.backbone = timm.create_model(
            cfg.BACKBONE,
            pretrained=cfg.PRETRAINED,
            num_classes=0,           # remove classification head
            global_pool="avg",       # global average pooling
            drop_rate=cfg.DROP_RATE,
            drop_path_rate=cfg.DROP_PATH_RATE,
        )
        num_features = self.backbone.num_features
        print(f"Backbone : {cfg.BACKBONE}  |  Features : {num_features}")

        # Classification head
        self.head = nn.Sequential(
            nn.LayerNorm(num_features),
            nn.Dropout(p=cfg.DROP_RATE),
            nn.Linear(num_features, 512),
            nn.GELU(),
            nn.Dropout(p=cfg.DROP_RATE / 2),
            nn.Linear(512, cfg.NUM_CLASSES),
        )
        self._init_head()

    def _init_head(self) -> None:
        """Xavier initialization on head linear layers."""
        for m in self.head.modules():
            if isinstance(m, nn.Linear):
                nn.init.xavier_uniform_(m.weight)
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x : [B, 3, H, W] input images (normalized)
        Returns [B, NUM_CLASSES] raw logits (no activation).
        """
        features = self.backbone(x)     # [B, num_features]
        logits = self.head(features)    # [B, NUM_CLASSES]
        return logits


# ===========================================================================
# 3. Data Pipeline / Dataset & Preprocessing Transforms
# ===========================================================================
def build_val_transforms(cfg: Config) -> A.Compose:
    """Returns the Albumentations validation transform pipeline."""
    return A.Compose([
        A.Resize(cfg.IMG_SIZE, cfg.IMG_SIZE, always_apply=True),
        A.Normalize(mean=cfg.MEAN, std=cfg.STD, always_apply=True),
        ToTensorV2(always_apply=True),
    ])


class InferenceTestDataset(Dataset):
    """
    PyTorch Dataset built specifically for testing.
    Loads real images when available, falls back to generating a mock image if not.
    """
    def __init__(self, df: pd.DataFrame, image_dir: Path, transform: A.Compose, cfg: Config):
        self.df = df.reset_index(drop=True)
        self.image_dir = image_dir
        self.transform = transform
        self.cfg = cfg
        self.labels = df[cfg.CLASSES].values.astype(np.float32)

    def __len__(self) -> int:
        return len(self.df)

    def __getitem__(self, idx: int):
        row = self.df.iloc[idx]
        img_path = self.image_dir / row["Image Index"]
        
        # Load image with grayscale -> RGB conversion
        if img_path.exists():
            img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
            if img is None:
                img = np.zeros((self.cfg.IMG_SIZE, self.cfg.IMG_SIZE), dtype=np.uint8)
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
        else:
            # Generate deterministic noise pattern as mock chest X-ray
            np.random.seed(idx)
            img = np.random.randint(40, 200, (512, 512), dtype=np.uint8)
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
            
        augmented = self.transform(image=img)
        image_tensor = augmented["image"]
        label_tensor = torch.from_numpy(self.labels[idx])
        
        return image_tensor, label_tensor, row["Image Index"]


# ===========================================================================
# 4. Helper function to find best_model.pth
# ===========================================================================
def find_checkpoint(checkpoint_path: str = None) -> Path:
    """Checks input path and fallbacks to locate the best checkpoint file."""
    if checkpoint_path:
        ckpt_p = Path(checkpoint_path)
        if ckpt_p.exists():
            return ckpt_p
            
    possible_paths = [
        Path("/kaggle/input/notebooks/agnefits/clinicai-v2-0/checkpoints/best_model.pth"),
        Path("/kaggle/working/checkpoints/best_model.pth"),
        Path("checkpoints/best_model.pth"),
        Path("best_model.pth"),
    ]
    
    if checkpoint_path:
        possible_paths.insert(0, Path(checkpoint_path))
        
    for path in possible_paths:
        if path.exists():
            return path
            
    return None


# ===========================================================================
# 5. Core Test Inference Runner (Batch / Multiple Images)
# ===========================================================================
def test_inference_on_batch(
    num_samples: int = 50,
    checkpoint_path: str = None,
    meta_csv_path: str = None,
    image_dir_path: str = None,
    threshold: float = 0.5,
    device: str = "cuda" if torch.cuda.is_available() else "cpu"
):
    """
    Main evaluation pipeline:
      1. Loads metadata, resolving image existence.
      2. Initializes model & loads best checkpoint.
      3. Loads and evaluates multiple images in parallel using PyTorch DataLoader.
      4. Calculates multi-label accuracy metrics (Hamming & Exact Match) and per-class metrics.
    """
    cfg = Config()
    device = torch.device(device)
    
    csv_path = Path(meta_csv_path) if meta_csv_path else cfg.META_CSV
    img_dir = Path(image_dir_path) if image_dir_path else cfg.IMAGE_DIR
    
    # 1. Locate Checkpoint
    resolved_checkpoint = find_checkpoint(checkpoint_path)
    
    # 2. Metadata Processing
    print(f"\n[1/4] Loading metadata from: {csv_path}")
    if not csv_path.exists():
        print(f"ERROR: Metadata CSV not found at '{csv_path}'. Please check paths.")
        return
        
    df_raw = pd.read_csv(csv_path)
    df_raw["Patient ID"] = df_raw["Image Index"].apply(lambda x: int(x.split("_")[0]))
    df = df_raw.copy()
    for cls in cfg.CLASSES:
        df[cls] = df["Finding Labels"].apply(lambda x: 1 if cls in x.split("|") else 0)
        
    # Check physical file existence and prioritize existing images
    print("Checking for existing images on disk...")
    df["File_Exists"] = df["Image Index"].apply(lambda x: (img_dir / x).exists())
    existing_count = df["File_Exists"].sum()
    print(f"Found {existing_count} images on disk out of {len(df)} total dataset entries.")
    
    # Filter dataset to prefer existing images, fallback to random rows if none exist
    if existing_count > 0:
        available_df = df[df["File_Exists"]].sample(n=min(num_samples, existing_count), random_state=42)
        if len(available_df) < num_samples:
            # Fill the rest with mock images
            remaining = num_samples - len(available_df)
            mock_df = df[~df["File_Exists"]].sample(n=remaining, random_state=42)
            available_df = pd.concat([available_df, mock_df])
    else:
        print("WARNING: No image files found on disk. Testing entirely using mock/synthetic image data.")
        available_df = df.sample(n=num_samples, random_state=42)
        
    print(f"Selected {len(available_df)} images for batch inference testing.")
    
    # 3. Load Model
    print(f"\n[2/4] Loading ChestXrayModel ({cfg.BACKBONE})...")
    if resolved_checkpoint:
        cfg.PRETRAINED = False # Skip downloading pretrained model weight
    model = ChestXrayModel(cfg).to(device)
    
    if resolved_checkpoint:
        print(f"  Loading weights from checkpoint: {resolved_checkpoint}")
        try:
            checkpoint = torch.load(resolved_checkpoint, map_location=device)
            if isinstance(checkpoint, dict):
                if "ema" in checkpoint:
                    model.load_state_dict(checkpoint["ema"])
                elif "model" in checkpoint:
                    model.load_state_dict(checkpoint["model"])
                else:
                    model.load_state_dict(checkpoint)
            else:
                model.load_state_dict(checkpoint)
            print("  Successfully loaded model weights.")
        except Exception as e:
            print(f"ERROR: Failed to load state dict from checkpoint: {e}")
            print("  Running test with randomly initialized weights.")
    else:
        print("  WARNING: No checkpoint path found. Model outputs will be random.")
        
    model.eval()
    
    # 4. Run Batch Inference
    print(f"\n[3/4] Running forward passes in batches on {device}...")
    transform = build_val_transforms(cfg)
    test_ds = InferenceTestDataset(available_df, img_dir, transform, cfg)
    
    # Batch size selected to run quickly and safely fit on small GPUs
    batch_size = min(32, num_samples)
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False, num_workers=0)
    
    all_probs = []
    all_labels = []
    
    with torch.no_grad():
        autocast_enabled = (device.type == "cuda")
        for images, labels, _ in test_loader:
            images = images.to(device)
            with torch.cuda.amp.autocast(enabled=autocast_enabled):
                logits = model(images)
            probs = torch.sigmoid(logits)
            all_probs.append(probs.cpu().numpy())
            all_labels.append(labels.numpy())
            
    all_probs = np.concatenate(all_probs, axis=0)  # [num_samples, 14]
    all_labels = np.concatenate(all_labels, axis=0) # [num_samples, 14]
    
    # Apply Threshold to get Binary Predictions
    all_preds = (all_probs >= threshold).astype(np.float32)
    
    # 5. Calculate Metrics
    print("\n[4/4] Calculating prediction accuracy metrics...")
    
    # Subset Accuracy: Strict match (exact match of all 14 labels)
    subset_acc = np.all(all_preds == all_labels, axis=1).mean() * 100
    
    # Hamming Accuracy: Percentage of correct individual labels (1 - Hamming Loss)
    hamming_acc = (all_preds == all_labels).mean() * 100
    
    print("\n" + "=" * 70)
    print(f"              BATCH EVALUATION REPORT (N={num_samples})")
    print("=" * 70)
    if resolved_checkpoint:
        print(f"Checkpoint Loaded  : {resolved_checkpoint}")
    else:
        print("Checkpoint Loaded  : None (Random Initialization)")
    print(f"Decision Threshold : {threshold}")
    print(f"Subset Accuracy    : {subset_acc:.2f}% (Strict - all 14 labels must match)")
    print(f"Hamming Accuracy   : {hamming_acc:.2f}% (Percentage of all labels correct)")
    print("-" * 70)
    print(f"  {'Pathology Class':<22} | {'Accuracy':<10} | {'Precision':<10} | {'Recall':<8} | {'ROC-AUC':<8}")
    print("-" * 70)
    
    per_class_metrics = {}
    for i, cls in enumerate(cfg.CLASSES):
        y_t = all_labels[:, i]
        y_p = all_preds[:, i]
        y_prob = all_probs[:, i]
        
        # Calculations
        class_acc = (y_p == y_t).mean()
        class_prec = precision_score(y_t, y_p, zero_division=0)
        class_rec = recall_score(y_t, y_p, zero_division=0)
        
        # ROC-AUC calculation requires both classes to be present in batch
        if len(np.unique(y_t)) > 1:
            class_auc = roc_auc_score(y_t, y_prob)
            auc_str = f"{class_auc:.4f}"
        else:
            class_auc = np.nan
            auc_str = "N/A*"
            
        print(f"  {cls:<22} | {class_acc:<10.2%} | {class_prec:<10.4f} | {class_rec:<8.4f} | {auc_str:<8}")
        per_class_metrics[cls] = {
            "accuracy": class_acc,
            "precision": class_prec,
            "recall": class_rec,
            "auc": class_auc
        }
    print("=" * 70)
    print("Note: ROC-AUC is 'N/A*' if the sample subset does not contain both positive and")
    print("negative ground truth cases for that class.")
    print("=" * 70)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Batch inference testing and accuracy calculation for ClinicAI.")
    parser.add_argument("--num-samples", type=int, default=50, 
                        help="Number of images to load and evaluate (e.g. 50, 100, 500).")
    parser.add_argument("--checkpoint", type=str, default=None, 
                        help="Optional specific path to model checkpoint file (.pth).")
    parser.add_argument("--csv", type=str, default=None, 
                        help="Optional path to Data_Entry_2017_v2020.csv metadata file.")
    parser.add_argument("--image-dir", type=str, default=None, 
                        help="Optional path to the directory containing NIH chest X-ray images.")
    parser.add_argument("--threshold", type=float, default=0.5, 
                        help="Threshold for classification (default: 0.5).")
    parser.add_argument("--device", type=str, default="cuda" if torch.cuda.is_available() else "cpu",
                        help="Device to run inference on (cuda/cpu).")
    
    args, _ = parser.parse_known_args()
    
    test_inference_on_batch(
        num_samples=args.num_samples,
        checkpoint_path=args.checkpoint,
        meta_csv_path=args.csv,
        image_dir_path=args.image_dir,
        threshold=args.threshold,
        device=args.device
    )
