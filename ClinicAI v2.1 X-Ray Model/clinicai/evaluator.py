from typing import Dict, Optional
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.metrics import (
    roc_auc_score, average_precision_score,
    precision_score, recall_score, f1_score,
    confusion_matrix, roc_curve,
)
from .config import Config, CFG

class Evaluator:
    """
    Computes validation and test metrics, and exports visual analysis plots
    (ROC curves, confusion matrices, class-specific bar graphs).
    """
    def __init__(self, cfg: Config):
        self.cfg = cfg

    def compute(self, y_true: np.ndarray, y_prob: np.ndarray,
                thresholds: Optional[np.ndarray] = None) -> Dict:
        """
        Calculates Macro/Micro ROC-AUC, mAP, and threshold-dependent Precision, Recall, and F1.
        """
        if thresholds is None:
            thresholds = np.full(self.cfg.NUM_CLASSES, 0.5)
        y_pred = (y_prob >= thresholds).astype(int)

        metrics = {}

        # Compute ROC-AUC Scores
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

        # Compute Per-Class ROC-AUC
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

        # Compute average precision (mAP)
        try:
            metrics["map"] = average_precision_score(y_true, y_prob, average="macro")
        except ValueError:
            metrics["map"] = 0.0

        # Compute Precision, Recall, F1
        metrics["precision"] = precision_score(y_true, y_pred, average="macro", zero_division=0)
        metrics["recall"]    = recall_score(y_true, y_pred, average="macro", zero_division=0)
        metrics["f1"]        = f1_score(y_true, y_pred, average="macro", zero_division=0)
        return metrics

    def plot_per_class_auc(self, per_class_auc: Dict[str, float],
                           save_path: Optional[Path] = None) -> None:
        """Saves a bar chart of per-class AUC values."""
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
        plt.savefig(path, dpi=150)
        plt.close()
        print(f"Saved: {path.name}")

    def plot_roc_curves(self, y_true: np.ndarray, y_prob: np.ndarray,
                        save_path: Optional[Path] = None) -> None:
        """Saves ROC curves for all pathology classes in a grid."""
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
        plt.savefig(path, dpi=150)
        plt.close()
        print(f"Saved: {path.name}")

    def plot_confusion_matrices(self, y_true: np.ndarray, y_pred: np.ndarray,
                                 save_path: Optional[Path] = None) -> None:
        """Saves individual confusion matrices in a grid."""
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
        plt.savefig(path, dpi=150)
        plt.close()
        print(f"Saved: {path.name}")
