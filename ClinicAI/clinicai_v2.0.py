# =============================================================================
# ClinicAI v2.0  —  NIH ChestX-ray14  |  Kaggle Grandmaster Pipeline
# =============================================================================
# Author   : ClinicAI Team
# Dataset  : NIH ChestX-ray14  (112 120 frontal chest X-rays, 14 diseases)
# Task     : Multi-label classification of 14 thoracic pathologies
# Target   : Macro ROC-AUC > 0.84
# Platform : Kaggle (P100 / T4 / L4 GPU)
# =============================================================================
#
# Sections
# --------
#  1. Environment Setup & Package Installation
#  2. Reproducibility & Global Config
#  3. Dataset Analysis & EDA
#  4. Patient-Wise Data Split (Iterative Multilabel Stratification)
#  5. Data Pipeline (Albumentations Augmentations)
#  6. DataLoader (Optimised for Kaggle)
#  7. Model Architecture (Modular Backbone Framework)
#  8. Loss Functions (Weighted BCE / Focal / Asymmetric)
#  9. Optimiser (AdamW + Weight Decay)
# 10. Scheduler (Cosine Annealing + Warmup / OneCycleLR)
# 11. Training Loop (AMP + Grad-Accum + EMA + Early-Stop + Checkpointing)
# 12. Metrics (ROC-AUC macro/micro, AP, P/R/F1, Confusion Matrix)
# 13. Threshold Optimisation (per-class Youden's J)
# 14. Test-Time Augmentation (TTA)
# 15. Explainability (GradCAM overlays)
# 16. Inference Pipeline (single image / batch / submission CSV)
# 17. Error Analysis (FP / FN / hard / uncertain)
# 18. Training Tricks (Label Smoothing / EMA / Mixup / CutMix)
# 19. Performance Optimisation (torch.compile / channels_last / cudnn)
# 20. Final Report (best epoch, GPU memory, per-class AUC, thresholds)
#
# =============================================================================


# ===========================================================================
# SECTION 1 — Environment Setup & Package Installation
# ===========================================================================
# On Kaggle most of these are pre-installed; we only install what is missing.
# We pin versions so the notebook stays reproducible when kernel images change.

import subprocess, sys

def pip_install(*packages):
    """Install packages silently; skip if already present."""
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "--quiet", "--upgrade", *packages]
    )

# Uncomment on Kaggle if you need the latest versions:
# pip_install("timm>=0.9.12", "albumentations>=1.3.1", "grad-cam>=1.4.8",
#             "iterstrat>=0.1.7", "wandb>=0.16.0")

# ---------------------------------------------------------------------------
# Standard library
import os, gc, math, time, json, random, warnings, copy
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from typing import Dict, List, Optional, Tuple, Union

# Data science
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")                         # headless backend for Kaggle
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import seaborn as sns
from PIL import Image

# Computer vision
import cv2

# PyTorch
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from torch.cuda.amp import GradScaler, autocast
import torchvision.transforms as T

# timm  — state-of-the-art model zoo
import timm

# Albumentations — fast GPU-friendly augmentations
import albumentations as A
from albumentations.pytorch import ToTensorV2

# scikit-learn
from sklearn.metrics import (
    roc_auc_score, average_precision_score,
    precision_score, recall_score, f1_score,
    confusion_matrix, roc_curve,
)
from sklearn.model_selection import train_test_split

# pytorch-grad-cam
try:
    from pytorch_grad_cam import GradCAM
    from pytorch_grad_cam.utils.image import show_cam_on_image
    from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget
    GRADCAM_AVAILABLE = True
except ImportError:
    GRADCAM_AVAILABLE = False
    print("WARNING: GradCAM not available - Section 15 will be skipped.")

# iterstrat — iterative multilabel stratification
try:
    from iterstrat.ml_stratifiers import MultilabelStratifiedShuffleSplit
    ITERSTRAT_AVAILABLE = True
except ImportError:
    ITERSTRAT_AVAILABLE = False
    print("WARNING: iterstrat not available - falling back to random patient split.")

# Weights & Biases (optional)
try:
    import wandb
    WANDB_AVAILABLE = True
except ImportError:
    WANDB_AVAILABLE = False

warnings.filterwarnings("ignore")
print("All imports successful.")


# ===========================================================================
# SECTION 2 — Reproducibility & Global Config
# ===========================================================================

class Config:
    """
    Single source-of-truth for every hyper-parameter and path.
    Change values here; every module below reads from this object.
    """
    # ── Paths ──────────────────────────────────────────────────────────────
    DATA_DIR        = Path("/kaggle/input/nih-chest-xrays-data")
    IMAGE_DIR       = DATA_DIR / "images"
    META_CSV        = DATA_DIR / "Data_Entry_2017_v2020.csv"
    BBOX_CSV        = DATA_DIR / "BBox_List_2017.csv"
    SPLIT_FILE      = DATA_DIR / "train_val_list.txt"
    OUTPUT_DIR      = Path("/kaggle/working")
    CHECKPOINT_DIR  = OUTPUT_DIR / "checkpoints"
    GRAD_CAM_DIR    = OUTPUT_DIR / "gradcam"

    # ── Disease labels (14 pathologies) ────────────────────────────────────
    CLASSES = [
        "Atelectasis", "Cardiomegaly", "Effusion", "Infiltration",
        "Mass", "Nodule", "Pneumonia", "Pneumothorax",
        "Consolidation", "Edema", "Emphysema", "Fibrosis",
        "Pleural_Thickening", "Hernia",
    ]
    NUM_CLASSES = len(CLASSES)          # 14

    # ── Image ───────────────────────────────────────────────────────────────
    IMG_SIZE        = 320              # ConvNeXt-Base sweet-spot on P100
    MEAN            = [0.485, 0.456, 0.406]
    STD             = [0.229, 0.224, 0.225]

    # ── Training ────────────────────────────────────────────────────────────
    EPOCHS          = 30
    BATCH_SIZE      = 32               # effective batch = BATCH * ACCUM_STEPS
    ACCUM_STEPS     = 2                # gradient accumulation steps
    NUM_WORKERS     = 4
    PIN_MEMORY      = True
    PERSISTENT_WORKERS = True
    PREFETCH_FACTOR = 2

    # ── Optimiser ───────────────────────────────────────────────────────────
    LR              = 3e-4
    LR_MIN          = 1e-6
    WEIGHT_DECAY    = 1e-2
    GRAD_CLIP       = 1.0

    # ── Scheduler ───────────────────────────────────────────────────────────
    SCHEDULER       = "cosine_warmup"  # "cosine_warmup" | "onecycle"
    WARMUP_EPOCHS   = 3

    # ── Model ───────────────────────────────────────────────────────────────
    BACKBONE        = "convnext_base"  # default backbone
    PRETRAINED      = True
    DROP_RATE       = 0.2
    DROP_PATH_RATE  = 0.1

    # ── Loss ────────────────────────────────────────────────────────────────
    LOSS            = "asymmetric"     # "bce" | "focal" | "asymmetric"
    LABEL_SMOOTH    = 0.05

    # ── Asymmetric Loss ─────────────────────────────────────────────────────
    ASL_GAMMA_NEG   = 4
    ASL_GAMMA_POS   = 1
    ASL_CLIP        = 0.05

    # ── Focal Loss ──────────────────────────────────────────────────────────
    FOCAL_GAMMA     = 2.0
    FOCAL_ALPHA     = 0.25

    # ── EMA ─────────────────────────────────────────────────────────────────
    EMA_DECAY       = 0.9998

    # ── Augmentation ────────────────────────────────────────────────────────
    USE_MIXUP       = True
    MIXUP_ALPHA     = 0.4
    USE_CUTMIX      = True
    CUTMIX_ALPHA    = 1.0

    # ── Early Stopping ──────────────────────────────────────────────────────
    PATIENCE        = 7
    MIN_DELTA       = 1e-4

    # ── TTA ─────────────────────────────────────────────────────────────────
    TTA_SCALES      = [288, 320, 352]

    # ── Misc ────────────────────────────────────────────────────────────────
    SEED            = 42
    AMP             = True             # Automatic Mixed Precision
    CHANNELS_LAST   = True             # memory-format optimisation
    COMPILE         = False            # torch.compile (PyTorch >= 2.0)
    CUDNN_BENCHMARK = True
    WANDB           = False            # set True + fill project name to enable

    # ── WandB ───────────────────────────────────────────────────────────────
    WANDB_PROJECT   = "clinicai-chestxray14"
    WANDB_RUN_NAME  = f"convnext_base_{datetime.now().strftime('%Y%m%d_%H%M')}"


CFG = Config()

# ── Create output directories ───────────────────────────────────────────────
CFG.CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
CFG.GRAD_CAM_DIR.mkdir(parents=True, exist_ok=True)


def set_seed(seed: int = 42) -> None:
    """
    Make training fully deterministic.
    Note: determinism may slightly reduce throughput; acceptable on Kaggle.
    """
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True   # reproducible conv results
    torch.backends.cudnn.benchmark     = CFG.CUDNN_BENCHMARK  # auto-tune kernels
    os.environ["PYTHONHASHSEED"]       = str(seed)

set_seed(CFG.SEED)

# ── Device ──────────────────────────────────────────────────────────────────
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device : {DEVICE}")
if DEVICE.type == "cuda":
    print(f"  GPU    : {torch.cuda.get_device_name(0)}")
    print(f"  VRAM   : {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")


# ===========================================================================
# SECTION 3 — Dataset Analysis & EDA
# ===========================================================================

