import math
from typing import List
import torch
from .config import Config

class CosineWarmupScheduler(torch.optim.lr_scheduler._LRScheduler):
    """
    Cosine annealing learning rate scheduler with linear warmup.
    Warmup phase: learning rate increases linearly from 0 to target base_lr.
    Cosine phase: learning rate decays from base_lr to lr_min along a cosine curve.
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
                # Linear warmup phase
                scale = (epoch + 1) / max(self.warmup_epochs, 1)
            else:
                # Cosine annealing phase
                progress = (epoch - self.warmup_epochs) / max(
                    self.total_epochs - self.warmup_epochs, 1
                )
                scale = (self.lr_min / max(base_lr, 1e-12) +
                         0.5 * (1 - self.lr_min / max(base_lr, 1e-12)) *
                         (1 + math.cos(math.pi * progress)))
            lrs.append(base_lr * scale)
        return lrs


def build_scheduler(optimiser: torch.optim.Optimizer, cfg: Config, steps_per_epoch: int = 0):
    """
    Factory function to instantiate the configured scheduler.
    """
    scheduler_type = cfg.SCHEDULER.lower()
    if scheduler_type == "cosine_warmup":
        return CosineWarmupScheduler(
            optimiser, warmup_epochs=cfg.WARMUP_EPOCHS,
            total_epochs=cfg.EPOCHS, lr_min=cfg.LR_MIN
        )
    elif scheduler_type == "onecycle":
        assert steps_per_epoch > 0, "steps_per_epoch must be provided for OneCycleLR"
        return torch.optim.lr_scheduler.OneCycleLR(
            optimiser,
            max_lr=[g["lr"] for g in optimiser.param_groups],
            epochs=cfg.EPOCHS,
            steps_per_epoch=steps_per_epoch,
            pct_start=0.1,
            anneal_strategy="cos",
            div_factor=25.0,
            final_div_factor=1e4,
        )
    else:
        raise ValueError(f"Unknown scheduler configuration: {cfg.SCHEDULER}")
