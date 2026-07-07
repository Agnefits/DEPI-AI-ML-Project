from pathlib import Path
from typing import Union
import numpy as np
import pandas as pd
import cv2
import matplotlib.pyplot as plt
from .config import Config, CFG

class ErrorAnalyser:
    """
    Identifies and logs model failure categories (False Positives, False Negatives,
    Hard Examples, and Uncertain boundary cases) to generate diagnostic insights.
    """
    def __init__(self, df: pd.DataFrame, cfg: Config):
        self.df  = df
        self.cfg = cfg

    def analyse(self, y_true: np.ndarray, y_prob: np.ndarray,
                thresholds: np.ndarray, image_dir: Path, n: int = 4) -> None:
        """
        Runs complete diagnostic analysis per disease class and saves grid visualizations.
        """
        y_pred = (y_prob >= thresholds).astype(int)

        for cls_idx, cls in enumerate(self.cfg.CLASSES):
            gt   = y_true[:, cls_idx]
            prob = y_prob[:, cls_idx]
            pred = y_pred[:, cls_idx]

            fp_idx    = np.where((pred == 1) & (gt == 0))[0]
            fn_idx    = np.where((pred == 0) & (gt == 1))[0]
            
            # Compute Binary Cross Entropy Loss for difficulty ranking
            bce_loss  = -(gt * np.log(prob + 1e-8) + (1 - gt) * np.log(1 - prob + 1e-8))
            hard_idx  = np.argsort(bce_loss)[::-1][:n]
            
            # Margin proximity to decision boundary
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
        """Saves a horizontal subplot panel displaying diagnostic images and model scores."""
        fig, axes = plt.subplots(1, len(indices), figsize=(4 * len(indices), 4))
        if len(indices) == 1:
            axes = [axes]
        for ax, idx in zip(axes, indices):
            img_name = self.df.iloc[idx]["Image Index"]
            img_path = image_dir / img_name
            if img_path.exists():
                img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
                ax.imshow(img, cmap="gray")
            ax.set_title(f"GT={int(gt[idx])} P={prob[idx]:.3f}", fontsize=9)
            ax.axis("off")
        plt.suptitle(f"{label.replace('_', ' ')} — {cls}", fontweight="bold")
        plt.tight_layout()
        fname = f"error_{label.lower()}_{cls.lower()}.png"
        plt.savefig(CFG.OUTPUT_DIR / fname, dpi=120)
        plt.close()