class DataAnalyser:
    """
    Encapsulates all exploratory data analysis for the NIH ChestX-ray14 dataset.
    Produces publication-ready figures saved to CFG.OUTPUT_DIR.
    """

    def __init__(self, df: pd.DataFrame, cfg: Config):
        self.df  = df
        self.cfg = cfg
        sns.set_theme(style="darkgrid", palette="muted")

    # ------------------------------------------------------------------
    def _parse_labels(self) -> pd.DataFrame:
        """
        Expand pipe-delimited Finding Labels into binary columns.
        Returns the original dataframe with 14 additional binary columns.
        """
        df = self.df.copy()
        for cls in self.cfg.CLASSES:
            df[cls] = df["Finding Labels"].apply(
                lambda x: 1 if cls in x.split("|") else 0
            )
        return df

    # ------------------------------------------------------------------
    def run(self) -> pd.DataFrame:
        """Execute all EDA steps and return the augmented dataframe."""
        df = self._parse_labels()
        self._plot_class_distribution(df)
        self._plot_cooccurrence(df)
        self._plot_patient_distribution(df)
        self._plot_view_position(df)
        self._plot_sample_images(df)
        self._print_imbalance_stats(df)
        return df

    # ------------------------------------------------------------------
    def _plot_class_distribution(self, df: pd.DataFrame) -> None:
        counts = df[self.cfg.CLASSES].sum().sort_values(ascending=False)
        fig, ax = plt.subplots(figsize=(14, 5))
        bars = ax.bar(counts.index, counts.values,
                      color=plt.cm.viridis(np.linspace(0.2, 0.9, len(counts))))
        ax.set_title("Class Distribution — NIH ChestX-ray14", fontsize=15, fontweight="bold")
        ax.set_ylabel("Number of Images")
        ax.set_xticklabels(counts.index, rotation=45, ha="right")
        for bar, val in zip(bars, counts.values):
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 100,
                    f"{val:,}", ha="center", va="bottom", fontsize=8)
        plt.tight_layout()
        plt.savefig(self.cfg.OUTPUT_DIR / "class_distribution.png", dpi=150)
        plt.close()
        print("Saved: class_distribution.png")

    # ------------------------------------------------------------------
    def _plot_cooccurrence(self, df: pd.DataFrame) -> None:
        label_mat = df[self.cfg.CLASSES].values
        co = (label_mat.T @ label_mat).astype(float)
        diag = np.diag(co)
        with np.errstate(divide="ignore", invalid="ignore"):
            co_norm = co / diag[:, None]
        np.fill_diagonal(co_norm, 0.0)

        fig, ax = plt.subplots(figsize=(12, 10))
        sns.heatmap(co_norm, xticklabels=self.cfg.CLASSES, yticklabels=self.cfg.CLASSES,
                    annot=True, fmt=".2f", cmap="YlOrRd", ax=ax, linewidths=0.3)
        ax.set_title("Disease Co-occurrence Matrix  (P(col | row))",
                     fontsize=13, fontweight="bold")
        plt.tight_layout()
        plt.savefig(self.cfg.OUTPUT_DIR / "cooccurrence_matrix.png", dpi=150)
        plt.close()
        print("Saved: cooccurrence_matrix.png")

    # ------------------------------------------------------------------
    def _plot_patient_distribution(self, df: pd.DataFrame) -> None:
        imgs_per_patient = df.groupby("Patient ID").size()
        fig, axes = plt.subplots(1, 2, figsize=(14, 4))

        axes[0].hist(imgs_per_patient.values, bins=40, color="#4C72B0", edgecolor="white")
        axes[0].set_title("Images per Patient")
        axes[0].set_xlabel("Number of Images")
        axes[0].set_ylabel("Number of Patients")

        n_patients = len(df["Patient ID"].unique())
        half = n_patients // 2
        axes[1].pie(
            [half, n_patients - half],
            labels=["First Half Patients", "Second Half Patients"],
            autopct="%1.1f%%", colors=["#4C72B0", "#DD8452"]
        )
        axes[1].set_title("Patient Data Distribution")
        plt.suptitle("Patient-Level Analysis", fontsize=13, fontweight="bold")
        plt.tight_layout()
        plt.savefig(self.cfg.OUTPUT_DIR / "patient_distribution.png", dpi=150)
        plt.close()
        print("Saved: patient_distribution.png")

    # ------------------------------------------------------------------
    def _plot_view_position(self, df: pd.DataFrame) -> None:
        vc = df["View Position"].value_counts()
        fig, ax = plt.subplots(figsize=(6, 4))
        ax.pie(vc.values, labels=vc.index, autopct="%1.1f%%",
               colors=["#4C72B0", "#DD8452", "#55A868"])
        ax.set_title("View Position Distribution", fontsize=13, fontweight="bold")
        plt.tight_layout()
        plt.savefig(self.cfg.OUTPUT_DIR / "view_position.png", dpi=150)
        plt.close()
        print("Saved: view_position.png")

    # ------------------------------------------------------------------
    def _plot_sample_images(self, df: pd.DataFrame) -> None:
        """Display one representative image for each disease class."""
        fig, axes = plt.subplots(2, 7, figsize=(22, 7))
        axes = axes.flatten()
        for i, cls in enumerate(self.cfg.CLASSES):
            subset = df[df[cls] == 1]["Image Index"].values
            if len(subset) == 0:
                axes[i].axis("off")
                continue
            img_path = self.cfg.IMAGE_DIR / random.choice(subset)
            if img_path.exists():
                img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
                axes[i].imshow(img, cmap="gray")
            else:
                axes[i].axis("off")
            axes[i].set_title(cls, fontsize=9, fontweight="bold")
            axes[i].axis("off")
        plt.suptitle("Representative Images — One per Disease", fontsize=14, fontweight="bold")
        plt.tight_layout()
        plt.savefig(self.cfg.OUTPUT_DIR / "sample_images.png", dpi=150)
        plt.close()
        print("Saved: sample_images.png")

    # ------------------------------------------------------------------
    def _print_imbalance_stats(self, df: pd.DataFrame) -> None:
        total   = len(df)
        pos     = df[self.cfg.CLASSES].sum()
        neg     = total - pos
        ratio   = (neg / pos).rename("neg:pos ratio")
        stats   = pd.concat([pos.rename("# Positive"), neg.rename("# Negative"),
                              ratio, (pos / total * 100).rename("Prevalence %")], axis=1)
        stats   = stats.sort_values("# Positive", ascending=False)
        print("\nClass Imbalance Statistics")
        print("=" * 65)
        print(stats.to_string())
        print("=" * 65)


# ===========================================================================
# SECTION 4 — Patient-Wise Data Split
# ===========================================================================

class DataSplitter:
    """
    Performs a STRICT patient-wise train/val split.
    No patient's images may appear in both sets.

    Strategy
    --------
    1. Aggregate per-patient label vectors (OR over all their images).
    2. Use MultilabelStratifiedShuffleSplit (iterstrat) so the validation
       set has similar class prevalence to the training set.
    3. Fall back to random patient split if iterstrat is unavailable.
    """

    def __init__(self, df: pd.DataFrame, cfg: Config, val_ratio: float = 0.15):
        self.df        = df
        self.cfg       = cfg
        self.val_ratio = val_ratio

    # ------------------------------------------------------------------
    def split(self) -> Tuple[pd.DataFrame, pd.DataFrame]:
        patient_ids = self.df["Patient ID"].unique()
        print(f"Total patients : {len(patient_ids):,}")

        # Per-patient aggregated label matrix
        patient_labels = (
            self.df.groupby("Patient ID")[self.cfg.CLASSES]
            .max()           # OR — patient is "positive" if any image shows it
            .reset_index()
        )

        if ITERSTRAT_AVAILABLE:
            splitter = MultilabelStratifiedShuffleSplit(
                n_splits=1, test_size=self.val_ratio, random_state=self.cfg.SEED
            )
            X = patient_labels["Patient ID"].values.reshape(-1, 1)
            y = patient_labels[self.cfg.CLASSES].values
            train_idx, val_idx = next(splitter.split(X, y))
            train_patients = patient_labels.iloc[train_idx]["Patient ID"].values
            val_patients   = patient_labels.iloc[val_idx]["Patient ID"].values
            print("Used iterative multilabel stratification.")
        else:
            train_patients, val_patients = train_test_split(
                patient_ids, test_size=self.val_ratio,
                random_state=self.cfg.SEED, shuffle=True
            )
            print("Used random patient split (iterstrat unavailable).")

        train_df = self.df[self.df["Patient ID"].isin(train_patients)].reset_index(drop=True)
        val_df   = self.df[self.df["Patient ID"].isin(val_patients)].reset_index(drop=True)

        # Sanity check — no patient overlap
        assert len(set(train_df["Patient ID"]) & set(val_df["Patient ID"])) == 0, \
            "ERROR: Patient leakage detected!"

        print(f"Train images : {len(train_df):,}  ({len(train_patients):,} patients)")
        print(f"Val   images : {len(val_df):,}  ({len(val_patients):,} patients)")
        return train_df, val_df


# ===========================================================================
# SECTION 5 — Data Pipeline (Albumentations)
# ===========================================================================

def build_transforms(mode: str, cfg: Config) -> A.Compose:
    """
    Factory that returns an Albumentations pipeline for a given mode.

    Design choices
    --------------
    * CLAHE (Contrast Limited Adaptive Histogram Equalisation) significantly
      boosts performance on chest X-rays by improving local contrast.
    * GaussianNoise and CoarseDropout act as strong regularisers.
    * We use the ImageNet mean/std because all backbones were pre-trained
      on ImageNet; the images are converted to 3-channel RGB beforehand.
    """
    mean, std = cfg.MEAN, cfg.STD

    if mode == "train":
        return A.Compose([
            # ── Spatial ─────────────────────────────────────────────────
            A.Resize(cfg.IMG_SIZE + 32, cfg.IMG_SIZE + 32, always_apply=True),
            A.RandomResizedCrop(
                height=cfg.IMG_SIZE, width=cfg.IMG_SIZE,
                scale=(0.75, 1.0), ratio=(0.85, 1.15), p=1.0
            ),
            A.HorizontalFlip(p=0.5),
            A.ShiftScaleRotate(
                shift_limit=0.05, scale_limit=0.1,
                rotate_limit=10, border_mode=cv2.BORDER_REFLECT, p=0.5
            ),
            # ── Intensity ────────────────────────────────────────────────
            A.CLAHE(clip_limit=2.0, tile_grid_size=(8, 8), p=0.5),
            A.RandomBrightnessContrast(
                brightness_limit=0.15, contrast_limit=0.15, p=0.5
            ),
            A.GaussNoise(var_limit=(5.0, 30.0), p=0.3),
            A.GaussianBlur(blur_limit=(3, 5), p=0.1),
            # ── Regularisation ───────────────────────────────────────────
            A.CoarseDropout(
                max_holes=8, max_height=cfg.IMG_SIZE // 16,
                max_width=cfg.IMG_SIZE // 16, fill_value=0, p=0.2
            ),
            # ── Normalisation ────────────────────────────────────────────
            A.Normalize(mean=mean, std=std, always_apply=True),
            ToTensorV2(always_apply=True),
        ])

    elif mode in ("val", "test"):
        return A.Compose([
            A.Resize(cfg.IMG_SIZE, cfg.IMG_SIZE, always_apply=True),
            A.Normalize(mean=mean, std=std, always_apply=True),
            ToTensorV2(always_apply=True),
        ])

    else:
        raise ValueError(f"Unknown mode: {mode}")


