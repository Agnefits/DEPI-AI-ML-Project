import torch
import torch.nn as nn
from .config import Config

def build_optimiser(model: nn.Module, cfg: Config) -> torch.optim.Optimizer:
    """
    Builds the AdamW optimizer with layer-wise learning rate decay (LLRD).
    The pre-trained backbone is fine-tuned conservative (0.1x of base learning rate),
    while the randomly initialized head is trained aggressively (1x of base learning rate).
    """
    backbone_params = list(model.backbone.parameters())
    head_params     = list(model.head.parameters())

    param_groups = [
        {"params": backbone_params, "lr": cfg.LR * 0.1, "name": "backbone"},
        {"params": head_params,     "lr": cfg.LR,       "name": "head"},
    ]
    return torch.optim.AdamW(param_groups, weight_decay=cfg.WEIGHT_DECAY)
