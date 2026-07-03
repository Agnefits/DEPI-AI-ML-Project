import copy
import time
import random
import math
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from collections import defaultdict
import numpy as np
from tqdm.auto import tqdm

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torch.cuda.amp import GradScaler, autocast

from .config import Config, DEVICE

# Optional tracking check
try:
    import wandb
    WANDB_AVAILABLE = True
except ImportError:
    WANDB_AVAILABLE = False


# ==========================================================================
# Exponential Moving Average (EMA)
# ==========================================================================
class ModelEMA:
    """
    Tracks an Exponential Moving Average (EMA) replica of the model weights.
    Averages out SGD weight updates over steps to boost final test performance.
    """
    def __init__(self, model: nn.Module, decay: float = 0.9998):
        self.decay     = decay
        self.ema_model = copy.deepcopy(model)
        self.ema_model.eval()
        for p in self.ema_model.parameters():
            p.requires_grad_(False)

    @torch.no_grad()
    def update(self, model: nn.Module) -> None:
        """Updates the running average weight based on the live model parameters."""
        for ema_p, model_p in zip(self.ema_model.parameters(), model.parameters()):
            ema_p.copy_(self.decay * ema_p + (1 - self.decay) * model_p.data)

    def state_dict(self) -> dict:
        return self.ema_model.state_dict()


# ==========================================================================
# Regularization (Mixup & CutMix)
# ==========================================================================
def mixup_data(x: torch.Tensor, y: torch.Tensor, alpha: float = 0.4) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor, float]:
    """Mixup augmentation (Zhang et al., 2018): interpolates two images and labels."""
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    B = x.size(0)
    idx = torch.randperm(B, device=x.device)
    mixed = lam * x + (1 - lam) * x[idx]
    return mixed, y, y[idx], lam