def build_tta_transforms(scale: int, cfg: Config) -> A.Compose:
    """
    TTA transform for a single scale.
    Horizontal flip during TTA inference is applied externally
    in the TTA loop to average flipped and non-flipped predictions.
    """
    return A.Compose([
        A.Resize(scale, scale, always_apply=True),
        A.Normalize(mean=cfg.MEAN, std=cfg.STD, always_apply=True),
        ToTensorV2(always_apply=True),
    ])


# ===========================================================================
# SECTION 6 — Dataset Class & DataLoader
# ===========================================================================

class ChestXray14Dataset(Dataset):
    """
    PyTorch Dataset for the NIH ChestX-ray14 dataset.

    Parameters
    ----------
    df          : DataFrame with columns [Image Index, Patient ID, <CLASSES>]
    image_dir   : directory containing all .png images
    transform   : Albumentations Compose pipeline
    cfg         : Config object
    """

    def __init__(self, df: pd.DataFrame, image_dir: Path,
                 transform: A.Compose, cfg: Config):
        self.df        = df.reset_index(drop=True)
        self.image_dir = image_dir
        self.transform = transform
        self.cfg       = cfg
        # Pre-compute label matrix as float32 numpy array for speed
        self.labels    = df[cfg.CLASSES].values.astype(np.float32)

    def __len__(self) -> int:
        return len(self.df)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
        row       = self.df.iloc[idx]
        img_path  = self.image_dir / row["Image Index"]

        # Load as grayscale, convert to 3-channel RGB (ImageNet expects RGB)
        img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            # Fallback: return a black image rather than crash the entire run
            img = np.zeros((self.cfg.IMG_SIZE, self.cfg.IMG_SIZE), dtype=np.uint8)
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)

        augmented = self.transform(image=img)
        image     = augmented["image"]                 # torch.float32 [3, H, W]
        label     = torch.from_numpy(self.labels[idx]) # torch.float32 [14]
        return image, label

    def get_pos_weight(self) -> torch.Tensor:
        """
        Compute positive-class weights for BCEWithLogitsLoss.
        pos_weight[i] = (#negatives for class i) / (#positives for class i)
        Capped at 100 to avoid numerical instability.
        """
        pos    = self.labels.sum(axis=0)
        neg    = len(self.labels) - pos
        with np.errstate(divide="ignore"):
            weight = np.where(pos > 0, neg / pos, 100.0)
        return torch.tensor(weight, dtype=torch.float32)


def build_dataloader(dataset: Dataset, batch_size: int, shuffle: bool,
                     cfg: Config) -> DataLoader:
    """
    Construct an optimised DataLoader for Kaggle GPU kernels.

    Key optimisations
    -----------------
    * pin_memory=True         : data is page-locked for faster CPU->GPU transfer
    * persistent_workers=True : worker processes survive across epochs
    * prefetch_factor=2       : each worker pre-fetches 2 batches ahead
    * num_workers=4           : Kaggle gives 4 CPU threads per GPU kernel
    """
    return DataLoader(
        dataset,
        batch_size         = batch_size,
        shuffle            = shuffle,
        num_workers        = cfg.NUM_WORKERS,
        pin_memory         = cfg.PIN_MEMORY,
        persistent_workers = cfg.PERSISTENT_WORKERS and cfg.NUM_WORKERS > 0,
        prefetch_factor    = cfg.PREFETCH_FACTOR if cfg.NUM_WORKERS > 0 else None,
        drop_last          = shuffle,       # drop last incomplete train batch
    )


# ===========================================================================
# SECTION 7 — Model Architecture
# ===========================================================================

