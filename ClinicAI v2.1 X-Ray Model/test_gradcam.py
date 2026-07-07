import torch
from pathlib import Path
from clinicai import (
    CFG,
    DEVICE,
    ChestXrayModel,
    GradCAMVisualiser,
    GRADCAM_AVAILABLE,
)

def main():
    print("\n" + "=" * 60)
    print("  ClinicAI v2.1 — GradCAM++ Visualization Tool")
    print("=" * 60 + "\n")

    if not GRADCAM_AVAILABLE:
        print("Error: PyTorch GradCAM library is not installed.")
        print("Please install grad-cam using: pip install grad-cam")
        return

    # 1. Initialize model and load trained weights
    model = ChestXrayModel(CFG).to(DEVICE)
    
    # Priority: Local checkpoint first, then fallback Kaggle checkpoint
    checkpoint_path = CFG.CHECKPOINT_DIR / "best_model.pth"
    kaggle_ckpt = Path("/kaggle/input/notebooks/agnefits/clinicai-v2-0/checkpoints/best_model.pth")

    if checkpoint_path.exists():
        ckpt = torch.load(checkpoint_path, map_location=DEVICE, weights_only=False)
        model.load_state_dict(ckpt["ema"] if "ema" in ckpt else ckpt["model"])
        print(f"Successfully loaded model weights from: {checkpoint_path}")
    elif kaggle_ckpt.exists():
        ckpt = torch.load(kaggle_ckpt, map_location=DEVICE, weights_only=False)
        model.load_state_dict(ckpt["ema"] if "ema" in ckpt else ckpt["model"])
        print(f"Successfully loaded pre-trained Kaggle weights from: {kaggle_ckpt}")
    else:
        print(f"Warning: Checkpoint not found. Visualizations will be generated using random model weights.")

    model.eval()
    cam_vis = GradCAMVisualiser(model, CFG)

    # 2. Automatically locate the test image
    print("Searching for the test image...")
    image_filename = "00000001_000.png"
    
    # Check CFG.IMAGE_DIR first, then fall back to /kaggle/input search
    local_img_path = CFG.IMAGE_DIR / image_filename
    test_image_path = None

    if local_img_path.exists():
        test_image_path = local_img_path
        print(f"Found image at configuration path: {test_image_path}")
    else:
        # Search parent folders recursively
        found_images = list(Path("/kaggle/input").rglob(image_filename))
        if found_images:
            test_image_path = found_images[0]
            print(f"Found image in input directory: {test_image_path}")
        else:
            print(f"Could not find specific image '{image_filename}'. Looking for any PNG X-ray image...")
            any_images = list(Path("/kaggle/input").rglob("*.png"))
            if any_images:
                test_image_path = any_images[0]
                print(f"Testing with fallback image: {test_image_path}")
            else:
                print("Error: No PNG images found in '/kaggle/input'. Please supply a valid image.")

    # 3. Generate visual heatmap overlay
    if test_image_path:
        print("Generating heatmaps for 14 pathology classes. Please wait...")
        cam_vis.visualise(test_image_path, class_indices=list(range(CFG.NUM_CLASSES)))
        print("Finished generating explainability heatmaps!")

if __name__ == "__main__":
    main()
