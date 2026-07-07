import torch
import torch.nn as nn
import timm
from .config import Config

class ChestXrayModel(nn.Module):
    """
    Modular Multi-label classification model with a custom classification head
    built on top of any timm-supported vision backbone.
    
    Supported backbones:
        * convnext_base (default)
        * tf_efficientnetv2_m
        * densenet121 (original CheXNet baseline)
        * swin_base_patch4_window7_224
        * convnext_small
        * tf_efficientnetv2_s
    """
    def __init__(self, cfg: Config):
        super().__init__()
        self.cfg = cfg

        # Create backbone using timm
        self.backbone = timm.create_model(
            cfg.BACKBONE,
            pretrained=cfg.PRETRAINED,
            num_classes=0,           # Remove original classification head
            global_pool="avg",       # Use average pooling
            drop_rate=cfg.DROP_RATE,
            drop_path_rate=cfg.DROP_PATH_RATE,
        )
        num_features = self.backbone.num_features
        print(f"Backbone : {cfg.BACKBONE} | Features : {num_features}")

        # Multi-label classification head
        self.head = nn.Sequential(
            nn.LayerNorm(num_features),
            nn.Dropout(p=cfg.DROP_RATE),
            nn.Linear(num_features, 512),
            nn.GELU(),
            nn.Dropout(p=cfg.DROP_RATE / 2),
            nn.Linear(512, cfg.NUM_CLASSES),
        )
        self._init_head()

    def _init_head(self) -> None:
        """Applies Xavier uniform initialization on classification head linear layers."""
        for m in self.head.modules():
            if isinstance(m, nn.Linear):
                nn.init.xavier_uniform_(m.weight)
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Runs the forward pass.
        Returns raw logits without Sigmoid activation for numerical stability.
        """
        features = self.backbone(x)
        logits   = self.head(features)
        return logits

    def get_gradcam_layer(self) -> nn.Module:
        """
        Returns the last convolutional layer of the backbone for GradCAM heatmaps.
        """
        backbone_name = self.cfg.BACKBONE.lower()
        if "convnext" in backbone_name:
            return self.backbone.stages[-1].blocks[-1]
        elif "densenet" in backbone_name:
            return self.backbone.features.denseblock4
        elif "efficientnet" in backbone_name:
            return self.backbone.blocks[-1]
        elif "swin" in backbone_name:
            return self.backbone.layers[-1].blocks[-1]
        else:
            # Fallback: find the last module with weights
            for module in reversed(list(self.backbone.modules())):
                if hasattr(module, "weight"):
                    return module
            return self.backbone

    @torch.no_grad()
    def predict_proba(self, x: torch.Tensor) -> torch.Tensor:
        """
        Returns the predicted sigmoid probabilities for inference.
        """
        self.eval()
        logits = self(x)
        return torch.sigmoid(logits)

    def param_count(self) -> int:
        """Returns total parameter count."""
        return sum(p.numel() for p in self.parameters())

    def trainable_param_count(self) -> int:
        """Returns trainable parameter count."""
        return sum(p.numel() for p in self.parameters() if p.requires_grad)