class ChestXrayModel(nn.Module):
    """
    Modular multi-label classification head on top of any timm backbone.

    Supported backbones (pass as cfg.BACKBONE)
    -------------------------------------------
    * "convnext_base"                    — ConvNeXt-Base   (default)
    * "tf_efficientnetv2_m"              — EfficientNetV2-M
    * "densenet121"                      — DenseNet-121  (CheXNet baseline)
    * "swin_base_patch4_window7_224"     — Swin-B Transformer
    * "convnext_small"                   — ConvNeXt-Small  (faster)
    * "tf_efficientnetv2_s"              — EfficientNetV2-S (faster)

    Architecture
    ------------
    backbone -> Global Average Pool -> LayerNorm -> Dropout ->
    Linear(512) -> GELU -> Dropout -> Linear(NUM_CLASSES)

    Raw logits are output (no sigmoid). Use BCEWithLogitsLoss,
    FocalLoss, or AsymmetricLoss during training for numerical stability.
    """

    def __init__(self, cfg: Config):
        super().__init__()
        self.cfg = cfg

        # ── Build backbone via timm ──────────────────────────────────────
        self.backbone = timm.create_model(
            cfg.BACKBONE,
            pretrained      = cfg.PRETRAINED,
            num_classes     = 0,           # remove classification head
            global_pool     = "avg",       # global average pooling
            drop_rate       = cfg.DROP_RATE,
            drop_path_rate  = cfg.DROP_PATH_RATE,
        )
        num_features = self.backbone.num_features
        print(f"Backbone : {cfg.BACKBONE}  |  Features : {num_features}")

        # ── Classification head ─────────────────────────────────────────
        self.head = nn.Sequential(
            nn.LayerNorm(num_features),
            nn.Dropout(p=cfg.DROP_RATE),
            nn.Linear(num_features, 512),
            nn.GELU(),
            nn.Dropout(p=cfg.DROP_RATE / 2),
            nn.Linear(512, cfg.NUM_CLASSES),
        )
        self._init_head()

    # ------------------------------------------------------------------
    def _init_head(self) -> None:
        """Xavier initialisation on head linear layers."""
        for m in self.head.modules():
            if isinstance(m, nn.Linear):
                nn.init.xavier_uniform_(m.weight)
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

    # ------------------------------------------------------------------
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        x : [B, 3, H, W]  input images (normalised)
        Returns [B, NUM_CLASSES] raw logits (no activation).
        """
        features = self.backbone(x)     # [B, num_features]
        logits   = self.head(features)  # [B, NUM_CLASSES]
        return logits

    # ------------------------------------------------------------------
    def get_gradcam_layer(self) -> nn.Module:
        """Return the last convolutional layer suitable for GradCAM."""
        if "convnext" in self.cfg.BACKBONE:
            return self.backbone.stages[-1].blocks[-1]
        elif "densenet" in self.cfg.BACKBONE:
            return self.backbone.features.denseblock4
        elif "efficientnet" in self.cfg.BACKBONE:
            return self.backbone.blocks[-1]
        elif "swin" in self.cfg.BACKBONE:
            return self.backbone.layers[-1].blocks[-1]
        else:
            # Generic fallback: last module with weight
            for module in reversed(list(self.backbone.modules())):
                if hasattr(module, "weight"):
                    return module
            return self.backbone

    # ------------------------------------------------------------------
    @torch.no_grad()
    def predict_proba(self, x: torch.Tensor) -> torch.Tensor:
        """Return sigmoid probabilities for inference."""
        self.eval()
        logits = self(x)
        return torch.sigmoid(logits)

    # ------------------------------------------------------------------
    def param_count(self) -> int:
        return sum(p.numel() for p in self.parameters())

    def trainable_param_count(self) -> int:
        return sum(p.numel() for p in self.parameters() if p.requires_grad)


# ===========================================================================
# SECTION 8 — Loss Functions
# ===========================================================================

class WeightedBCELoss(nn.Module):
    """
    Weighted Binary Cross Entropy with optional label smoothing.

    Label smoothing replaces hard targets {0, 1} with soft targets
    {eps/2, 1-eps/2}, reducing over-confidence and improving calibration.
    """
    def __init__(self, pos_weight: torch.Tensor, label_smooth: float = 0.05):
        super().__init__()
        self.register_buffer("pos_weight", pos_weight)
        self.smooth = label_smooth

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        if self.smooth > 0:
            targets = targets * (1 - self.smooth) + 0.5 * self.smooth
        return F.binary_cross_entropy_with_logits(
            logits, targets, pos_weight=self.pos_weight, reduction="mean"
        )


class FocalLoss(nn.Module):
    """
    Sigmoid Focal Loss (Lin et al., 2017 — RetinaNet).

    Reduces the contribution of easy negatives so the model focuses
    on hard, mis-classified examples — extremely useful for rare diseases.

    FL(p) = -alpha * (1-p)^gamma * log(p)   for positives
    FL(p) = -(1-alpha) * p^gamma * log(1-p) for negatives
    """
    def __init__(self, gamma: float = 2.0, alpha: float = 0.25,
                 label_smooth: float = 0.05):
        super().__init__()
        self.gamma  = gamma
        self.alpha  = alpha
        self.smooth = label_smooth

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        if self.smooth > 0:
            targets = targets * (1 - self.smooth) + 0.5 * self.smooth
        probs = torch.sigmoid(logits)
        bce   = F.binary_cross_entropy_with_logits(logits, targets, reduction="none")
        pt    = probs * targets + (1 - probs) * (1 - targets)
        alpha = self.alpha * targets + (1 - self.alpha) * (1 - targets)
        focal = alpha * (1 - pt) ** self.gamma * bce
        return focal.mean()


class AsymmetricLoss(nn.Module):
    """
    Asymmetric Loss (Ridnik et al., 2021 — ASL).

    Key insight: in multi-label problems, false negatives (missing a disease)
    are far more costly than false positives.  ASL uses different focusing
    parameters for positives and negatives:
      - gamma_pos (small, e.g. 1): mild downweighting of easy positives
      - gamma_neg (large, e.g. 4): aggressive downweighting of easy negatives
    Probability shifting clip: squeezes p_neg to [0, 1-m] to remove
    very confident negatives from the gradient entirely.

    State-of-the-art for multi-label medical imaging (consistently beats BCE
    and Focal Loss on CheXpert, NIH ChestX-ray14, etc.).
    """
    def __init__(self, gamma_neg: int = 4, gamma_pos: int = 1,
                 clip: float = 0.05, label_smooth: float = 0.05):
        super().__init__()
        self.gamma_neg = gamma_neg
        self.gamma_pos = gamma_pos
        self.clip      = clip
        self.smooth    = label_smooth

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        if self.smooth > 0:
            targets = targets * (1 - self.smooth) + 0.5 * self.smooth

        xs_pos = torch.sigmoid(logits)
        xs_neg = 1 - xs_pos

        # Probability shifting: clip easy negatives
        if self.clip is not None and self.clip > 0:
            xs_neg = (xs_neg + self.clip).clamp(max=1.0)

        los_pos = targets       * torch.log(xs_pos.clamp(min=1e-8))
        los_neg = (1 - targets) * torch.log(xs_neg.clamp(min=1e-8))
        loss    = los_pos + los_neg

        # Asymmetric focusing
        if self.gamma_neg > 0 or self.gamma_pos > 0:
            pt0             = xs_pos * targets
            pt1             = xs_neg * (1 - targets)
            pt              = pt0 + pt1
            one_sided_gamma = self.gamma_pos * targets + self.gamma_neg * (1 - targets)
            one_sided_w     = torch.pow(1 - pt, one_sided_gamma)
            loss           *= one_sided_w

        return -loss.sum() / logits.size(0)


def build_loss(cfg: Config, pos_weight: Optional[torch.Tensor] = None) -> nn.Module:
    """Factory: instantiate and return the configured loss function."""
    if cfg.LOSS == "bce":
        assert pos_weight is not None, "pos_weight required for WeightedBCELoss"
        return WeightedBCELoss(pos_weight.to(DEVICE), cfg.LABEL_SMOOTH)
    elif cfg.LOSS == "focal":
        return FocalLoss(cfg.FOCAL_GAMMA, cfg.FOCAL_ALPHA, cfg.LABEL_SMOOTH)
    elif cfg.LOSS == "asymmetric":
        return AsymmetricLoss(cfg.ASL_GAMMA_NEG, cfg.ASL_GAMMA_POS,
                              cfg.ASL_CLIP, cfg.LABEL_SMOOTH)
    else:
        raise ValueError(f"Unknown loss: {cfg.LOSS}")


# ===========================================================================
# SECTION 9 — Optimiser
# ===========================================================================

def build_optimiser(model: nn.Module, cfg: Config) -> torch.optim.Optimizer:
    """
    AdamW with decoupled weight decay.

    Layer-wise learning rates (LLRD)
    ---------------------------------
    - backbone : lr * 0.1   (fine-tune conservatively; weights are pre-trained)
    - head     : lr * 1.0   (train aggressively; weights are randomly initialised)

    This is a standard technique from BERT fine-tuning applied to vision.
    """
    backbone_params = list(model.backbone.parameters())
    head_params     = list(model.head.parameters())

    param_groups = [
        {"params": backbone_params, "lr": cfg.LR * 0.1, "name": "backbone"},
        {"params": head_params,     "lr": cfg.LR,       "name": "head"},
    ]
    return torch.optim.AdamW(param_groups, weight_decay=cfg.WEIGHT_DECAY)


# ===========================================================================
# SECTION 10 — Scheduler
# ===========================================================================

class CosineWarmupScheduler(torch.optim.lr_scheduler._LRScheduler):
    """
    Cosine annealing with linear warmup.

    Warmup phase : LR increases linearly 0 -> base_lr over warmup_epochs.
    Cosine phase : LR decays base_lr -> lr_min following a cosine curve.

    Warmup prevents divergence at the start of training when the head
    weights are randomly initialised and gradients are large.
    """
    def __init__(self, optimiser: torch.optim.Optimizer, warmup_epochs: int,
                 total_epochs: int, lr_min: float = 1e-6, last_epoch: int = -1):
        self.warmup_epochs = warmup_epochs
        self.total_epochs  = total_epochs
        self.lr_min        = lr_min
        super().__init__(optimiser, last_epoch)

    def get_lr(self) -> List[float]:
        epoch = self.last_epoch
        lrs   = []
        for base_lr in self.base_lrs:
            if epoch < self.warmup_epochs:
                # Linear warmup
                scale = (epoch + 1) / max(self.warmup_epochs, 1)
            else:
                # Cosine decay
                progress = (epoch - self.warmup_epochs) / max(
                    self.total_epochs - self.warmup_epochs, 1
                )
                scale = (self.lr_min / max(base_lr, 1e-12) +
                         0.5 * (1 - self.lr_min / max(base_lr, 1e-12)) *
                         (1 + math.cos(math.pi * progress)))
            lrs.append(base_lr * scale)
        return lrs


def build_scheduler(optimiser: torch.optim.Optimizer, cfg: Config,
                    steps_per_epoch: int = 0):
    """Factory: instantiate and return the configured LR scheduler."""
    if cfg.SCHEDULER == "cosine_warmup":
        return CosineWarmupScheduler(
            optimiser, warmup_epochs=cfg.WARMUP_EPOCHS,
            total_epochs=cfg.EPOCHS, lr_min=cfg.LR_MIN
        )
    elif cfg.SCHEDULER == "onecycle":
        assert steps_per_epoch > 0, "steps_per_epoch must be provided for OneCycleLR"
        return torch.optim.lr_scheduler.OneCycleLR(
            optimiser,
            max_lr         = [g["lr"] for g in optimiser.param_groups],
            epochs         = cfg.EPOCHS,
            steps_per_epoch= steps_per_epoch,
            pct_start      = 0.1,
            anneal_strategy= "cos",
            div_factor     = 25.0,
            final_div_factor= 1e4,
        )
    else:
        raise ValueError(f"Unknown scheduler: {cfg.SCHEDULER}")


# ===========================================================================
# SECTION 18A — EMA Model (Training Trick)
# ===========================================================================

class ModelEMA:
    """
    Maintains an Exponential Moving Average copy of model weights.

    EMA models generalise better than the final trained checkpoint because
    they average out SGD noise accumulated at the end of training.
    We use the EMA model for all validation and test inference.

    Update rule:
        theta_ema <- decay * theta_ema + (1 - decay) * theta_model
    """

    def __init__(self, model: nn.Module, decay: float = 0.9998):
        self.decay     = decay
        self.ema_model = copy.deepcopy(model)
        self.ema_model.eval()
        for p in self.ema_model.parameters():
            p.requires_grad_(False)

    @torch.no_grad()
    def update(self, model: nn.Module) -> None:
        for ema_p, model_p in zip(self.ema_model.parameters(),
                                   model.parameters()):
            ema_p.copy_(self.decay * ema_p + (1 - self.decay) * model_p.data)

    def state_dict(self) -> dict:
        return self.ema_model.state_dict()


# ===========================================================================
# SECTION 18B — Mixup & CutMix (Training Tricks)
# ===========================================================================

def mixup_data(x: torch.Tensor, y: torch.Tensor,
               alpha: float = 0.4) -> Tuple[torch.Tensor, torch.Tensor,
                                            torch.Tensor, float]:
    """
    Mixup augmentation (Zhang et al., 2018).
    Linearly interpolates two images and their labels.
    Encourages linear behaviour between training examples and acts as
    a powerful regulariser, especially for imbalanced datasets.
    """
    lam   = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    B     = x.size(0)
    idx   = torch.randperm(B, device=x.device)
    mixed = lam * x + (1 - lam) * x[idx]
    return mixed, y, y[idx], lam


def cutmix_data(x: torch.Tensor, y: torch.Tensor,
                alpha: float = 1.0) -> Tuple[torch.Tensor, torch.Tensor,
                                             torch.Tensor, float]:
    """
    CutMix augmentation (Yun et al., 2019).
    Pastes a rectangular region from one image into another.
    Stronger regulariser than Mixup because it removes content, forcing
    the model to rely on multiple regions (better localisation).
    """
    lam        = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    B, C, H, W = x.size()
    idx        = torch.randperm(B, device=x.device)
    cut_ratio  = math.sqrt(1 - lam)
    cut_h, cut_w = int(H * cut_ratio), int(W * cut_ratio)
    cx, cy     = random.randint(0, W), random.randint(0, H)
    x1 = max(cx - cut_w // 2, 0); x2 = min(cx + cut_w // 2, W)
    y1 = max(cy - cut_h // 2, 0); y2 = min(cy + cut_h // 2, H)
    mixed      = x.clone()
    mixed[:, :, y1:y2, x1:x2] = x[idx, :, y1:y2, x1:x2]
    lam        = 1 - (y2 - y1) * (x2 - x1) / (H * W)
    return mixed, y, y[idx], lam


def mixup_criterion(criterion: nn.Module, logits: torch.Tensor,
                    y_a: torch.Tensor, y_b: torch.Tensor,
                    lam: float) -> torch.Tensor:
    """Compute mixed loss: lambda * L(y_a) + (1-lambda) * L(y_b)."""
    return lam * criterion(logits, y_a) + (1 - lam) * criterion(logits, y_b)


# ===========================================================================
# SECTION 11 — Training Loop
# ===========================================================================

class EarlyStopping:
    """Stops training if monitored metric does not improve for `patience` epochs."""

    def __init__(self, patience: int = 7, min_delta: float = 1e-4,
                 mode: str = "max"):
        self.patience  = patience
        self.min_delta = min_delta
        self.mode      = mode
        self.best      = -np.inf if mode == "max" else np.inf
        self.counter   = 0
        self.stop      = False

    def __call__(self, value: float) -> bool:
        improved = (value > self.best + self.min_delta) if self.mode == "max" \
                   else (value < self.best - self.min_delta)
        if improved:
            self.best    = value
            self.counter = 0
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.stop = True
        return self.stop


class Trainer:
    """
    Orchestrates the complete training loop including:
      - AMP (Automatic Mixed Precision) with GradScaler
      - Gradient accumulation (effective_batch = batch_size x accum_steps)
      - Gradient clipping (prevents exploding gradients in early training)
      - EMA (Exponential Moving Average) model tracking
      - Mixup / CutMix data augmentation
      - Early stopping on validation AUC
      - Best checkpoint saving
      - Optional WandB metric logging
    """

    def __init__(self, model: nn.Module, train_loader: DataLoader,
                 val_loader: DataLoader, criterion: nn.Module,
                 optimiser: torch.optim.Optimizer, scheduler,
                 cfg: Config, evaluator: "Evaluator"):
        self.model        = model.to(DEVICE)
        self.train_loader = train_loader
        self.val_loader   = val_loader
        self.criterion    = criterion.to(DEVICE)
        self.optimiser    = optimiser
        self.scheduler    = scheduler
        self.cfg          = cfg
        self.evaluator    = evaluator

        self.ema          = ModelEMA(model, cfg.EMA_DECAY)
        self.scaler       = GradScaler(enabled=cfg.AMP)
        self.early_stop   = EarlyStopping(cfg.PATIENCE, cfg.MIN_DELTA, mode="max")

        self.history: Dict[str, List] = defaultdict(list)
        self.best_auc  = 0.0
        self.best_epoch = 0
        self.start_time = None

        # Memory format optimisation
        if cfg.CHANNELS_LAST and DEVICE.type == "cuda":
            self.model = self.model.to(memory_format=torch.channels_last)

        # torch.compile (PyTorch >= 2.0)
        if cfg.COMPILE and hasattr(torch, "compile") and DEVICE.type == "cuda":
            print("Applying torch.compile()...")
            self.model = torch.compile(self.model)

        # WandB initialisation
        if cfg.WANDB and WANDB_AVAILABLE:
            wandb.init(project=cfg.WANDB_PROJECT, name=cfg.WANDB_RUN_NAME,
                       config=vars(cfg))

    # ------------------------------------------------------------------
    def _train_one_epoch(self, epoch: int) -> Dict[str, float]:
        """Run one full pass through the training data."""
        self.model.train()
        total_loss = 0.0
        n_batches  = 0
        self.optimiser.zero_grad()

        for step, (images, labels) in enumerate(self.train_loader):
            images = images.to(DEVICE, non_blocking=True)
            labels = labels.to(DEVICE, non_blocking=True)

            if self.cfg.CHANNELS_LAST and DEVICE.type == "cuda":
                images = images.to(memory_format=torch.channels_last)

            # ── Mixup / CutMix (50/50 when both are enabled) ─────────
            use_mix = False
            if self.cfg.USE_MIXUP and self.cfg.USE_CUTMIX:
                use_mix    = True
                use_cutmix = random.random() < 0.5
            elif self.cfg.USE_MIXUP:
                use_mix, use_cutmix = True, False
            elif self.cfg.USE_CUTMIX:
                use_mix, use_cutmix = True, True

            if use_mix:
                if use_cutmix:
                    images, y_a, y_b, lam = cutmix_data(images, labels,
                                                         self.cfg.CUTMIX_ALPHA)
                else:
                    images, y_a, y_b, lam = mixup_data(images, labels,
                                                        self.cfg.MIXUP_ALPHA)

            # ── Forward pass + AMP ───────────────────────────────────
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(images)
                if use_mix:
                    loss = mixup_criterion(self.criterion, logits, y_a, y_b, lam)
                else:
                    loss = self.criterion(logits, labels)
                loss = loss / self.cfg.ACCUM_STEPS      # scale for accumulation

            # ── Backward pass ────────────────────────────────────────
            self.scaler.scale(loss).backward()

            # ── Gradient accumulation: update every ACCUM_STEPS ─────
            if (step + 1) % self.cfg.ACCUM_STEPS == 0 or \
               (step + 1) == len(self.train_loader):
                # Must unscale before clipping for AMP compatibility
                self.scaler.unscale_(self.optimiser)
                torch.nn.utils.clip_grad_norm_(
                    self.model.parameters(), self.cfg.GRAD_CLIP
                )
                self.scaler.step(self.optimiser)
                self.scaler.update()
                self.optimiser.zero_grad()
                self.ema.update(self.model)     # update EMA after each step

            total_loss += loss.item() * self.cfg.ACCUM_STEPS
            n_batches  += 1

        return {"loss": total_loss / max(n_batches, 1)}

    # ------------------------------------------------------------------
    @torch.no_grad()
    def _validate(self) -> Dict[str, float]:
        """Evaluate EMA model on the validation set."""
        self.ema.ema_model.eval()
        all_logits, all_labels = [], []

        for images, labels in self.val_loader:
            images = images.to(DEVICE, non_blocking=True)
            if self.cfg.CHANNELS_LAST and DEVICE.type == "cuda":
                images = images.to(memory_format=torch.channels_last)
            with autocast(enabled=self.cfg.AMP):
                logits = self.ema.ema_model(images)
            all_logits.append(logits.cpu().float())
            all_labels.append(labels.cpu().float())

        all_logits = torch.cat(all_logits, dim=0)
        all_labels = torch.cat(all_labels, dim=0)
        probs      = torch.sigmoid(all_logits).numpy()
        labels_np  = all_labels.numpy()
        return self.evaluator.compute(labels_np, probs)

    # ------------------------------------------------------------------
    def _save_checkpoint(self, epoch: int, metrics: Dict,
                          is_best: bool) -> None:
        state = {
            "epoch"     : epoch,
            "model"     : self.model.state_dict(),
            "ema"       : self.ema.state_dict(),
            "optimiser" : self.optimiser.state_dict(),
            "scaler"    : self.scaler.state_dict(),
            "metrics"   : metrics,
            "cfg"       : vars(self.cfg),
        }
        torch.save(state, self.cfg.CHECKPOINT_DIR / f"epoch_{epoch:03d}.pth")
        if is_best:
            torch.save(state, self.cfg.CHECKPOINT_DIR / "best_model.pth")
            print(f"   Best model saved  (AUC={metrics['auc_macro']:.4f})")

    # ------------------------------------------------------------------
    def _log(self, epoch: int, train_m: Dict, val_m: Dict) -> None:
        lr = self.optimiser.param_groups[-1]["lr"]
        self.history["epoch"].append(epoch)
        self.history["train_loss"].append(train_m["loss"])
        self.history["val_auc"].append(val_m["auc_macro"])
        self.history["lr"].append(lr)

        print(
            f"Epoch [{epoch:3d}/{self.cfg.EPOCHS}] "
            f"Loss: {train_m['loss']:.4f}  "
            f"Val AUC: {val_m['auc_macro']:.4f}  "
            f"AP: {val_m['map']:.4f}  "
            f"LR: {lr:.2e}"
        )
        if self.cfg.WANDB and WANDB_AVAILABLE:
            wandb.log({"epoch": epoch, **train_m,
                       **{f"val_{k}": v for k, v in val_m.items()},
                       "lr": lr})

    # ------------------------------------------------------------------
    def fit(self) -> Dict:
        """Main entry-point: run the full training loop, return history."""
        print(f"\n{'='*60}")
        print(f"  ClinicAI v2.0  |  {self.cfg.BACKBONE}  |  {self.cfg.LOSS.upper()}")
        print(f"  Epochs  : {self.cfg.EPOCHS}  |  "
              f"Batch : {self.cfg.BATCH_SIZE}x{self.cfg.ACCUM_STEPS}")
        print(f"  Device  : {DEVICE}")
        print(f"{'='*60}\n")

        self.start_time = time.time()

        for epoch in range(1, self.cfg.EPOCHS + 1):
            train_m = self._train_one_epoch(epoch)
            val_m   = self._validate()

            if isinstance(self.scheduler, CosineWarmupScheduler):
                self.scheduler.step()

            is_best = val_m["auc_macro"] > self.best_auc
            if is_best:
                self.best_auc   = val_m["auc_macro"]
                self.best_epoch = epoch

            self._save_checkpoint(epoch, val_m, is_best)
            self._log(epoch, train_m, val_m)

            if self.early_stop(val_m["auc_macro"]):
                print(f"\nEarly stopping at epoch {epoch} "
                      f"(best AUC={self.best_auc:.4f} @ epoch {self.best_epoch})")
                break

        elapsed = time.time() - self.start_time
        print(f"\nTraining complete in {elapsed/60:.1f} min")
        if self.cfg.WANDB and WANDB_AVAILABLE:
            wandb.finish()
        return dict(self.history)


# ===========================================================================
# SECTION 12 — Metrics
# ===========================================================================

class Evaluator:
    """
    Computes a comprehensive set of classification metrics for multi-label
    chest X-ray classification.

    Metrics produced
    ----------------
    * ROC-AUC macro   — primary ranking metric (averaged over classes)
    * ROC-AUC micro   — all labels treated as one binary problem
    * mAP             — mean Average Precision
    * Precision, Recall, F1 (macro)
    * Per-class ROC-AUC
    """

    def __init__(self, cfg: Config):
        self.cfg = cfg

    # ------------------------------------------------------------------
    def compute(self, y_true: np.ndarray, y_prob: np.ndarray,
                thresholds: Optional[np.ndarray] = None) -> Dict:
        """
        y_true     : [N, 14]  ground-truth binary labels
        y_prob     : [N, 14]  predicted probabilities in [0, 1]
        thresholds : [14]     per-class thresholds (default 0.5)
        """
        if thresholds is None:
            thresholds = np.full(self.cfg.NUM_CLASSES, 0.5)
        y_pred = (y_prob >= thresholds).astype(int)

        metrics = {}

        # ── ROC-AUC ─────────────────────────────────────────────────────
        try:
            metrics["auc_macro"] = roc_auc_score(y_true, y_prob, average="macro")
        except ValueError:
            metrics["auc_macro"] = 0.0

        try:
            metrics["auc_micro"] = roc_auc_score(
                y_true.ravel(), y_prob.ravel(), average=None
            )
        except ValueError:
            metrics["auc_micro"] = 0.0

        # Per-class AUC (skip classes with no positive samples)
        per_class_auc = {}
        for i, cls in enumerate(self.cfg.CLASSES):
            n_pos = y_true[:, i].sum()
            if 0 < n_pos < len(y_true):
                try:
                    per_class_auc[cls] = roc_auc_score(y_true[:, i], y_prob[:, i])
                except ValueError:
                    per_class_auc[cls] = 0.0
            else:
                per_class_auc[cls] = 0.0
        metrics["per_class_auc"] = per_class_auc

        # ── Average Precision ────────────────────────────────────────────
        try:
            metrics["map"] = average_precision_score(y_true, y_prob, average="macro")
        except ValueError:
            metrics["map"] = 0.0

        # ── Precision / Recall / F1 ──────────────────────────────────────
        metrics["precision"] = precision_score(y_true, y_pred, average="macro",
                                               zero_division=0)
        metrics["recall"]    = recall_score(y_true, y_pred, average="macro",
                                            zero_division=0)
        metrics["f1"]        = f1_score(y_true, y_pred, average="macro",
                                        zero_division=0)
        return metrics

    # ------------------------------------------------------------------
    def plot_per_class_auc(self, per_class_auc: Dict[str, float],
                           save_path: Optional[Path] = None) -> None:
        classes = list(per_class_auc.keys())
        aucs    = list(per_class_auc.values())
        idx     = np.argsort(aucs)[::-1]

        fig, ax = plt.subplots(figsize=(12, 5))
        colors  = plt.cm.RdYlGn(np.array(aucs)[idx] - 0.5)
        bars    = ax.bar(np.array(classes)[idx], np.array(aucs)[idx], color=colors)
        ax.axhline(np.mean(aucs), color="navy", linestyle="--", lw=1.5,
                   label=f"Macro AUC = {np.mean(aucs):.4f}")
        ax.set_ylim([0.5, 1.0])
        ax.set_ylabel("ROC-AUC")
        ax.set_title("Per-class ROC-AUC", fontweight="bold")
        ax.set_xticklabels(np.array(classes)[idx], rotation=45, ha="right")
        for bar, val in zip(bars, np.array(aucs)[idx]):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.003,
                    f"{val:.3f}", ha="center", va="bottom", fontsize=8)
        ax.legend()
        plt.tight_layout()
        path = save_path or CFG.OUTPUT_DIR / "per_class_auc.png"
        plt.savefig(path, dpi=150); plt.close()
        print(f"Saved: {path.name}")

    # ------------------------------------------------------------------
    def plot_roc_curves(self, y_true: np.ndarray, y_prob: np.ndarray,
                        save_path: Optional[Path] = None) -> None:
        fig, axes = plt.subplots(2, 7, figsize=(26, 8))
        axes      = axes.flatten()
        for i, cls in enumerate(self.cfg.CLASSES):
            if y_true[:, i].sum() == 0:
                axes[i].axis("off")
                continue
            fpr, tpr, _ = roc_curve(y_true[:, i], y_prob[:, i])
            auc_val     = roc_auc_score(y_true[:, i], y_prob[:, i])
            axes[i].plot(fpr, tpr, color="#E74C3C", lw=2,
                         label=f"AUC={auc_val:.3f}")
            axes[i].plot([0, 1], [0, 1], "k--", lw=1)
            axes[i].set_title(cls, fontsize=9, fontweight="bold")
            axes[i].set_xlabel("FPR")
            axes[i].set_ylabel("TPR")
            axes[i].legend(fontsize=8)
            axes[i].set_xlim([0, 1])
            axes[i].set_ylim([0, 1])
        plt.suptitle("Per-class ROC Curves", fontsize=14, fontweight="bold")
        plt.tight_layout()
        path = save_path or CFG.OUTPUT_DIR / "roc_curves.png"
        plt.savefig(path, dpi=150); plt.close()
        print(f"Saved: {path.name}")

    # ------------------------------------------------------------------
    def plot_confusion_matrices(self, y_true: np.ndarray, y_pred: np.ndarray,
                                 save_path: Optional[Path] = None) -> None:
        fig, axes = plt.subplots(2, 7, figsize=(26, 8))
        axes      = axes.flatten()
        for i, cls in enumerate(self.cfg.CLASSES):
            cm = confusion_matrix(y_true[:, i], y_pred[:, i])
            if cm.shape != (2, 2):
                axes[i].axis("off")
                continue
            sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", ax=axes[i],
                        cbar=False, xticklabels=["Neg", "Pos"],
                        yticklabels=["Neg", "Pos"])
            axes[i].set_title(cls, fontsize=8, fontweight="bold")
        plt.suptitle("Confusion Matrices (per class)", fontsize=14, fontweight="bold")
        plt.tight_layout()
        path = save_path or CFG.OUTPUT_DIR / "confusion_matrices.png"
        plt.savefig(path, dpi=150); plt.close()
        print(f"Saved: {path.name}")


# ===========================================================================
# SECTION 13 — Threshold Optimisation
# ===========================================================================

class ThresholdOptimiser:
    """
    Finds the optimal decision threshold for each class independently
    using Youden's J statistic on the validation set:

        J = Sensitivity + Specificity - 1 = TPR - FPR

    This maximises the geometric performance of both TPR and TNR,
    which is appropriate for imbalanced multi-label medical data.
    Using a fixed 0.5 threshold is suboptimal because:
    1. Rare diseases are systematically under-predicted (low recall).
    2. Different classes have different optimal operating points.
    """

    def __init__(self, cfg: Config):
        self.cfg        = cfg
        self.thresholds = np.full(cfg.NUM_CLASSES, 0.5)

    def fit(self, y_true: np.ndarray, y_prob: np.ndarray) -> np.ndarray:
        """Compute optimal per-class thresholds from validation predictions."""
        for i, cls in enumerate(self.cfg.CLASSES):
            n_pos = y_true[:, i].sum()
            if n_pos == 0 or n_pos == len(y_true):
                self.thresholds[i] = 0.5
                continue
            fpr, tpr, candidates = roc_curve(y_true[:, i], y_prob[:, i])
            j_stat               = tpr - fpr
            best_j               = np.argmax(j_stat)
            self.thresholds[i]   = candidates[best_j]

        print("\nOptimal Thresholds (Youden's J):")
        for cls, t in zip(self.cfg.CLASSES, self.thresholds):
            print(f"  {cls:<22} : {t:.4f}")
        return self.thresholds

    def save(self, path: Optional[Path] = None) -> None:
        path = path or CFG.OUTPUT_DIR / "thresholds.json"
        with open(path, "w") as f:
            json.dump(dict(zip(self.cfg.CLASSES, self.thresholds.tolist())), f, indent=2)
        print(f"Thresholds saved to {path}")

    def load(self, path: Path) -> np.ndarray:
        with open(path) as f:
            d = json.load(f)
        self.thresholds = np.array([d[cls] for cls in self.cfg.CLASSES])
        return self.thresholds


# ===========================================================================
# SECTION 14 — Test-Time Augmentation (TTA)
# ===========================================================================

class TTAInference:
    """
    Test-Time Augmentation averages predictions from multiple augmented
    views of the same image to reduce prediction variance.

    Augmentation views
    ------------------
    For each scale in CFG.TTA_SCALES:
      1. Original image at that scale
      2. Horizontally flipped image at that scale
    Total forward passes: 2 x len(TTA_SCALES) per image.

    Averaging predictions typically boosts macro AUC by 0.3-0.8 pp
    without any additional training.
    """

    def __init__(self, model: nn.Module, cfg: Config):
        self.model = model.eval()
        self.cfg   = cfg

    @torch.no_grad()
    def predict(self, image_path: Union[str, Path]) -> np.ndarray:
        """Predict probabilities for a single image with multi-scale TTA."""
        img = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            raise FileNotFoundError(f"Cannot read: {image_path}")
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)

        all_probs = []
        for scale in self.cfg.TTA_SCALES:
            tfm = build_tta_transforms(scale, self.cfg)

            # Original
            t_img  = tfm(image=img)["image"].unsqueeze(0).to(DEVICE)
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(t_img)
            all_probs.append(torch.sigmoid(logits).cpu().numpy())

            # Horizontal flip
            img_f  = cv2.flip(img, 1)
            t_imgf = tfm(image=img_f)["image"].unsqueeze(0).to(DEVICE)
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(t_imgf)
            all_probs.append(torch.sigmoid(logits).cpu().numpy())

        return np.mean(all_probs, axis=0).squeeze(0)    # [NUM_CLASSES]

    @torch.no_grad()
    def predict_loader(self, loader: DataLoader) -> np.ndarray:
        """Batch inference (standard resolution, no multi-scale for speed)."""
        all_probs = []
        self.model.eval()
        for images, _ in loader:
            images = images.to(DEVICE, non_blocking=True)
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(images)
            all_probs.append(torch.sigmoid(logits).cpu().numpy())
        return np.concatenate(all_probs, axis=0)


# ===========================================================================
# SECTION 15 — Explainability (GradCAM)
# ===========================================================================

class GradCAMVisualiser:
    """
    Generates GradCAM heatmaps overlaid on the original chest X-ray.

    GradCAM (Selvaraju et al., 2017) highlights the spatial regions that
    most influenced the model's prediction for a given disease class.
    In chest X-ray analysis, GradCAM typically highlights the lung regions
    associated with pathology — critical for clinical trust and validation.

    Requirements: pip install grad-cam
    """

    def __init__(self, model: nn.Module, cfg: Config):
        self.model = model
        self.cfg   = cfg
        self._cam  = None

        if not GRADCAM_AVAILABLE:
            print("GradCAM library not available.")
            return

        target_layer = model.get_gradcam_layer()
        self._cam    = GradCAM(model=model, target_layers=[target_layer])

    def visualise(self, image_path: Union[str, Path],
                  class_indices: Optional[List[int]] = None,
                  save_dir: Optional[Path] = None) -> None:
        """Generate GradCAM overlays for each specified class."""
        if not GRADCAM_AVAILABLE or self._cam is None:
            return

        save_dir = save_dir or self.cfg.GRAD_CAM_DIR
        save_dir.mkdir(parents=True, exist_ok=True)

        if class_indices is None:
            class_indices = list(range(self.cfg.NUM_CLASSES))

        img_bgr  = cv2.imread(str(image_path))
        if img_bgr is None:
            print(f"Cannot read: {image_path}")
            return
        img_rgb  = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        img_resz = cv2.resize(img_rgb, (self.cfg.IMG_SIZE, self.cfg.IMG_SIZE))
        img_norm = img_resz.astype(np.float32) / 255.0

        tfm    = build_transforms("val", self.cfg)
        tensor = tfm(image=cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB))["image"]
        tensor = tensor.unsqueeze(0).to(DEVICE)

        self.model.eval()
        with torch.no_grad():
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(tensor)
        probs = torch.sigmoid(logits).cpu().numpy().squeeze()

        fig_cols = min(4, len(class_indices))
        fig_rows = math.ceil(len(class_indices) / fig_cols)
        fig, axes = plt.subplots(fig_rows, fig_cols,
                                 figsize=(5 * fig_cols, 5 * fig_rows))
        axes = np.array(axes).flatten()

        for plot_idx, cls_idx in enumerate(class_indices):
            targets = [ClassifierOutputTarget(cls_idx)]
            cam_map = self._cam(input_tensor=tensor, targets=targets)[0]
            overlay = show_cam_on_image(img_norm, cam_map, use_rgb=True)
            axes[plot_idx].imshow(overlay)
            axes[plot_idx].set_title(
                f"{self.cfg.CLASSES[cls_idx]}\n(p={probs[cls_idx]:.3f})",
                fontsize=9, fontweight="bold"
            )
            axes[plot_idx].axis("off")

        for ax in axes[len(class_indices):]:
            ax.axis("off")

        img_name  = Path(image_path).stem
        plt.suptitle(f"GradCAM - {img_name}", fontsize=13, fontweight="bold")
        plt.tight_layout()
        save_path = save_dir / f"gradcam_{img_name}.png"
        plt.savefig(save_path, dpi=150, bbox_inches="tight")
        plt.close()
        print(f"GradCAM saved: {save_path}")


# ===========================================================================
# SECTION 16 — Inference Pipeline
# ===========================================================================

class InferencePipeline:
    """
    Production-grade inference module supporting:
      - Single-image prediction with optional TTA
      - Batch prediction from a DataFrame
      - Kaggle submission CSV generation
    """

    def __init__(self, model: nn.Module, cfg: Config,
                 thresholds: Optional[np.ndarray] = None):
        self.model      = model.eval()
        self.cfg        = cfg
        self.thresholds = (thresholds if thresholds is not None
                           else np.full(cfg.NUM_CLASSES, 0.5))
        self.tta        = TTAInference(model, cfg)
        self.transform  = build_transforms("val", cfg)

    def predict_single(self, image_path: Union[str, Path],
                       use_tta: bool = True) -> Dict:
        """Single-image prediction with optional TTA."""
        if use_tta:
            probs = self.tta.predict(image_path)
        else:
            img    = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
            img    = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
            tensor = self.transform(image=img)["image"].unsqueeze(0).to(DEVICE)
            with torch.no_grad():
                with autocast(enabled=self.cfg.AMP):
                    logits = self.model(tensor)
            probs = torch.sigmoid(logits).cpu().numpy().squeeze()

        predictions = (probs >= self.thresholds).astype(int)
        detected    = [cls for cls, pred in zip(self.cfg.CLASSES, predictions)
                       if pred]
        return {
            "probabilities"  : dict(zip(self.cfg.CLASSES, probs.tolist())),
            "predictions"    : dict(zip(self.cfg.CLASSES, predictions.tolist())),
            "detected_labels": detected if detected else ["No Finding"],
        }

    @torch.no_grad()
    def predict_batch(self, df: pd.DataFrame, image_dir: Path) -> np.ndarray:
        """Batch inference; returns [N, NUM_CLASSES] probability matrix."""
        dataset = ChestXray14Dataset(df, image_dir, self.transform, self.cfg)
        loader  = DataLoader(dataset, batch_size=self.cfg.BATCH_SIZE,
                             shuffle=False, num_workers=self.cfg.NUM_WORKERS,
                             pin_memory=self.cfg.PIN_MEMORY)
        probs   = []
        self.model.eval()
        for images, _ in loader:
            images = images.to(DEVICE, non_blocking=True)
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(images)
            probs.append(torch.sigmoid(logits).cpu().numpy())
        return np.concatenate(probs, axis=0)

    def generate_submission(self, df: pd.DataFrame, image_dir: Path,
                             save_path: Optional[Path] = None) -> pd.DataFrame:
        """Generate a Kaggle-style submission CSV."""
        print(f"Generating submission for {len(df):,} images...")
        probs   = self.predict_batch(df, image_dir)
        preds   = (probs >= self.thresholds).astype(int)
        result  = pd.DataFrame(preds, columns=self.cfg.CLASSES)
        result.insert(0, "Image Index", df["Image Index"].values)
        save_path = save_path or self.cfg.OUTPUT_DIR / "submission.csv"
        result.to_csv(save_path, index=False)
        print(f"Submission saved to {save_path}  ({len(result):,} rows)")
        return result


# ===========================================================================
# SECTION 17 — Error Analysis
# ===========================================================================

class ErrorAnalyser:
    """
    Analyses model failures to gain actionable diagnostic insights.

    Categories
    ----------
    * False Positives : model over-diagnosed a disease that is absent
    * False Negatives : model missed a disease that is present
    * Hard Examples   : highest binary-cross-entropy loss (hardest for model)
    * Most Uncertain  : predicted probability closest to the threshold
    """

    def __init__(self, df: pd.DataFrame, cfg: Config):
        self.df  = df
        self.cfg = cfg

    def analyse(self, y_true: np.ndarray, y_prob: np.ndarray,
                thresholds: np.ndarray, image_dir: Path, n: int = 4) -> None:
        """Run error analysis and save visualisations for each class."""
        y_pred = (y_prob >= thresholds).astype(int)

        for cls_idx, cls in enumerate(self.cfg.CLASSES):
            gt   = y_true[:, cls_idx]
            prob = y_prob[:, cls_idx]
            pred = y_pred[:, cls_idx]

            fp_idx    = np.where((pred == 1) & (gt == 0))[0]
            fn_idx    = np.where((pred == 0) & (gt == 1))[0]
            bce_loss  = -(gt * np.log(prob + 1e-8) + (1-gt) * np.log(1-prob+1e-8))
            hard_idx  = np.argsort(bce_loss)[::-1][:n]
            margin    = np.abs(prob - thresholds[cls_idx])
            uncert_idx = np.argsort(margin)[:n]

            print(f"\n{'-'*50}")
            print(f"  {cls:<22}  |  FP={len(fp_idx)}  FN={len(fn_idx)}")
            print(f"{'-'*50}")

            for label, indices in [
                ("False_Positives", fp_idx[:n]),
                ("False_Negatives", fn_idx[:n]),
                ("Hard_Examples",   hard_idx),
                ("Most_Uncertain",  uncert_idx),
            ]:
                if len(indices) == 0:
                    continue
                self._show_examples(label, indices, cls, prob, gt, image_dir)

    def _show_examples(self, label: str, indices: np.ndarray, cls: str,
                        prob: np.ndarray, gt: np.ndarray,
                        image_dir: Path) -> None:
        fig, axes = plt.subplots(1, len(indices),
                                 figsize=(4 * len(indices), 4))
        if len(indices) == 1:
            axes = [axes]
        for ax, idx in zip(axes, indices):
            img_name = self.df.iloc[idx]["Image Index"]
            img_path = image_dir / img_name
            if img_path.exists():
                img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
                ax.imshow(img, cmap="gray")
            ax.set_title(f"GT={int(gt[idx])}  P={prob[idx]:.3f}", fontsize=9)
            ax.axis("off")
        plt.suptitle(f"{label.replace('_', ' ')} — {cls}", fontweight="bold")
        plt.tight_layout()
        fname = f"error_{label.lower()}_{cls.lower()}.png"
        plt.savefig(CFG.OUTPUT_DIR / fname, dpi=120)
        plt.close()


# ===========================================================================
# SECTION 19 — Performance Optimisation
# ===========================================================================

def apply_performance_opts(model: nn.Module, cfg: Config) -> nn.Module:
    """
    Apply hardware-level optimisations for Kaggle P100/T4/L4 GPUs.

    Channels-last memory format
    ----------------------------
    NVIDIA convolution kernels run faster with NHWC layout (channels last)
    vs NCHW (channels first). torch.channels_last enables this transparently.

    torch.compile
    -------------
    PyTorch 2.0+ traces the model graph and generates optimised Triton/CUDA
    kernels with operator fusion. 10-40% speedup at the cost of ~2min warmup.

    cudnn.benchmark
    ---------------
    Automatically selects the fastest cuDNN conv algorithm for each input
    shape at the start of training. Recommended for fixed image sizes.
    """
    if cfg.CHANNELS_LAST and DEVICE.type == "cuda":
        model = model.to(memory_format=torch.channels_last)
        print("channels_last memory format enabled")

    if cfg.COMPILE and hasattr(torch, "compile") and DEVICE.type == "cuda":
        model = torch.compile(model, mode="reduce-overhead")
        print("torch.compile() applied")

    torch.backends.cudnn.benchmark = cfg.CUDNN_BENCHMARK
    if cfg.CUDNN_BENCHMARK:
        print("cudnn.benchmark = True")

    return model


# ===========================================================================
# SECTION 20 — Final Report
# ===========================================================================

class Reporter:
    """Generates the comprehensive final performance report after training."""

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def print_report(self, history: Dict, best_metrics: Dict,
                     thresholds: np.ndarray, model: nn.Module,
                     training_time_sec: float) -> None:
        print("\n" + "=" * 70)
        print("  CLINICAI v2.0 — FINAL REPORT")
        print("=" * 70)

        best_epoch = (history.get("epoch", [0])
                      [np.argmax(history.get("val_auc", [0]))])
        print(f"\n  Best Epoch        : {best_epoch}")
        print(f"  Training Time     : {training_time_sec/60:.1f} minutes")

        if DEVICE.type == "cuda":
            mem = torch.cuda.max_memory_allocated() / 1e9
            print(f"  Peak GPU Memory   : {mem:.2f} GB")
            torch.cuda.reset_peak_memory_stats()

        total_p     = model.param_count() / 1e6
        trainable_p = model.trainable_param_count() / 1e6
        print(f"  Total Params      : {total_p:.1f} M")
        print(f"  Trainable Params  : {trainable_p:.1f} M")

        print(f"\n  Macro ROC-AUC     : {best_metrics.get('auc_macro', 0):.4f}")
        print(f"  Micro ROC-AUC     : {best_metrics.get('auc_micro', 0):.4f}")
        print(f"  Mean Avg Prec     : {best_metrics.get('map', 0):.4f}")
        print(f"  Precision (macro) : {best_metrics.get('precision', 0):.4f}")
        print(f"  Recall    (macro) : {best_metrics.get('recall', 0):.4f}")
        print(f"  F1        (macro) : {best_metrics.get('f1', 0):.4f}")

        print("\n  Per-class ROC-AUC & Optimal Threshold:")
        print(f"  {'Class':<24} {'AUC':>7}   {'Threshold':>9}")
        print("  " + "-" * 46)
        per_cls = best_metrics.get("per_class_auc", {})
        for i, cls in enumerate(self.cfg.CLASSES):
            auc_val = per_cls.get(cls, 0.0)
            t_val   = thresholds[i]
            flag    = "STAR" if auc_val >= 0.85 else ("LOW" if auc_val < 0.75 else "   ")
            print(f"  {cls:<24} {auc_val:>7.4f}   {t_val:>9.4f}  {flag}")

        print(f"\n  Backbone          : {self.cfg.BACKBONE}")
        print(f"  Loss Function     : {self.cfg.LOSS.upper()}")
        print(f"  Image Size        : {self.cfg.IMG_SIZE}x{self.cfg.IMG_SIZE}")
        print("=" * 70)

    def plot_training_curves(self, history: Dict) -> None:
        fig, axes = plt.subplots(1, 2, figsize=(14, 4))
        axes[0].plot(history["epoch"], history["train_loss"],
                     label="Train Loss", color="#E74C3C")
        axes[0].set_title("Training Loss")
        axes[0].set_xlabel("Epoch")
        axes[0].set_ylabel("Loss")
        axes[0].legend()

        axes[1].plot(history["epoch"], history["val_auc"],
                     label="Val AUC", color="#2ECC71")
        axes[1].axhline(0.84, color="#E74C3C", linestyle="--",
                        lw=1.5, label="Target (0.84)")
        axes[1].set_title("Validation AUC")
        axes[1].set_xlabel("Epoch")
        axes[1].set_ylabel("ROC-AUC")
        axes[1].legend()

        plt.suptitle("Training Curves — ClinicAI v2.0", fontweight="bold")
        plt.tight_layout()
        plt.savefig(CFG.OUTPUT_DIR / "training_curves.png", dpi=150)
        plt.close()
        print("Saved: training_curves.png")


# ===========================================================================
# MAIN — Orchestrate the complete pipeline
# ===========================================================================

def load_metadata(cfg: Config) -> pd.DataFrame:
    """Load and lightly preprocess the NIH ChestX-ray14 metadata CSV."""
    df = pd.read_csv(cfg.META_CSV)
    # Extract integer Patient ID from filename (e.g. "00000001_000.png" -> 1)
    df["Patient ID"] = df["Image Index"].apply(lambda x: int(x.split("_")[0]))
    print(f"Loaded {len(df):,} rows from {cfg.META_CSV.name}")
    return df


def main():
    """End-to-end pipeline orchestration."""
    print("\n" + "=" * 60)
    print("  ClinicAI v2.0 — NIH ChestX-ray14 Pipeline")
    print("=" * 60 + "\n")

    # ── 1. Load metadata ─────────────────────────────────────────────
    df_raw = load_metadata(CFG)

    # ── 2. EDA  (Section 3) ──────────────────────────────────────────
    analyser = DataAnalyser(df_raw, CFG)
    df       = analyser.run()   # returns df with binary label columns

    # ── 3. Patient-Wise Split  (Section 4) ───────────────────────────
    splitter         = DataSplitter(df, CFG, val_ratio=0.15)
    train_df, val_df = splitter.split()

    # ── 4. Augmentation pipelines  (Section 5) ───────────────────────
    train_tfm = build_transforms("train", CFG)
    val_tfm   = build_transforms("val",   CFG)

    # ── 5. Datasets & DataLoaders  (Sections 5-6) ────────────────────
    train_ds   = ChestXray14Dataset(train_df, CFG.IMAGE_DIR, train_tfm, CFG)
    val_ds     = ChestXray14Dataset(val_df,   CFG.IMAGE_DIR, val_tfm,   CFG)
    pos_weight = train_ds.get_pos_weight()

    train_loader = build_dataloader(train_ds, CFG.BATCH_SIZE, shuffle=True,  cfg=CFG)
    val_loader   = build_dataloader(val_ds,   CFG.BATCH_SIZE, shuffle=False, cfg=CFG)
    print(f"Train batches: {len(train_loader)}  |  Val batches: {len(val_loader)}")

    # ── 6. Model  (Section 7) ────────────────────────────────────────
    model = ChestXrayModel(CFG).to(DEVICE)
    model = apply_performance_opts(model, CFG)
    print(f"Total params     : {model.param_count()/1e6:.1f} M")
    print(f"Trainable params : {model.trainable_param_count()/1e6:.1f} M")

    # ── 7. Loss / Optimiser / Scheduler  (Sections 8-10) ─────────────
    criterion = build_loss(CFG, pos_weight)
    optimiser = build_optimiser(model, CFG)
    scheduler = build_scheduler(optimiser, CFG)
    evaluator = Evaluator(CFG)

    # ── 8. Training  (Section 11) ────────────────────────────────────
    trainer = Trainer(
        model=model, train_loader=train_loader, val_loader=val_loader,
        criterion=criterion, optimiser=optimiser, scheduler=scheduler,
        cfg=CFG, evaluator=evaluator,
    )
    t0      = time.time()
    history = trainer.fit()
    t_train = time.time() - t0

    # ── 9. Load best EMA checkpoint ───────────────────────────────────
    best_ckpt = CFG.CHECKPOINT_DIR / "best_model.pth"
    if best_ckpt.exists():
        ckpt = torch.load(best_ckpt, map_location=DEVICE)
        model.load_state_dict(ckpt["ema"])
        print(f"Loaded best EMA checkpoint (epoch {ckpt['epoch']})")
    model.eval()

    # ── 10. Full validation metrics  (Section 12) ────────────────────
    print("\nComputing full validation metrics...")
    val_probs, val_labels = [], []
    with torch.no_grad():
        for images, labels in val_loader:
            images = images.to(DEVICE, non_blocking=True)
            with autocast(enabled=CFG.AMP):
                logits = model(images)
            val_probs.append(torch.sigmoid(logits).cpu().numpy())
            val_labels.append(labels.numpy())
    val_probs  = np.concatenate(val_probs,  axis=0)
    val_labels = np.concatenate(val_labels, axis=0)

    best_metrics = evaluator.compute(val_labels, val_probs)
    evaluator.plot_per_class_auc(best_metrics["per_class_auc"])
    evaluator.plot_roc_curves(val_labels, val_probs)
    y_pred_05 = (val_probs >= 0.5).astype(int)
    evaluator.plot_confusion_matrices(val_labels, y_pred_05)

    # ── 11. Threshold Optimisation  (Section 13) ─────────────────────
    thresh_opt = ThresholdOptimiser(CFG)
    thresholds = thresh_opt.fit(val_labels, val_probs)
    thresh_opt.save()

    best_metrics_opt = evaluator.compute(val_labels, val_probs, thresholds)
    print(f"\n  AUC  (fixed  0.5) : {best_metrics['auc_macro']:.4f}")
    print(f"  AUC  (opt thresh) : {best_metrics_opt['auc_macro']:.4f}")
    print(f"  F1   (fixed  0.5) : {best_metrics['f1']:.4f}")
    print(f"  F1   (opt thresh) : {best_metrics_opt['f1']:.4f}")

    # ── 12. Explainability  (Section 15) ─────────────────────────────
    if GRADCAM_AVAILABLE:
        cam_vis = GradCAMVisualiser(model, CFG)
        sample  = val_df.iloc[0]["Image Index"]
        cam_vis.visualise(CFG.IMAGE_DIR / sample,
                          class_indices=list(range(CFG.NUM_CLASSES)))

    # ── 13. Error Analysis  (Section 17) ─────────────────────────────
    err_analyser = ErrorAnalyser(val_df, CFG)
    err_analyser.analyse(val_labels, val_probs, thresholds, CFG.IMAGE_DIR, n=4)

    # ── 14. Inference Pipeline demo  (Section 16) ────────────────────
    pipeline   = InferencePipeline(model, CFG, thresholds)
    sample_img = CFG.IMAGE_DIR / val_df.iloc[0]["Image Index"]
    if sample_img.exists():
        result = pipeline.predict_single(sample_img, use_tta=True)
        print("\nSample TTA Prediction:")
        for cls, prob in result["probabilities"].items():
            flag = "[X]" if result["predictions"][cls] else "   "
            print(f"  {flag} {cls:<22} : {prob:.4f}")
        print(f"  Detected: {result['detected_labels']}")

    # ── 15. Final Report  (Section 20) ───────────────────────────────
    reporter = Reporter(CFG)
    reporter.print_report(history, best_metrics_opt, thresholds, model, t_train)
    reporter.plot_training_curves(history)

    # ── Cleanup ───────────────────────────────────────────────────────
    del model, trainer
    gc.collect()
    if DEVICE.type == "cuda":
        torch.cuda.empty_cache()

    print("\nClinicAI v2.0 pipeline complete!")
    return best_metrics_opt


# ===========================================================================
# Entry point
# ===========================================================================
if __name__ == "__main__":
    main()
