from pathlib import Path
from typing import Dict, List, Optional, Union
import numpy as np
import pandas as pd
import cv2
import torch
from torch.utils.data import DataLoader
from torch.cuda.amp import autocast

from .config import Config, DEVICE
from .data import build_transforms, build_tta_transforms, ChestXray14Dataset

class TTAInference:
    """
    Performs Test-Time Augmentation (TTA) by scaling and flipping the image,
    and averaging predictions to reduce spatial variance.
    """
    def __init__(self, model: torch.nn.Module, cfg: Config):
        self.model = model.eval()
        self.cfg   = cfg

    @torch.no_grad()
    def predict(self, image_path: Union[str, Path]) -> np.ndarray:
        """
        Runs predictions for a single image with multi-scale and flipped TTA.
        """
        img = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            raise FileNotFoundError(f"Cannot read: {image_path}")
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)

        all_probs = []
        for scale in self.cfg.TTA_SCALES:
            tfm = build_tta_transforms(scale, self.cfg)

            # Original scale
            t_img = tfm(image=img)["image"].unsqueeze(0).to(DEVICE)
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(t_img)
            all_probs.append(torch.sigmoid(logits).cpu().numpy())

            # Horizontally flipped scale
            img_f = cv2.flip(img, 1)
            t_imgf = tfm(image=img_f)["image"].unsqueeze(0).to(DEVICE)
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(t_imgf)
            all_probs.append(torch.sigmoid(logits).cpu().numpy())

        return np.mean(all_probs, axis=0).squeeze(0)  # Average predictions


class InferencePipeline:
    """
    Orchestrates prediction requests for single image testing,
    batch dataset validation, or CSV submission output.
    """
    def __init__(self, model: torch.nn.Module, cfg: Config,
                 thresholds: Optional[np.ndarray] = None):
        self.model      = model.eval()
        self.cfg        = cfg
        self.thresholds = (thresholds if thresholds is not None
                           else np.full(cfg.NUM_CLASSES, 0.5))
        self.tta        = TTAInference(model, cfg)
        self.transform  = build_transforms("val", cfg)

    def predict_single(self, image_path: Union[str, Path], use_tta: bool = True) -> Dict:
        """
        Runs single image classification with or without TTA.
        """
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
        detected    = [cls for cls, pred in zip(self.cfg.CLASSES, predictions) if pred]

        return {
            "probabilities"  : dict(zip(self.cfg.CLASSES, probs.tolist())),
            "predictions"    : dict(zip(self.cfg.CLASSES, predictions.tolist())),
            "detected_labels": detected if detected else ["No Finding"],
        }

    @torch.no_grad()
    def predict_batch(self, df: pd.DataFrame, image_dir: Path) -> np.ndarray:
        """
        Runs batch inference and returns predicted probabilities matrix [N, 14].
        """
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
        """
        Runs batch predictions and outputs a Kaggle-style submission file.
        """
        print(f"Generating submission for {len(df):,} images...")
        probs   = self.predict_batch(df, image_dir)
        preds   = (probs >= self.thresholds).astype(int)
        result  = pd.DataFrame(preds, columns=self.cfg.CLASSES)
        result.insert(0, "Image Index", df["Image Index"].values)
        save_path = save_path or self.cfg.OUTPUT_DIR / "submission.csv"
        result.to_csv(save_path, index=False)
        print(f"Submission saved to {save_path} ({len(result):,} rows)")
        return result
