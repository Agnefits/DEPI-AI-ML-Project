import math
from pathlib import Path
from typing import List, Optional, Union
import numpy as np
import cv2
import matplotlib.pyplot as plt
import torch
from torch.cuda.amp import autocast

from .config import Config, DEVICE
from .data import build_transforms

# Try importing GradCAM components
try:
    from pytorch_grad_cam import GradCAMPlusPlus
    from pytorch_grad_cam.utils.image import show_cam_on_image
    from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget
    GRADCAM_AVAILABLE = True
except ImportError:
    GRADCAM_AVAILABLE = False


class GradCAMVisualiser:
    """
    Visualizes neural network decision regions using GradCAM++ with percentile-clipping
    and Gaussian smoothing to ensure readable heatmaps.
    """
    def __init__(self, model: torch.nn.Module, cfg: Config):
        self.model = model
        self.cfg   = cfg
        self._cam  = None

        if not GRADCAM_AVAILABLE:
            print("GradCAM library not available. Explainability module disabled.")
            return

        target_layer = model.get_gradcam_layer()
        self._cam = GradCAMPlusPlus(model=model, target_layers=[target_layer])

    def visualise(self, image_path: Union[str, Path],
                  class_indices: Optional[List[int]] = None,
                  save_dir: Optional[Path] = None) -> None:
        """
        Generates and saves GradCAM++ heatmap grids overlaying structural chest X-rays.
        """
        if not GRADCAM_AVAILABLE or self._cam is None:
            return

        save_dir = save_dir or self.cfg.GRAD_CAM_DIR
        save_dir.mkdir(parents=True, exist_ok=True)

        if class_indices is None:
            class_indices = list(range(self.cfg.NUM_CLASSES))

        img_bgr = cv2.imread(str(image_path))
        if img_bgr is None:
            print(f"Cannot read: {image_path}")
            return

        img_rgb  = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        img_resz = cv2.resize(img_rgb, (self.cfg.IMG_SIZE, self.cfg.IMG_SIZE))
        img_norm = img_resz.astype(np.float32) / 255.0

        tfm    = build_transforms("val", self.cfg)
        tensor = tfm(image=img_rgb)["image"]
        tensor = tensor.unsqueeze(0).to(DEVICE)

        self.model.eval()
        with torch.no_grad():
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(tensor)
        probs = torch.sigmoid(logits).cpu().numpy().squeeze()

        fig_cols = min(4, len(class_indices))
        fig_rows = math.ceil(len(class_indices) / fig_cols)
        fig, axes = plt.subplots(fig_rows, fig_cols, figsize=(5 * fig_cols, 5 * fig_rows))

        if isinstance(axes, plt.Axes):
            axes = np.array([axes])
        axes = axes.flatten()

        for plot_idx, cls_idx in enumerate(class_indices):
            targets = [ClassifierOutputTarget(cls_idx)]
            cam_map = self._cam(input_tensor=tensor, targets=targets)[0]

            # Medical Enhancements:
            # 1. Percentile Clipping: Zero-out lower 75% noise signals
            p_val = np.percentile(cam_map, 75)
            cam_map = np.where(cam_map < p_val, 0, cam_map)

            # 2. Gaussian Smoothing: Smooth edge margins for organic rendering
            cam_map = cv2.GaussianBlur(cam_map, (15, 15), 0)

            # 3. Re-normalization: Scale from 0.0 to 1.0 after filtering
            if np.max(cam_map) != 0:
                cam_map = cam_map / np.max(cam_map)

            # Draw CAM on normalized image
            overlay = show_cam_on_image(img_norm, cam_map, use_rgb=True)
            axes[plot_idx].imshow(overlay)
            axes[plot_idx].set_title(
                f"{self.cfg.CLASSES[cls_idx]}\n(p={probs[cls_idx]:.3f})",
                fontsize=9, fontweight="bold"
            )
            axes[plot_idx].axis("off")

        # Hide unused subplots
        for ax in axes[len(class_indices):]:
            ax.axis("off")

        img_name = Path(image_path).stem
        plt.suptitle(f"GradCAM++ (Enhanced) - {img_name}", fontsize=13, fontweight="bold")
        plt.tight_layout()
        save_path = save_dir / f"gradcam_enhanced_{img_name}.png"
        plt.savefig(save_path, dpi=150, bbox_inches="tight")
        plt.close()
        print(f"Enhanced GradCAM saved: {save_path}")
