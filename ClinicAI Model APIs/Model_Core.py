import torch
import torch.nn as nn
import timm
import albumentations as A
from albumentations.pytorch import ToTensorV2

# 1. إعدادات الموديل الأساسية المستخرجة من النوت بوك[cite: 1]
class Config:
    CLASSES = [
        "Atelectasis", "Cardiomegaly", "Effusion", "Infiltration",
        "Mass", "Nodule", "Pneumonia", "Pneumothorax",
        "Consolidation", "Edema", "Emphysema", "Fibrosis",
        "Pleural_Thickening", "Hernia",
    ]
    NUM_CLASSES = len(CLASSES)
    BACKBONE = "convnext_base" 
    PRETRAINED = False # مش محتاجين نحمل الأوزان من النت لأننا هنحملها من الملف بتاعك
    DROP_RATE = 0.2
    DROP_PATH_RATE = 0.1
    IMG_SIZE = 320
    MEAN = [0.485, 0.456, 0.406]
    STD = [0.229, 0.224, 0.225]

# 2. معمارية الموديل[cite: 1]
class ChestXrayModel(nn.Module):
    def __init__(self, cfg: Config):
        super().__init__()
        self.cfg = cfg
        self.backbone = timm.create_model(
            cfg.BACKBONE,
            pretrained      = cfg.PRETRAINED,
            num_classes     = 0,
            global_pool     = "avg",
            drop_rate       = cfg.DROP_RATE,
            drop_path_rate  = cfg.DROP_PATH_RATE,
        )
        num_features = self.backbone.num_features
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
        for m in self.head.modules():
            if isinstance(m, nn.Linear):
                nn.init.xavier_uniform_(m.weight)
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        features = self.backbone(x)
        logits   = self.head(features)
        return logits

# 3. تحضير الصورة للـ Inference (Validation Transforms)[cite: 1]
def get_inference_transforms(cfg: Config):
    return A.Compose([
        A.Resize(cfg.IMG_SIZE, cfg.IMG_SIZE),
        A.Normalize(mean=cfg.MEAN, std=cfg.STD),
        ToTensorV2(),
    ])