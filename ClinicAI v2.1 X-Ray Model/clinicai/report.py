from typing import Dict
import numpy as np
import matplotlib.pyplot as plt
import torch
from .config import Config, CFG, DEVICE

class Reporter:
    """
    Assembles training run telemetry: registers VRAM peaks, parameters,
    validation thresholds, per-class metric flags, and saves training loss curves.
    """
    def __init__(self, cfg: Config):
        self.cfg = cfg

    def print_report(self, history: Dict, best_metrics: Dict,
                     thresholds: np.ndarray, model: torch.nn.Module,
                     training_time_sec: float) -> None:
        """Prints a structured summary of the final training performance to stdout."""
        print("\n" + "=" * 70)
        print(" CLINICAI v2.1 — FINAL REPORT")
        print("=" * 70)

        best_epoch = (history.get("epoch", [0])
                      [np.argmax(history.get("val_auc", [0]))])
        print(f"\n Best Epoch : {best_epoch}")
        print(f" Training Time : {training_time_sec/60:.1f} minutes")

        if DEVICE.type == "cuda":
            mem = torch.cuda.max_memory_allocated() / 1e9
            print(f" Peak GPU Memory : {mem:.2f} GB")
            torch.cuda.reset_peak_memory_stats()

        total_p     = model.param_count() / 1e6
        trainable_p = model.trainable_param_count() / 1e6
        print(f" Total Params : {total_p:.1f} M")
        print(f" Trainable Params : {trainable_p:.1f} M")

        print(f"\n Macro ROC-AUC : {best_metrics.get('auc_macro', 0):.4f}")
        print(f" Micro ROC-AUC : {best_metrics.get('auc_micro', 0):.4f}")
        print(f" Mean Avg Prec : {best_metrics.get('map', 0):.4f}")
        print(f" Precision (macro) : {best_metrics.get('precision', 0):.4f}")
        print(f" Recall (macro) : {best_metrics.get('recall', 0):.4f}")
        print(f" F1 (macro) : {best_metrics.get('f1', 0):.4f}")

        print("\n Per-class ROC-AUC & Optimal Threshold:")
        print(f" {'Class':<24} {'AUC':>7} {'Threshold':>9}")
        print(" " + "-" * 46)
        per_cls = best_metrics.get("per_class_auc", {})
        for i, cls in enumerate(self.cfg.CLASSES):
            auc_val = per_cls.get(cls, 0.0)
            t_val   = thresholds[i]
            flag    = "STAR" if auc_val >= 0.85 else ("LOW" if auc_val < 0.75 else " ")
            print(f" {cls:<24} {auc_val:>7.4f} {t_val:>9.4f} {flag}")

        print(f"\n Backbone : {self.cfg.BACKBONE}")
        print(f" Loss Function : {self.cfg.LOSS.upper()}")
        print(f" Image Size : {self.cfg.IMG_SIZE}x{self.cfg.IMG_SIZE}")
        print("=" * 70)

    def plot_training_curves(self, history: Dict) -> None:
        """Saves a dual-panel plot showing loss and validation curves over epochs."""
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
