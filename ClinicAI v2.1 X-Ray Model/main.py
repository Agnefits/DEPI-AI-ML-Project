import gc
import time
import pandas as pd
import numpy as np
import torch
from torch.cuda.amp import autocast

from clinicai import (
    CFG,
    DEVICE,
    set_seed,
    DataAnalyser,
    DataSplitter,
    ChestXray14Dataset,
    build_transforms,
    build_dataloader,
    ChestXrayModel,
    build_loss,
    build_optimiser,
    build_scheduler,
    Evaluator,
    ThresholdOptimiser,
    GradCAMVisualiser,
    GRADCAM_AVAILABLE,
    ErrorAnalyser,
    InferencePipeline,
    Reporter,
    apply_performance_opts,
)

def load_metadata(cfg) -> pd.DataFrame:
    """Loads and preprocesses the NIH ChestX-ray14 metadata CSV."""
    df = pd.read_csv(cfg.META_CSV)
    # Extract numerical Patient ID from image index (e.g., "00000001_000.png" -> 1)
    df["Patient ID"] = df["Image Index"].apply(lambda x: int(x.split("_")[0]))
    print(f"Loaded {len(df):,} rows from {cfg.META_CSV.name}")
    return df

def main():
    """End-to-end training and evaluation pipeline."""
    print("\n" + "=" * 60)
    print("  ClinicAI v2.1 — NIH ChestX-ray14 Pipeline")
    print("=" * 60 + "\n")

    # Set deterministic random seed
    set_seed(CFG.SEED)

    # 1. Load metadata
    df_raw = load_metadata(CFG)

    # 2. Exploratory Data Analysis (EDA)
    analyser = DataAnalyser(df_raw, CFG)
    df = analyser.run()  # Generates EDA plots and parses finding labels

    # 3. Patient-Wise Split (Ensures no patient overlap between train/val)
    splitter = DataSplitter(df, CFG, val_ratio=0.15)
    train_df, val_df = splitter.split()

    # 4. Augmentation Pipelines
    train_tfm = build_transforms("train", CFG)
    val_tfm   = build_transforms("val",   CFG)

    # 5. Datasets & Dataloaders
    train_ds = ChestXray14Dataset(train_df, CFG.IMAGE_DIR, train_tfm, CFG)
    val_ds   = ChestXray14Dataset(val_df,   CFG.IMAGE_DIR, val_tfm,   CFG)
    pos_weight = train_ds.get_pos_weight()

    train_loader = build_dataloader(train_ds, CFG.BATCH_SIZE, shuffle=True,  cfg=CFG)
    val_loader   = build_dataloader(val_ds,   CFG.BATCH_SIZE, shuffle=False, cfg=CFG)
    print(f"Train batches: {len(train_loader)}  |  Val batches: {len(val_loader)}")

    # 6. Model Setup & Hardware Optimization
    model = ChestXrayModel(CFG).to(DEVICE)
    model = apply_performance_opts(model, CFG)
    print(f"Total params     : {model.param_count()/1e6:.1f} M")
    print(f"Trainable params : {model.trainable_param_count()/1e6:.1f} M")

    # 7. Optimizer, Loss & Scheduler Factories
    criterion = build_loss(CFG, pos_weight)
    optimiser = build_optimiser(model, CFG)
    scheduler = build_scheduler(optimiser, CFG)
    evaluator = Evaluator(CFG)

    # 8. Training
    from clinicai import Trainer
    trainer = Trainer(
        model=model, train_loader=train_loader, val_loader=val_loader,
        criterion=criterion, optimiser=optimiser, scheduler=scheduler,
        cfg=CFG, evaluator=evaluator,
    )
    t0 = time.time()
    history = trainer.fit()
    t_train = time.time() - t0

    # 9. Load Best EMA Weights for Validation
    best_ckpt = CFG.CHECKPOINT_DIR / "best_model.pth"
    if best_ckpt.exists():
        ckpt = torch.load(best_ckpt, map_location=DEVICE, weights_only=False)
        model.load_state_dict(ckpt["ema"])
        print(f"Loaded best EMA checkpoint (epoch {ckpt['epoch']})")
    model.eval()

    # 10. Compute Full Validation Metrics
    print("\nComputing full validation metrics...")
    val_probs, val_labels = [], []
    with torch.no_grad():
        for images, labels in val_loader:
            images = images.to(DEVICE, non_blocking=True)
            with autocast(enabled=CFG.AMP):
                logits = model(images)
            val_probs.append(torch.sigmoid(logits).cpu().numpy())
            val_labels.append(labels.numpy())
    val_probs  = np.concatenate(val_probs,  axis=0)
    val_labels = np.concatenate(val_labels, axis=0)

    best_metrics = evaluator.compute(val_labels, val_probs)
    evaluator.plot_per_class_auc(best_metrics["per_class_auc"])
    evaluator.plot_roc_curves(val_labels, val_probs)
    y_pred_05 = (val_probs >= 0.5).astype(int)
    evaluator.plot_confusion_matrices(val_labels, y_pred_05)

    # 11. Threshold Optimization using Youden's J Statistic
    thresh_opt = ThresholdOptimiser(CFG)
    thresholds = thresh_opt.fit(val_labels, val_probs)
    thresh_opt.save()

    best_metrics_opt = evaluator.compute(val_labels, val_probs, thresholds)
    print(f"\n  AUC  (fixed  0.5) : {best_metrics['auc_macro']:.4f}")
    print(f"  AUC  (opt thresh) : {best_metrics_opt['auc_macro']:.4f}")
    print(f"  F1   (fixed  0.5) : {best_metrics['f1']:.4f}")
    print(f"  F1   (opt thresh) : {best_metrics_opt['f1']:.4f}")

    # 12. GradCAM Visualizations
    if GRADCAM_AVAILABLE:
        cam_vis = GradCAMVisualiser(model, CFG)
        sample  = val_df.iloc[0]["Image Index"]
        cam_vis.visualise(CFG.IMAGE_DIR / sample, class_indices=list(range(CFG.NUM_CLASSES)))

    # 13. Error Analysis Visualizations
    err_analyser = ErrorAnalyser(val_df, CFG)
    err_analyser.analyse(val_labels, val_probs, thresholds, CFG.IMAGE_DIR, n=4)

    # 14. Single Image Inference Pipeline Demonstration
    pipeline   = InferencePipeline(model, CFG, thresholds)
    sample_img = CFG.IMAGE_DIR / val_df.iloc[0]["Image Index"]
    if sample_img.exists():
        result = pipeline.predict_single(sample_img, use_tta=True)
        print("\nSample TTA Prediction:")
        for cls, prob in result["probabilities"].items():
            flag = "[X]" if result["predictions"][cls] else "   "
            print(f"  {flag} {cls:<22} : {prob:.4f}")
        print(f"  Detected: {result['detected_labels']}")

    # 15. Final Report Printing & Plotting
    reporter = Reporter(CFG)
    reporter.print_report(history, best_metrics_opt, thresholds, model, t_train)
    reporter.plot_training_curves(history)

    # Cleanup GPU VRAM
    del model, trainer
    gc.collect()
    if DEVICE.type == "cuda":
        torch.cuda.empty_cache()

    print("\nClinicAI v2.1 pipeline complete!")
    return best_metrics_opt

if __name__ == "__main__":
    main()
