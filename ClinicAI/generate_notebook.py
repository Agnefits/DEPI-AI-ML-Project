"""
generate_notebook.py
~~~~~~~~~~~~~~~~~~~~
Converts clinicai_v2.0.py into a fully structured Jupyter Notebook
(clinicai_v2.0.ipynb) with:
  - A rich title + TOC Markdown cell
  - One Markdown header cell per section
  - One code cell per section
  - A standalone "RUN PIPELINE" cell at the end
"""

import json, re, textwrap
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE    = Path(__file__).parent
PY_SRC  = HERE / "clinicai_v2.0.py"
NB_OUT  = HERE / "clinicai_v2.0.ipynb"

src = PY_SRC.read_text(encoding="utf-8")

# ---------------------------------------------------------------------------
# Cell helpers
# ---------------------------------------------------------------------------
def md_cell(text: str) -> dict:
    lines = [l + "\n" for l in text.splitlines()]
    if lines:
        lines[-1] = lines[-1].rstrip("\n")
    return {
        "cell_type": "markdown",
        "metadata": {},
        "source": lines,
    }

def code_cell(text: str) -> dict:
    text  = text.strip("\n")
    lines = [l + "\n" for l in text.splitlines()]
    if lines:
        lines[-1] = lines[-1].rstrip("\n")
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": lines,
    }

# ---------------------------------------------------------------------------
# Title / banner cell
# ---------------------------------------------------------------------------
title_md = """\
# 🏥 ClinicAI v2.0 — NIH ChestX-ray14 | Kaggle Grandmaster Pipeline

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue)](https://python.org)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.x-red)](https://pytorch.org)
[![timm](https://img.shields.io/badge/timm-0.9%2B-green)](https://timm.fast.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

**Task:** Multi-label classification of 14 thoracic pathologies  
**Dataset:** NIH ChestX-ray14 (112 120 frontal chest X-rays)  
**Target:** Macro ROC-AUC > 0.84  
**Platform:** Kaggle (P100 / T4 / L4 GPU)  

---

## 📋 Table of Contents

| # | Section | Key Techniques |
|---|---------|----------------|
| 1 | [Environment Setup](#section-1) | Package installation, imports |
| 2 | [Reproducibility & Config](#section-2) | Seeds, determinism, global hyperparameters |
| 3 | [Dataset Analysis & EDA](#section-3) | Class distribution, co-occurrence, sample images |
| 4 | [Patient-Wise Data Split](#section-4) | Iterative multilabel stratification |
| 5 | [Data Pipeline](#section-5) | Albumentations: CLAHE, RRC, Mixup, CoarseDropout |
| 6 | [DataLoader](#section-6) | pin_memory, persistent_workers, prefetch |
| 7 | [Model Architecture](#section-7) | ConvNeXt / EfficientNetV2 / DenseNet / Swin |
| 8 | [Loss Functions](#section-8) | Weighted BCE, Focal Loss, Asymmetric Loss |
| 9 | [Optimiser](#section-9) | AdamW + layer-wise learning rates |
| 10 | [Scheduler](#section-10) | Cosine warmup / OneCycleLR |
| 11 | [Training Loop](#section-11) | AMP, gradient accumulation, EMA, early stopping |
| 12 | [Metrics](#section-12) | ROC-AUC, AP, P/R/F1, confusion matrix |
| 13 | [Threshold Optimisation](#section-13) | Per-class Youden's J statistic |
| 14 | [Test-Time Augmentation](#section-14) | Multi-scale + horizontal-flip TTA |
| 15 | [Explainability](#section-15) | GradCAM heatmap overlays |
| 16 | [Inference Pipeline](#section-16) | Single image, batch, submission CSV |
| 17 | [Error Analysis](#section-17) | FP / FN / hard / uncertain examples |
| 18 | [Training Tricks](#section-18) | Label smoothing, EMA, Mixup, CutMix |
| 19 | [Performance Optimisation](#section-19) | torch.compile, channels_last, cudnn |
| 20 | [Final Report](#section-20) | AUC table, thresholds, GPU stats |
| — | [▶ Run Full Pipeline](#run) | Execute end-to-end |

---
> **How to use:** Run all cells top-to-bottom on a Kaggle GPU kernel.  
> Set `CFG.WANDB = True` to stream metrics to Weights & Biases.
"""

