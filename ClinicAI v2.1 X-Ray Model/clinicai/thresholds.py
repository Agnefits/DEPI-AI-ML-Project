import json
from pathlib import Path
from typing import Optional
import numpy as np
from sklearn.metrics import roc_curve
from .config import Config, CFG

class ThresholdOptimiser:
    """
    Finds the optimal decision threshold for each class independently
    using Youden's J statistic:
        J = Sensitivity + Specificity - 1 = True Positive Rate - False Positive Rate
    This helps balance predictions for highly imbalanced classes.
    """
    def __init__(self, cfg: Config):
        self.cfg        = cfg
        self.thresholds = np.full(cfg.NUM_CLASSES, 0.5)

    def fit(self, y_true: np.ndarray, y_prob: np.ndarray) -> np.ndarray:
        """Finds optimal per-class thresholds from true labels and probabilities."""
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
        """Saves thresholds to a JSON configuration file."""
        path = path or CFG.OUTPUT_DIR / "thresholds.json"
        with open(path, "w") as f:
            json.dump(dict(zip(self.cfg.CLASSES, self.thresholds.tolist())), f, indent=2)
        print(f"Thresholds saved to {path}")

    def load(self, path: Path) -> np.ndarray:
        """Loads thresholds from a JSON configuration file."""
        with open(path) as f:
            d = json.load(f)
        self.thresholds = np.array([d[cls] for cls in self.cfg.CLASSES])
        return self.thresholds
