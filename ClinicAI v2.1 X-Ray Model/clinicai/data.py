import random
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union
import numpy as np
import pandas as pd
import cv2
import matplotlib.pyplot as plt
import seaborn as sns
from PIL import Image

import torch
from torch.utils.data import Dataset, DataLoader
import albumentations as A
from albumentations.pytorch import ToTensorV2
from sklearn.model_selection import train_test_split

from .config import Config

# Try to import iterative stratification package
try:
    from iterstrat.ml_stratifiers import MultilabelStratifiedShuffleSplit
    ITERSTRAT_AVAILABLE = True
except ImportError:
    ITERSTRAT_AVAILABLE = False


# ==========================================================================
# Image Mapping
# ==========================================================================
def build_image_map(root: str = "/kaggle/input") -> Dict[str, Path]:
    """
    Scans the root directory recursively for PNG files to map image filenames
    to their absolute paths. This is essential for NIH ChestX-ray14 dataset
    where images are split across multiple directories.
    """
    image_map = {}
    root_path = Path(root)
    if not root_path.exists():
        print(f"Warning: Image root path '{root}' does not exist. Image map will be empty.")
        return image_map

    for img in root_path.rglob("*.png"):
        image_map[img.name] = img

    print(f"Found {len(image_map)} images in {root}.")
    return image_map


# Module-level variable to hold the image path mapping
IMAGE_MAP = build_image_map()


# ==========================================================================
# Transforms
# ==========================================================================
def build_transforms(mode: str, cfg: Config) -> A.Compose:
    """
    Creates Albumentations augmentation pipelines.
    
    Training:
        Spatial crops, resizing, CLAHE (contrast enhancement), rotate,
        Gaussian noise/blur, coarse dropout, and normalization.
    Validation/Testing:
        Resizing and normalization only.
    """
    mean, std = cfg.MEAN, cfg.STD

    if mode == "train":
        return A.Compose([
            # Spatial Jittering
            A.Resize(cfg.IMG_SIZE + 32, cfg.IMG_SIZE + 32),
            A.RandomResizedCrop(
                size=(cfg.IMG_SIZE, cfg.IMG_SIZE),
                scale=(0.75, 1.0),
                ratio=(0.85, 1.15),
                p=1.0,
            ),
            A.HorizontalFlip(p=0.5),
            A.ShiftScaleRotate(
                shift_limit=0.05,
                scale_limit=0.10,
                rotate_limit=10,
                border_mode=cv2.BORDER_REFLECT_101,
                p=0.5,
            ),
            # Intensity Enhancements
            A.CLAHE(
                clip_limit=2.0,
                tile_grid_size=(8, 8),
                p=0.5,
            ),
            A.RandomBrightnessContrast(
                brightness_limit=0.15,
                contrast_limit=0.15,
                p=0.5,
            ),
            A.GaussNoise(
                std_range=(0.02, 0.08),
                p=0.3,
            ),
            A.GaussianBlur(
                blur_limit=(3, 5),
                p=0.1,
            ),
            # Regularization (Occlusion)
            A.CoarseDropout(
                num_holes_range=(1, 8),
                hole_height_range=(0.02, 0.06),
                hole_width_range=(0.02, 0.06),
                fill=0,
                p=0.2,
            ),
            # Normalization
            A.Normalize(mean=mean, std=std),
            ToTensorV2(),
        ])

    elif mode in ("val", "test"):
        return A.Compose([
            A.Resize(cfg.IMG_SIZE, cfg.IMG_SIZE),
            A.Normalize(mean=mean, std=std),
            ToTensorV2(),
        ])
    else:
        raise ValueError(f"Unknown mode: {mode}")


def build_tta_transforms(scale: int, cfg: Config) -> A.Compose:
    """
    Creates scale-specific validation transform for Test-Time Augmentation (TTA).
    """
    return A.Compose([
        A.Resize(scale, scale),
        A.Normalize(mean=cfg.MEAN, std=cfg.STD),
        ToTensorV2(),
    ])


# ==========================================================================
# Dataset
# ==========================================================================
class ChestXray14Dataset(Dataset):
    """
    PyTorch Dataset wrapper for NIH ChestX-ray14 dataset.
    Reads images, converts grayscale to RGB, applies augmentations,
    and returns image and label tensor pairs.
    """
    def __init__(self, df: pd.DataFrame, image_dir: Union[str, Path], transform: A.Compose, cfg: Config):
        self.df = df.reset_index(drop=True)
        self.transform = transform
        self.cfg = cfg
        self.image_map = IMAGE_MAP
        self.labels = df[cfg.CLASSES].values.astype(np.float32)

    def __len__(self) -> int:
        return len(self.df)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
        row = self.df.iloc[idx]
        filename = row["Image Index"]
        img_path = self.image_map.get(filename)

        if img_path is None:
            # Fallback for missing images
            img = np.zeros((self.cfg.IMG_SIZE, self.cfg.IMG_SIZE), dtype=np.uint8)
        else:
            img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
            if img is None:
                img = np.zeros((self.cfg.IMG_SIZE, self.cfg.IMG_SIZE), dtype=np.uint8)

        # Convert grayscale to 3-channel RGB (pre-trained networks require RGB input)
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)

        # Apply augmentation transforms
        img = self.transform(image=img)["image"]
        label = torch.tensor(self.labels[idx], dtype=torch.float32)

        return img, label

    def get_pos_weight(self) -> torch.Tensor:
        """
        Calculates positive weights for loss balancing based on inverse prevalence.
        """
        pos = self.labels.sum(axis=0)
        neg = len(self.labels) - pos
        weight = np.where(pos > 0, neg / pos, 100.0)
        return torch.tensor(weight, dtype=torch.float32)


