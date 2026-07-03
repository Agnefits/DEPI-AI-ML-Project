from typing import Optional
import torch
import torch.nn as nn
import torch.nn.functional as F
from .config import Config, DEVICE

class WeightedBCELoss(nn.Module):
    """
    Weighted Binary Cross Entropy with optional label smoothing.
    Replaces hard targets {0, 1} with soft targets {eps/2, 1-eps/2} to reduce overfitting.
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
    Sigmoid Focal Loss (Lin et al., 2017).
    Down-weights easy examples to let the model focus on hard, misclassified examples.
    """
    def __init__(self, gamma: float = 2.0, alpha: float = 0.25, label_smooth: float = 0.05):
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
    Asymmetric Loss (Ridnik et al., 2021).
    Utilizes different focusing parameters (gamma_pos, gamma_neg) for positive and negative labels.
    Additionally clips easy negatives to remove their contribution to gradients completely.
    """
    def __init__(self, gamma_neg: int = 4, gamma_pos: int = 1, clip: float = 0.05, label_smooth: float = 0.05):
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

        # Clip easy negatives
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
    """
    Factory function to instantiate the configured loss function.
    """
    loss_type = cfg.LOSS.lower()
    if loss_type == "bce":
        assert pos_weight is not None, "pos_weight required for WeightedBCELoss"
        return WeightedBCELoss(pos_weight.to(DEVICE), cfg.LABEL_SMOOTH)
    elif loss_type == "focal":
        return FocalLoss(cfg.FOCAL_GAMMA, cfg.FOCAL_ALPHA, cfg.LABEL_SMOOTH)
    elif loss_type == "asymmetric":
        return AsymmetricLoss(cfg.ASL_GAMMA_NEG, cfg.ASL_GAMMA_POS, cfg.ASL_CLIP, cfg.LABEL_SMOOTH)
    else:
        raise ValueError(f"Unknown loss configuration: {cfg.LOSS}")