# ---------------------------------------------------------------------------
# Section definitions:
# (anchor, emoji, title, description, start_marker, end_marker)
# start_marker / end_marker are substrings that identify the block in the .py
# ---------------------------------------------------------------------------
sections = [
    {
        "anchor"  : "section-1",
        "emoji"   : "📦",
        "title"   : "Section 1 — Environment Setup & Package Installation",
        "desc"    : """\
Install only the packages that are *not* pre-installed on the Kaggle GPU image.

| Package | Purpose |
|---------|---------|
| `timm` | State-of-the-art model zoo (ConvNeXt, EfficientNetV2, Swin …) |
| `albumentations` | Fast, GPU-friendly image augmentations |
| `grad-cam` | GradCAM explainability heatmaps |
| `iterstrat` | Iterative multilabel stratification for patient-wise splits |
| `wandb` | (Optional) experiment tracking |

> **Note:** Uncomment the `pip_install(...)` line below if any package is missing in your kernel.""",
        "start"   : "# SECTION 1",
        "end"     : "# SECTION 2",
    },
    {
        "anchor"  : "section-2",
        "emoji"   : "🔁",
        "title"   : "Section 2 — Reproducibility & Global Config",
        "desc"    : """\
### Design Philosophy
- **`Config` class** — single source of truth for every hyperparameter and path.  
  Change a value here; all downstream modules pick it up automatically.
- **`set_seed()`** — fixes Python, NumPy, and PyTorch RNG for bit-exact reproducibility.
- **`CUDNN_BENCHMARK = True`** — auto-tunes cuDNN kernel selection for the fixed input size.

### Key Hyperparameters

| Param | Value | Rationale |
|-------|-------|-----------|
| `IMG_SIZE` | 320 | Sweet-spot for ConvNeXt-Base on P100 (memory vs accuracy) |
| `BATCH_SIZE` | 32 × 2 accum | Effective batch = 64; fits in 16 GB VRAM with AMP |
| `LR` | 3e-4 | Head LR; backbone gets 10× lower (3e-5) |
| `EMA_DECAY` | 0.9998 | Very slow EMA update — stable for long training runs |
| `ASL_GAMMA_NEG` | 4 | Aggressively down-weights easy negatives |""",
        "start"   : "# SECTION 2",
        "end"     : "# SECTION 3",
    },
    {
        "anchor"  : "section-3",
        "emoji"   : "📊",
        "title"   : "Section 3 — Dataset Analysis & EDA",
        "desc"    : """\
`DataAnalyser` produces **6 publication-ready figures** saved to `/kaggle/working/`:

| Figure | Shows |
|--------|-------|
| `class_distribution.png` | Bar chart of per-class prevalence (huge imbalance!) |
| `cooccurrence_matrix.png` | Conditional probability P(col \\| row) — disease co-morbidity |
| `patient_distribution.png` | Images-per-patient histogram + patient split pie |
| `view_position.png` | PA vs AP vs LL breakdown |
| `sample_images.png` | One representative X-ray per disease class |

**Printed table** shows `neg:pos` ratio and prevalence % for every class.

> Hernia has only ~227 images with a 500:1 imbalance — the hardest class.""",
        "start"   : "# SECTION 3",
        "end"     : "# SECTION 4",
    },
    {
        "anchor"  : "section-4",
        "emoji"   : "✂️",
        "title"   : "Section 4 — Patient-Wise Data Split",
        "desc"    : """\
### Why Patient-Wise?
The NIH dataset contains **multiple images per patient**.  A naive random split
would leak the same patient into both train and validation, inflating AUC by
several points — a common mistake in chest X-ray literature.

### Strategy
1. Aggregate labels per patient (`OR` across all their images).
2. Run **`MultilabelStratifiedShuffleSplit`** (iterstrat) so each class has
   ~equal prevalence in train and val.
3. Fall back to a plain random patient split if iterstrat is unavailable.

```
Total patients ≈ 30 805
Train patients ≈ 26 184  (85%)
Val   patients ≈  4 621  (15%)
```

**Assertion:** The code verifies zero patient overlap before proceeding.""",
        "start"   : "# SECTION 4",
        "end"     : "# SECTION 5",
    },
    {
        "anchor"  : "section-5",
        "emoji"   : "🔬",
        "title"   : "Section 5 — Data Pipeline (Albumentations)",
        "desc"    : """\
### Training Augmentations

| Transform | p | Rationale |
|-----------|---|-----------|
| `Resize(352, 352)` | 1.0 | Slightly oversized before crop |
| `RandomResizedCrop(320)` | 1.0 | Scale/aspect-ratio jitter |
| `HorizontalFlip` | 0.5 | Chest X-rays are horizontally symmetric |
| `ShiftScaleRotate` | 0.5 | Small geometric deformation |
| `CLAHE` | 0.5 | **Key for X-rays** — improves local contrast |
| `RandomBrightnessContrast` | 0.5 | Intensity variation |
| `GaussNoise` | 0.3 | Simulates sensor noise |
| `GaussianBlur` | 0.1 | Mild blur regularisation |
| `CoarseDropout` | 0.2 | Occlusion regularisation |
| `Normalize` | 1.0 | ImageNet mean/std (all backbones are ImageNet-pretrained) |

### Validation: Resize → Normalize only (no randomness).""",
        "start"   : "# SECTION 5",
        "end"     : "# SECTION 6",
    },
    {
        "anchor"  : "section-6",
        "emoji"   : "⚡",
        "title"   : "Section 6 — Dataset Class & DataLoader",
        "desc"    : """\
### `ChestXray14Dataset`
- Loads grayscale PNGs → converts to 3-channel RGB (all ImageNet backbones expect RGB).
- Pre-computes the label matrix as `float32` numpy array at construction time.
- Returns `(image_tensor, label_tensor)` pairs.

### DataLoader Optimisations for Kaggle

| Option | Value | Effect |
|--------|-------|--------|
| `num_workers` | 4 | Parallel CPU data loading |
| `pin_memory` | True | Page-locked RAM → faster CPU→GPU transfer |
| `persistent_workers` | True | Workers survive across epochs (saves fork overhead) |
| `prefetch_factor` | 2 | Each worker pre-fetches 2 batches ahead |
| `drop_last` | True (train) | Avoids tiny last batch causing BatchNorm instability |""",
        "start"   : "# SECTION 6",
        "end"     : "# SECTION 7",
    },
    {
        "anchor"  : "section-7",
        "emoji"   : "🧠",
        "title"   : "Section 7 — Model Architecture",
        "desc"    : """\
### Modular Backbone Framework
Switch backbone by changing **one line**: `CFG.BACKBONE = "..."`.

| Backbone | Params | Notes |
|----------|--------|-------|
| `convnext_base` ✅ | 89 M | **Default.** Best accuracy on ChestX-ray14 |
| `tf_efficientnetv2_m` | 54 M | Memory-efficient; faster than ConvNeXt |
| `densenet121` | 8 M | Original CheXNet backbone; lightweight baseline |
| `swin_base_patch4_window7_224` | 88 M | Vision Transformer; strong on global patterns |
| `convnext_small` | 50 M | Faster ConvNeXt variant |

### Classification Head
```
backbone (pretrained) → GAP
    → LayerNorm(num_features)
    → Dropout(0.2)
    → Linear(num_features → 512)
    → GELU
    → Dropout(0.1)
    → Linear(512 → 14)       # raw logits, no sigmoid
```
> **No sigmoid in forward()** — loss functions operate on logits for numerical stability.""",
        "start"   : "# SECTION 7",
        "end"     : "# SECTION 8",
    },
    {
        "anchor"  : "section-8",
        "emoji"   : "📉",
        "title"   : "Section 8 — Loss Functions",
        "desc"    : """\
Three losses are implemented and benchmarked. **Asymmetric Loss is the default.**

### Weighted BCE
Standard BCEWithLogitsLoss with per-class `pos_weight = neg/pos`.
+ Label smoothing replaces hard {0,1} targets with soft {ε/2, 1−ε/2}.

### Focal Loss (Lin et al., 2017)
`FL(p) = −α(1−p)^γ log(p)` — down-weights easy examples, focuses on hard ones.

### Asymmetric Loss ✅ (Ridnik et al., 2021)
Uses **different γ** for positives and negatives:
- `γ_pos = 1` → mild down-weighting of easy positives
- `γ_neg = 4` → aggressive down-weighting of easy negatives
- **Probability shifting** (clip=0.05): removes very confident negatives from gradient

> ASL consistently outperforms BCE and Focal on multi-label medical datasets.""",
        "start"   : "# SECTION 8",
        "end"     : "# SECTION 9",
    },
    {
        "anchor"  : "section-9",
        "emoji"   : "⚙️",
        "title"   : "Section 9 — Optimiser (AdamW)",
        "desc"    : """\
**AdamW** with decoupled weight decay (Loshchilov & Hutter, 2019).

### Layer-wise Learning Rate Decay (LLRD)
| Parameter Group | Learning Rate | Rationale |
|-----------------|---------------|-----------|
| Backbone | `LR × 0.1 = 3e-5` | Pre-trained weights need gentle updates |
| Head | `LR × 1.0 = 3e-4` | Randomly initialised — needs aggressive training |

This pattern is standard in BERT fine-tuning and transfers well to vision.""",
        "start"   : "# SECTION 9",
        "end"     : "# SECTION 10",
    },
    {
        "anchor"  : "section-10",
        "emoji"   : "📈",
        "title"   : "Section 10 — Learning Rate Scheduler",
        "desc"    : """\
Two scheduler options are available via `CFG.SCHEDULER`.

### Cosine Warmup ✅ (default)
```
Epoch 0 → WARMUP_EPOCHS : LR increases linearly 0 → base_lr
Epoch WARMUP → EPOCHS   : LR decays base_lr → LR_MIN  (cosine curve)
```
Warmup prevents head weight divergence in the first epochs (large gradients).

### OneCycleLR (alternative)
Super-convergence policy from Smith & Topin (2018).  
Max LR → step-up → step-down in a single cycle.  
Set `CFG.SCHEDULER = "onecycle"` to activate.""",
        "start"   : "# SECTION 10",
        "end"     : "# SECTION 18A",
    },
    {
        "anchor"  : "section-18",
        "emoji"   : "🎲",
        "title"   : "Section 18 — Training Tricks (EMA, Mixup, CutMix)",
        "desc"    : """\
### EMA — Exponential Moving Average
`θ_ema ← decay × θ_ema + (1 − decay) × θ_model`

EMA weights average out SGD noise → better generalisation at test time.
`decay = 0.9998` means the EMA lags ~5 000 update steps behind the live model.
**All validation and test inference uses the EMA model.**

### Mixup (Zhang et al., 2018)
Linearly interpolates two images *and* their labels:
`x_mix = λ·x_i + (1−λ)·x_j` — encourages linear interpolation in feature space.

### CutMix (Yun et al., 2019)
Pastes a rectangular crop from one image into another.
Stronger regulariser than Mixup because it removes content, forcing the model
to rely on multiple spatial regions (improves localisation).

### Label Smoothing
Applied inside every loss function: replaces hard targets with `{ε/2, 1−ε/2}`.""",
        "start"   : "# SECTION 18A",
        "end"     : "# SECTION 11",
    },
    {
        "anchor"  : "section-11",
        "emoji"   : "🏋️",
        "title"   : "Section 11 — Training Loop",
        "desc"    : """\
The `Trainer` class ties together every modern training technique:

```
for epoch in range(EPOCHS):
    for step, (images, labels) in enumerate(train_loader):
        apply Mixup or CutMix
        forward pass (AMP autocast)
        loss = ASL(logits, labels) / ACCUM_STEPS
        scaler.scale(loss).backward()
        if (step+1) % ACCUM_STEPS == 0:
            unscale → clip_grad_norm → scaler.step → scaler.update
            ema.update(model)
    scheduler.step()
    validate with EMA model
    save checkpoint if best AUC
    early stop if no improvement for PATIENCE epochs
```

### Key flags
| Technique | Config key | Default |
|-----------|-----------|---------|
| Automatic Mixed Precision | `CFG.AMP` | `True` |
| Gradient accumulation | `CFG.ACCUM_STEPS` | `2` |
| Gradient clipping | `CFG.GRAD_CLIP` | `1.0` |
| EMA decay | `CFG.EMA_DECAY` | `0.9998` |
| Early stopping patience | `CFG.PATIENCE` | `7` epochs |""",
        "start"   : "# SECTION 11",
        "end"     : "# SECTION 12",
    },
    {
        "anchor"  : "section-12",
        "emoji"   : "📐",
        "title"   : "Section 12 — Metrics",
        "desc"    : """\
`Evaluator` computes a full suite of multi-label metrics after every epoch
and produces three plots at the end of training.

| Metric | Notes |
|--------|-------|
| **ROC-AUC macro** | Primary metric — unaffected by threshold choice |
| **ROC-AUC micro** | Treats every (sample, label) pair independently |
| **mAP** | Area under the Precision-Recall curve (macro) |
| **Precision / Recall / F1** | Macro-averaged, threshold-dependent |
| **Per-class AUC** | Allows identifying the weakest classes |

### Saved Plots
- `per_class_auc.png` — sorted bar chart coloured by AUC value
- `roc_curves.png` — individual ROC curves for all 14 classes
- `confusion_matrices.png` — TP/FP/TN/FN for each class at threshold 0.5""",
        "start"   : "# SECTION 12",
        "end"     : "# SECTION 13",
    },
    {
        "anchor"  : "section-13",
        "emoji"   : "🎯",
        "title"   : "Section 13 — Per-class Threshold Optimisation",
        "desc"    : """\
Using a **fixed threshold of 0.5** is suboptimal for imbalanced multi-label data:
- Rare classes (Hernia, Pneumonia) are systematically under-predicted.
- Each class has a different optimal operating point on its ROC curve.

### Youden's J Statistic
For each class independently, we search the threshold that maximises:

$$J = \\text{TPR} - \\text{FPR} = \\text{Sensitivity} + \\text{Specificity} - 1$$

This simultaneously maximises both sensitivity and specificity.

### Result
- Optimal thresholds are saved to `thresholds.json`.
- F1 typically improves by **5–15%** compared to fixed 0.5.
- AUC is unaffected (threshold-independent), but precision/recall improve.""",
        "start"   : "# SECTION 13",
        "end"     : "# SECTION 14",
    },
    {
        "anchor"  : "section-14",
        "emoji"   : "🔄",
        "title"   : "Section 14 — Test-Time Augmentation (TTA)",
        "desc"    : """\
TTA averages predictions from multiple augmented views of the same image,
reducing prediction variance without any retraining.

### Augmentation Views
For each scale in `CFG.TTA_SCALES = [288, 320, 352]`:
1. **Original** image at that scale
2. **Horizontally flipped** image at that scale

→ **6 total forward passes** per image.

### Expected Gain
TTA typically boosts macro AUC by **0.3–0.8 percentage points**.

> **Batch mode** (for submission) uses only the standard scale for speed.""",
        "start"   : "# SECTION 14",
        "end"     : "# SECTION 15",
    },
    {
        "anchor"  : "section-15",
        "emoji"   : "🔥",
        "title"   : "Section 15 — Explainability (GradCAM)",
        "desc"    : """\
**GradCAM** (Selvaraju et al., 2017) computes the gradient of the class score
with respect to the last convolutional feature map, producing a heatmap that
highlights *which spatial regions* drove the prediction.

### Clinical Value
In chest X-rays, GradCAM typically highlights:
- Lung apices for Pneumothorax
- Cardiac silhouette for Cardiomegaly
- Costophrenic angles for Effusion

This provides **radiologist-level interpretability** and helps identify
when the model is focusing on spurious correlations.

### Saved output
`/kaggle/working/gradcam/gradcam_<image_name>.png` — one panel per disease class.""",
        "start"   : "# SECTION 15",
        "end"     : "# SECTION 16",
    },
    {
        "anchor"  : "section-16",
        "emoji"   : "🚀",
        "title"   : "Section 16 — Inference Pipeline",
        "desc"    : """\
`InferencePipeline` is the production-ready interface for deployment.

### Methods

| Method | Input | Output |
|--------|-------|--------|
| `predict_single(path, use_tta=True)` | One image path | Dict: probs + preds + disease names |
| `predict_batch(df, image_dir)` | DataFrame | `[N, 14]` probability matrix |
| `generate_submission(df, image_dir)` | DataFrame | Kaggle CSV saved to disk |

### Submission Format
```
Image Index, Atelectasis, Cardiomegaly, ..., Hernia
00000001_000.png, 0, 1, ..., 0
```""",
        "start"   : "# SECTION 16",
        "end"     : "# SECTION 17",
    },
    {
        "anchor"  : "section-17",
        "emoji"   : "🔍",
        "title"   : "Section 17 — Error Analysis",
        "desc"    : """\
`ErrorAnalyser` systematically identifies *how* the model fails for each class.

| Category | Definition | Clinical Meaning |
|----------|-----------|-----------------|
| **False Positives** | Predicted positive, GT negative | Over-diagnosis — unnecessary follow-up |
| **False Negatives** | Predicted negative, GT positive | Under-diagnosis — missed disease ⚠️ |
| **Hard Examples** | Highest binary cross-entropy | Cases where model is most wrong |
| **Most Uncertain** | Predicted prob closest to threshold | Cases where model is least confident |

Each category produces a saved figure grid.  
Use these to guide **data collection**, **augmentation tuning**, and **threshold adjustment**.""",
        "start"   : "# SECTION 17",
        "end"     : "# SECTION 19",
    },
    {
        "anchor"  : "section-19",
        "emoji"   : "⚡",
        "title"   : "Section 19 — Performance Optimisation",
        "desc"    : """\
Hardware-level optimisations for Kaggle P100 / T4 / L4 GPUs.

### Channels-Last Memory Format
NVIDIA convolution kernels run faster on NHWC (channels last) vs NCHW layout.
`model.to(memory_format=torch.channels_last)` enables this transparently.

### `torch.compile` (PyTorch ≥ 2.0)
Traces the model graph, fuses operators, and generates optimised Triton/CUDA kernels.
10–40% speedup at the cost of ~2 min one-time compilation.
**Disabled by default** (`CFG.COMPILE = False`) — enable for long training runs.

### `cudnn.benchmark = True`
Auto-selects the fastest cuDNN convolution algorithm for each input shape.
Large speedup for fixed image sizes (our case: always 320×320).

### `non_blocking=True`
All `.to(DEVICE, non_blocking=True)` calls in the DataLoader allow the GPU to
overlap data transfer with computation.""",
        "start"   : "# SECTION 19",
        "end"     : "# SECTION 20",
    },
    {
        "anchor"  : "section-20",
        "emoji"   : "📋",
        "title"   : "Section 20 — Final Report",
        "desc"    : """\
`Reporter` prints a comprehensive summary after training completes.

### Output
- Best epoch & total training time
- Peak GPU memory usage
- Total & trainable parameter count
- Macro / Micro ROC-AUC
- Mean Average Precision
- Per-class AUC table with optimal thresholds
- `training_curves.png` — loss and AUC curves over epochs""",
        "start"   : "# SECTION 20",
        "end"     : "# ===========================================================================\n# MAIN",
    },
    {
        "anchor"  : "main",
        "emoji"   : "🔧",
        "title"   : "Main Orchestrator — load_metadata() + main()",
        "desc"    : """\
`main()` wires together all 20 sections in sequence:

```
load_metadata  →  EDA  →  patient split  →  transforms  →  datasets + loaders
  →  model  →  loss/optimiser/scheduler  →  Trainer.fit()
  →  load best checkpoint  →  full metrics  →  threshold optimisation
  →  GradCAM  →  error analysis  →  inference demo  →  final report
```""",
        "start"   : "# ===========================================================================\n# MAIN",
        "end"     : "# ===========================================================================\n# Entry point",
    },
    {
        "anchor"  : "run",
        "emoji"   : "▶️",
        "title"   : "▶ Run Full Pipeline",
        "desc"    : """\
Execute the complete end-to-end training and evaluation pipeline.

> **Estimated time on Kaggle T4:** ~3–4 hours for 30 epochs  
> **Expected result:** Macro ROC-AUC > 0.84

Adjust `CFG.EPOCHS`, `CFG.BACKBONE`, or `CFG.LOSS` in Section 2 before running.""",
        "start"   : "# ===========================================================================\n# Entry point",
        "end"     : None,
    },
]