def cutmix_data(x: torch.Tensor, y: torch.Tensor, alpha: float = 1.0) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor, float]:
    """CutMix augmentation (Yun et al., 2019): patches a cut region from image_B to image_A."""
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    B, C, H, W = x.size()
    idx = torch.randperm(B, device=x.device)
    cut_ratio = math.sqrt(1 - lam)
    cut_h, cut_w = int(H * cut_ratio), int(W * cut_ratio)
    cx, cy = random.randint(0, W), random.randint(0, H)

    x1 = max(cx - cut_w // 2, 0)
    x2 = min(cx + cut_w // 2, W)
    y1 = max(cy - cut_h // 2, 0)
    y2 = min(cy + cut_h // 2, H)

    mixed = x.clone()
    mixed[:, :, y1:y2, x1:x2] = x[idx, :, y1:y2, x1:x2]
    lam = 1 - (y2 - y1) * (x2 - x1) / (H * W)
    return mixed, y, y[idx], lam


def mixup_criterion(criterion: nn.Module, logits: torch.Tensor,
                    y_a: torch.Tensor, y_b: torch.Tensor, lam: float) -> torch.Tensor:
    """Computes combined loss for mixed samples."""
    return lam * criterion(logits, y_a) + (1 - lam) * criterion(logits, y_b)


# ==========================================================================
# Early Stopping
# ==========================================================================
class EarlyStopping:
    """
    Monitors a metric and halts training when it stops improving.
    """
    def __init__(self, patience: int = 7, min_delta: float = 1e-4, mode: str = "max"):
        self.patience  = patience
        self.min_delta = min_delta
        self.mode      = mode
        self.best      = -np.inf if mode == "max" else np.inf
        self.counter   = 0
        self.stop      = False

    def __call__(self, value: float) -> bool:
        improved = (value > self.best + self.min_delta) if self.mode == "max" \
                   else (value < self.best - self.min_delta)
        if improved:
            self.best    = value
            self.counter = 0
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.stop = True
        return self.stop


# ==========================================================================
# Trainer
# ==========================================================================
class Trainer:
    """
    Ties together the multi-label PyTorch training workflow:
    AMP scaling, gradient accumulations, EMA checks, Mixup/CutMix splits,
    early stopping, and checkpoint tracking.
    """
    def __init__(self, model: nn.Module, train_loader: DataLoader,
                 val_loader: DataLoader, criterion: nn.Module,
                 optimiser: torch.optim.Optimizer, scheduler,
                 cfg: Config, evaluator):
        self.model        = model.to(DEVICE)
        self.train_loader = train_loader
        self.val_loader   = val_loader
        self.criterion    = criterion.to(DEVICE)
        self.optimiser    = optimiser
        self.scheduler    = scheduler
        self.cfg          = cfg
        self.evaluator    = evaluator

        self.ema          = ModelEMA(model, cfg.EMA_DECAY)
        self.scaler       = GradScaler(enabled=cfg.AMP)
        self.early_stop   = EarlyStopping(cfg.PATIENCE, cfg.MIN_DELTA, mode="max")

        self.history: Dict[str, List] = defaultdict(list)
        self.best_auc   = 0.0
        self.best_epoch = 0
        self.start_time = None

        # Load weights: Priority 1 - Local Checkpoint, Priority 2 - Pretrained Kaggle weights
        local_ckpt = self.cfg.CHECKPOINT_DIR / "best_model.pth"
        kaggle_ckpt = Path("/kaggle/input/notebooks/agnefits/clinicai-v2-0/checkpoints/best_model.pth")
        ckpt_path = None

        if local_ckpt.exists():
            ckpt_path = local_ckpt
            print(f"Resuming from local checkpoint: {local_ckpt}")
        elif kaggle_ckpt.exists():
            ckpt_path = kaggle_ckpt
            print(f"Loading pretrained Kaggle model: {kaggle_ckpt}")

        if ckpt_path is not None:
            ckpt = torch.load(ckpt_path, map_location=DEVICE, weights_only=False)
            if "ema" in ckpt:
                self.model.load_state_dict(ckpt["ema"])
                self.ema.ema_model.load_state_dict(ckpt["ema"])
            else:
                self.model.load_state_dict(ckpt["model"])
                self.ema.ema_model.load_state_dict(ckpt["model"])
            print(f"Loaded checkpoint (epoch {ckpt.get('epoch', '?')})")
        else:
            print("No checkpoint found. Training from scratch.")

        # Channels last optimization
        if cfg.CHANNELS_LAST and DEVICE.type == "cuda":
            self.model = self.model.to(memory_format=torch.channels_last)

        # torch.compile compilation (PyTorch >= 2.0)
        if cfg.COMPILE and hasattr(torch, "compile") and DEVICE.type == "cuda":
            print("Applying torch.compile()...")
            self.model = torch.compile(self.model)

        # Log to weights and biases if requested
        if cfg.WANDB and WANDB_AVAILABLE:
            wandb.init(project=cfg.WANDB_PROJECT, name=cfg.WANDB_RUN_NAME, config=vars(cfg))

    def _train_one_epoch(self, epoch: int) -> Dict[str, float]:
        """Runs the active gradient updates over a single dataset epoch."""
        self.model.train()
        total_loss = 0.0
        n_batches  = 0
        self.optimiser.zero_grad()

        epoch_start = time.time()

        pbar = tqdm(
            enumerate(self.train_loader),
            total=len(self.train_loader),
            desc=f"Epoch {epoch}/{self.cfg.EPOCHS}",
            leave=False,
        )

        for step, (images, labels) in pbar:
            images = images.to(DEVICE, non_blocking=True)
            labels = labels.to(DEVICE, non_blocking=True)

            if self.cfg.CHANNELS_LAST and DEVICE.type == "cuda":
                images = images.to(memory_format=torch.channels_last)

            # Apply Mixup/CutMix regularization
            use_mix = False
            if self.cfg.USE_MIXUP and self.cfg.USE_CUTMIX:
                use_mix = True
                use_cutmix = random.random() < 0.5
            elif self.cfg.USE_MIXUP:
                use_mix, use_cutmix = True, False
            elif self.cfg.USE_CUTMIX:
                use_mix, use_cutmix = True, True

            if use_mix:
                if use_cutmix:
                    images, y_a, y_b, lam = cutmix_data(images, labels, self.cfg.CUTMIX_ALPHA)
                else:
                    images, y_a, y_b, lam = mixup_data(images, labels, self.cfg.MIXUP_ALPHA)

            # Forward pass under AMP Autocasting
            with autocast(enabled=self.cfg.AMP):
                logits = self.model(images)
                if use_mix:
                    loss = mixup_criterion(self.criterion, logits, y_a, y_b, lam)
                else:
                    loss = self.criterion(logits, labels)
                loss = loss / self.cfg.ACCUM_STEPS

            # Run backward gradient pass
            self.scaler.scale(loss).backward()

            # Step optimizer every ACCUM_STEPS or at end of loader
            if (step + 1) % self.cfg.ACCUM_STEPS == 0 or (step + 1) == len(self.train_loader):
                self.scaler.unscale_(self.optimiser)
                torch.nn.utils.clip_grad_norm_(self.model.parameters(), self.cfg.GRAD_CLIP)
                self.scaler.step(self.optimiser)
                self.scaler.update()
                self.optimiser.zero_grad()
                self.ema.update(self.model)

            total_loss += loss.item() * self.cfg.ACCUM_STEPS
            n_batches  += 1

            pbar.set_postfix({
                "loss": f"{total_loss / max(n_batches, 1):.4f}",
                "lr": f"{self.optimiser.param_groups[-1]['lr']:.2e}"
            })

        epoch_time = time.time() - epoch_start
        return {
            "loss": total_loss / max(n_batches, 1),
            "time": epoch_time,
        }

    @torch.no_grad()
    def _validate(self) -> Dict[str, float]:
        """Evaluates model performance against the validation set using the EMA replica."""
        self.ema.ema_model.eval()
        all_logits, all_labels = [], []

        for images, labels in self.val_loader:
            images = images.to(DEVICE, non_blocking=True)
            if self.cfg.CHANNELS_LAST and DEVICE.type == "cuda":
                images = images.to(memory_format=torch.channels_last)
            with autocast(enabled=self.cfg.AMP):
                logits = self.ema.ema_model(images)
            all_logits.append(logits.cpu().float())
            all_labels.append(labels.cpu().float())

        all_logits = torch.cat(all_logits, dim=0)
        all_labels = torch.cat(all_labels, dim=0)
        probs      = torch.sigmoid(all_logits).numpy()
        labels_np  = all_labels.numpy()
        return self.evaluator.compute(labels_np, probs)

    def _save_checkpoint(self, epoch: int, metrics: Dict, is_best: bool) -> None:
        """Saves current training session weights if it hits a new AUC maximum."""
        state = {
            "epoch"     : epoch,
            "model"     : self.model.state_dict(),
            "ema"       : self.ema.state_dict(),
            "optimiser" : self.optimiser.state_dict(),
            "scaler"    : self.scaler.state_dict(),
            "metrics"   : metrics,
            "cfg"       : vars(self.cfg),
        }
        if is_best:
            torch.save(state, self.cfg.CHECKPOINT_DIR / "best_model.pth")
            print(f"   Best model saved  (AUC={metrics['auc_macro']:.4f})")

    def _log(self, epoch: int, train_m: Dict, val_m: Dict) -> None:
        """Prints loss reports and writes metrics into history dictionaries and WandB."""
        lr = self.optimiser.param_groups[-1]["lr"]
        self.history["epoch"].append(epoch)
        self.history["train_loss"].append(train_m["loss"])
        self.history["val_auc"].append(val_m["auc_macro"])
        self.history["lr"].append(lr)

        print(
            f"Epoch [{epoch:3d}/{self.cfg.EPOCHS}] | "
            f"Loss: {train_m['loss']:.4f} | "
            f"AUC: {val_m['auc_macro']:.4f} | "
            f"AP: {val_m['map']:.4f} | "
            f"LR: {lr:.2e} | "
            f"Time: {train_m['time']:.1f}s"
        )

        if self.cfg.WANDB and WANDB_AVAILABLE:
            wandb.log({"epoch": epoch, **train_m,
                       **{f"val_{k}": v for k, v in val_m.items()},
                       "lr": lr})

    def fit(self) -> Dict:
        """Orchestrates the main training epoch loop."""
        print(f"\n{'='*60}")
        print(f"  ClinicAI v2.1  |  {self.cfg.BACKBONE}  |  {self.cfg.LOSS.upper()}")
        print(f"  Epochs  : {self.cfg.EPOCHS}  |  "
              f"Batch : {self.cfg.BATCH_SIZE}x{self.cfg.ACCUM_STEPS}")
        print(f"  Device  : {DEVICE}")
        print(f"{'='*60}\n")

        self.start_time = time.time()

        for epoch in range(1, self.cfg.EPOCHS + 1):
            train_m = self._train_one_epoch(epoch)
            val_m   = self._validate()

            if isinstance(self.scheduler, CosineWarmupSchedulerTypeCheckDummy := object):
                # CosineWarmup step
                self.scheduler.step()
            elif hasattr(self.scheduler, "step") and not hasattr(self.scheduler, "pct_start"):
                # Standard step (if cosine_warmup or custom non-batch level)
                self.scheduler.step()

            is_best = val_m["auc_macro"] > self.best_auc
            if is_best:
                self.best_auc   = val_m["auc_macro"]
                self.best_epoch = epoch

            self._save_checkpoint(epoch, val_m, is_best)
            self._log(epoch, train_m, val_m)

            if self.early_stop(val_m["auc_macro"]):
                print(f"\nEarly stopping at epoch {epoch} "
                      f"(best AUC={self.best_auc:.4f} @ epoch {self.best_epoch})")
                break

        elapsed = time.time() - self.start_time
        print(f"\nTraining complete in {elapsed/60:.1f} min")
        if self.cfg.WANDB and WANDB_AVAILABLE:
            wandb.finish()
        return dict(self.history)