# ==========================================================================
# Data splitting
# ==========================================================================
class DataSplitter:
    """
    Performs patient-wise train/validation split to avoid data leakage.
    Ensures images of a single patient do not cross the split boundaries.
    """
    def __init__(self, df: pd.DataFrame, cfg: Config, val_ratio: float = 0.15):
        self.df = df
        self.cfg = cfg
        self.val_ratio = val_ratio

    def split(self) -> Tuple[pd.DataFrame, pd.DataFrame]:
        patient_ids = self.df["Patient ID"].unique()
        print(f"Total patients : {len(patient_ids):,}")

        # Aggregate labels: positive if any patient image has it
        patient_labels = (
            self.df.groupby("Patient ID")[self.cfg.CLASSES]
            .max()
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

        # Assert no patient overlap to verify absence of data leakage
        assert len(set(train_df["Patient ID"]) & set(val_df["Patient ID"])) == 0, \
            "ERROR: Patient leakage detected!"

        print(f"Train images : {len(train_df):,}  ({len(train_patients):,} patients)")
        print(f"Val   images : {len(val_df):,}  ({len(val_patients):,} patients)")
        return train_df, val_df


# ==========================================================================
# DataAnalyser (EDA)
# ==========================================================================
class DataAnalyser:
    """
    Performs Exploratory Data Analysis (EDA) on the NIH ChestX-ray14 dataset.
    Generates class distributions, disease co-occurrence matrices, patient histograms,
    view position breakdown, and representative chest X-ray images.
    """
    def __init__(self, df: pd.DataFrame, cfg: Config):
        self.df = df
        self.cfg = cfg
        sns.set_theme(style="darkgrid", palette="muted")

    def _parse_labels(self) -> pd.DataFrame:
        df = self.df.copy()
        for cls in self.cfg.CLASSES:
            df[cls] = df["Finding Labels"].apply(
                lambda x: 1 if cls in x.split("|") else 0
            )
        return df

    def run(self) -> pd.DataFrame:
        df = self._parse_labels()
        self._plot_class_distribution(df)
        self._plot_cooccurrence(df)
        self._plot_patient_distribution(df)
        self._plot_view_position(df)
        self._plot_sample_images(df)
        self._print_imbalance_stats(df)
        return df

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
        ax.set_title("Disease Co-occurrence Matrix (P(col | row))",
                     fontsize=13, fontweight="bold")
        plt.tight_layout()
        plt.savefig(self.cfg.OUTPUT_DIR / "cooccurrence_matrix.png", dpi=150)
        plt.close()
        print("Saved: cooccurrence_matrix.png")

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

    def _plot_sample_images(self, df: pd.DataFrame) -> None:
        fig, axes = plt.subplots(2, 7, figsize=(22, 7))
        axes = axes.flatten()
        for i, cls in enumerate(self.cfg.CLASSES):
            subset = df[df[cls] == 1]["Image Index"].values
            if len(subset) == 0:
                axes[i].axis("off")
                continue
            img_path = IMAGE_MAP.get(random.choice(subset))
            if img_path and img_path.exists():
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

    def _print_imbalance_stats(self, df: pd.DataFrame) -> None:
        total = len(df)
        pos = df[self.cfg.CLASSES].sum()
        neg = total - pos
        ratio = (neg / pos).rename("neg:pos ratio")
        stats = pd.concat([pos.rename("# Positive"), neg.rename("# Negative"),
                           ratio, (pos / total * 100).rename("Prevalence %")], axis=1)
        stats = stats.sort_values("# Positive", ascending=False)
        print("\nClass Imbalance Statistics")
        print("=" * 65)
        print(stats.to_string())
        print("=" * 65)


# ==========================================================================
# DataLoader builder
# ==========================================================================
def build_dataloader(dataset: ChestXray14Dataset, batch_size: int, shuffle: bool, cfg: Config) -> DataLoader:
    """
    Helper function to instantiate a DataLoader with customized worker parameters.
    """
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=cfg.NUM_WORKERS,
        pin_memory=cfg.PIN_MEMORY,
        persistent_workers=(cfg.PERSISTENT_WORKERS and cfg.NUM_WORKERS > 0),
        prefetch_factor=(cfg.PREFETCH_FACTOR if cfg.NUM_WORKERS > 0 else None),
        drop_last=shuffle,
    )