# ---------------------------------------------------------------------------
# Extract code blocks between section markers
# ---------------------------------------------------------------------------
def extract_between(src: str, start_marker: str, end_marker: str | None) -> str:
    """Return the portion of src between start_marker and end_marker."""
    s = src.find(start_marker)
    if s == -1:
        return ""
    if end_marker is None:
        return src[s:]
    e = src.find(end_marker, s + len(start_marker))
    if e == -1:
        return src[s:]
    return src[s:e]

# ---------------------------------------------------------------------------
# Build notebook cells
# ---------------------------------------------------------------------------
cells = []

# 1. Title cell
cells.append(md_cell(title_md))

# 2. One pair of (Markdown header + Code) per section
for sec in sections:
    start = sec["start"]
    end   = sec["end"]
    code  = extract_between(src, start, end).strip()

    # ── Markdown header cell ──────────────────────────────────────────
    md = (
        f'<a id="{sec["anchor"]}"></a>\n\n'
        f'## {sec["emoji"]} {sec["title"]}\n\n'
        f'{sec["desc"]}'
    )
    cells.append(md_cell(md))

    # ── Code cell ─────────────────────────────────────────────────────
    if code:
        # For the last "run" section, replace the entry-point block
        if sec["anchor"] == "run":
            code = (
                "# ── Run the full pipeline ───────────────────────────────────────────\n"
                "if __name__ == \"__main__\":\n"
                "    results = main()\n"
                "else:\n"
                "    results = main()   # always run in notebook context\n"
            )
        cells.append(code_cell(code))

