import torch
from .config import Config, DEVICE

def apply_performance_opts(model: torch.nn.Module, cfg: Config) -> torch.nn.Module:
    """
    Applies hardware-level performance optimizations for modern GPUs:
    1. Channels-Last Memory Format: speeds up NVIDIA convolution kernels.
    2. PyTorch Graph Compilation: fuses math operations for speedups.
    3. cuDNN benchmarking auto-tuner.
    """
    if cfg.CHANNELS_LAST and DEVICE.type == "cuda":
        model = model.to(memory_format=torch.channels_last)
        print("channels_last memory format enabled")

    if cfg.COMPILE and hasattr(torch, "compile") and DEVICE.type == "cuda":
        # Compile model using torch.compile (introduced in PyTorch 2.0)
        model = torch.compile(model, mode="reduce-overhead")
        print("torch.compile() applied")

    torch.backends.cudnn.benchmark = cfg.CUDNN_BENCHMARK
    if cfg.CUDNN_BENCHMARK:
        print("cudnn.benchmark = True")

    return model
