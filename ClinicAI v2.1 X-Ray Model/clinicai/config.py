import os
import random
from pathlib import Path
from datetime import datetime
import numpy as np
import torch

# Define device global configuration
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class Config:
    """
    Single source of truth for all project paths and hyperparameters.
    Modify values here to customize model training and evaluation.
    """
    # -- Paths
    DATA_DIR        = Path("/kaggle/input/datasets/organizations/nih-chest-xrays/data")
    IMAGE_DIR       = DATA_DIR / "images"
    META_CSV        = DATA_DIR / "Data_Entry_2017.csv"
    BBOX_CSV        = DATA_DIR / "BBox_List_2017.csv"
    SPLIT_FILE      = DATA_DIR / "train_val_list.txt"
    OUTPUT_DIR      = Path("/kaggle/working")
    CHECKPOINT_DIR  = OUTPUT_DIR / "checkpoints"
    GRAD_CAM_DIR    = OUTPUT_DIR / "gradcam"

    # -- Pathology classes
    CLASSES = [
        "Atelectasis", "Cardiomegaly", "Effusion", "Infiltration",
        "Mass", "Nodule", "Pneumonia", "Pneumothorax",
        "Consolidation", "Edema", "Emphysema", "Fibrosis",
        "Pleural_Thickening", "Hernia",
    ]
    NUM_CLASSES = len(CLASSES)

    # -- Image constraints
    IMG_SIZE        = 320
    MEAN            = [0.485, 0.456, 0.406]
    STD             = [0.229, 0.224, 0.225]

    # -- Training Hyperparameters
    EPOCHS          = 30
    BATCH_SIZE      = 32
    ACCUM_STEPS     = 2
    NUM_WORKERS     = 4
    PIN_MEMORY      = True
    PERSISTENT_WORKERS = True
    PREFETCH_FACTOR = 2

    # -- Optimizer Settings
    LR              = 3e-4
    LR_MIN          = 1e-6
    WEIGHT_DECAY    = 1e-2
    GRAD_CLIP       = 1.0

    # -- Learning Rate Scheduler Settings
    SCHEDULER       = "cosine_warmup"  # Options: "cosine_warmup" | "onecycle"
    WARMUP_EPOCHS   = 3

    # -- Backbone Model Architecture settings
    BACKBONE        = "convnext_base"
    PRETRAINED      = True
    DROP_RATE       = 0.2
    DROP_PATH_RATE  = 0.1

    # -- Loss Configurations
    LOSS            = "asymmetric"     # Options: "bce" | "focal" | "asymmetric"
    LABEL_SMOOTH    = 0.05

    # -- Asymmetric Loss Hyperparameters (Ridnik et al., 2021)
    ASL_GAMMA_NEG   = 4
    ASL_GAMMA_POS   = 1
    ASL_CLIP        = 0.05

    # -- Focal Loss Settings
    FOCAL_GAMMA     = 2.0
    FOCAL_ALPHA     = 0.25

    # -- Exponential Moving Average (EMA) Settings
    EMA_DECAY       = 0.9998

    # -- Data Augmentation Mix Settings
    USE_MIXUP       = True
    MIXUP_ALPHA     = 0.4
    USE_CUTMIX      = True
    CUTMIX_ALPHA    = 1.0

    # -- Early Stopping
    PATIENCE        = 7
    MIN_DELTA       = 1e-4

    # -- Test-Time Augmentation Scales
    TTA_SCALES      = [288, 320, 352]

    # -- Reproducibility & Tracking
    SEED            = 42
    AMP             = True
    CHANNELS_LAST   = True
    COMPILE         = False
    CUDNN_BENCHMARK = True
    WANDB           = False

    # -- Weights & Biases Config
    WANDB_PROJECT   = "clinicai-chestxray14"
    WANDB_RUN_NAME  = f"convnext_base_{datetime.now().strftime('%Y%m%d_%H%M')}"


CFG = Config()

# Ensure directories exist
CFG.CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
CFG.GRAD_CAM_DIR.mkdir(parents=True, exist_ok=True)


def set_seed(seed: int = 42) -> None:
    """
    Sets seed values for Python, NumPy, and PyTorch to guarantee reproducible training results.
    """
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark     = CFG.CUDNN_BENCHMARK
    os.environ["PYTHONHASHSEED"]       = str(seed)