# ---------------------------------------------------------------------------
# Assemble the notebook JSON
# ---------------------------------------------------------------------------
notebook = {
    "nbformat"      : 4,
    "nbformat_minor": 5,
    "metadata"      : {
        "kernelspec": {
            "display_name": "Python 3",
            "language"    : "python",
            "name"        : "python3",
        },
        "language_info": {
            "name"   : "python",
            "version": "3.10.0",
        },
        "kaggle": {
            "accelerator"     : "gpu",
            "dataSources"     : [
                {
                    "sourceType"     : "datasetVersion",
                    "sourceId"       : 3101,
                    "datasetId"      : 3101,
                    "datasetDataPath": "/kaggle/input/nih-chest-xrays-data",
                }
            ],
            "dockerImageVersionId": 30747,
            "isInternetEnabled"   : True,
            "language"            : "python",
            "sourceType"          : "notebook",
        },
    },
    "cells": cells,
}

NB_OUT.write_text(json.dumps(notebook, indent=1, ensure_ascii=False), encoding="utf-8")
print(f"Notebook written: {NB_OUT}")
print(f"Total cells    : {len(cells)}")
print(f"  Markdown cells : {sum(1 for c in cells if c['cell_type']=='markdown')}")
print(f"  Code     cells : {sum(1 for c in cells if c['cell_type']=='code')}")
print(f"File size      : {NB_OUT.stat().st_size / 1024:.1f} KB")
