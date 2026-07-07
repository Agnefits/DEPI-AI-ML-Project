import torch
import cv2
import numpy as np
from pathlib import Path
from typing import Dict

# استدعاء الأساسيات من الملف اللي لسه عاملينه
from Model_Core import Config, ChestXrayModel, get_inference_transforms

class APIInferenceManager:
    def __init__(self, model_path: str):
        self.cfg = Config()
        self.device = torch.device("cpu") # تشغيل إجباري على CPU لتناسب إمكانيات الجهاز
        
        # 1. تعريف الموديل
        self.model = ChestXrayModel(self.cfg).to(self.device)
        self.model.eval()
        
        # 2. تحميل الأوزان بأمان
        if Path(model_path).exists():
            try:
                globals_to_add = [np.dtype]
                if hasattr(np, "dtypes"):
                    for name in dir(np.dtypes):
                        attr = getattr(np.dtypes, name)
                        if isinstance(attr, type):
                            globals_to_add.append(attr)
                if hasattr(np, "_core") and hasattr(np._core, "multiarray"):
                    globals_to_add.append(np._core.multiarray.scalar)
                elif hasattr(np, "core") and hasattr(np.core, "multiarray"):
                    globals_to_add.append(np.core.multiarray.scalar)
                torch.serialization.add_safe_globals(globals_to_add)
            except Exception:
                pass
            # weights_only=True لحماية الـ API من ثغرات الـ Pickle 
            ckpt = torch.load(model_path, map_location=self.device, weights_only=True)
            # استخراج أوزان الـ EMA[cite: 1]
            self.model.load_state_dict(ckpt.get("ema", ckpt.get("model", ckpt))) 
        else:
            raise FileNotFoundError(f"Model weights not found at: {model_path}")
            
        # 3. إعداد الـ Thresholds (تقدر تعدلها بالأرقام المحسنة من Youden's J لاحقاً)[cite: 1]
        self.thresholds = np.full(self.cfg.NUM_CLASSES, 0.5)
        
        # 4. تجهيز الـ Transforms الخاص بـ Albumentations[cite: 1]
        self.transform = get_inference_transforms(self.cfg)

    def predict_from_bytes(self, image_bytes: bytes) -> Dict:
        # تحويل الصورة القادمة من الـ API إلى مصفوفة قابلة للقراءة
        np_arr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_GRAYSCALE)
        
        if img is None:
            raise ValueError("Invalid image format or corrupted file.")
            
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
        
        # تطبيق المعالجة وتحويلها لـ Tensor
        tensor = self.transform(image=img)["image"].unsqueeze(0).to(self.device)
        
        # المعالجة واستخراج التوقعات
        with torch.no_grad():
            logits = self.model(tensor)
            probs = torch.sigmoid(logits).numpy().squeeze()
            
        predictions = (probs >= self.thresholds).astype(int)
        detected = [
            {"label": cls, "probability": round(float(prob), 4)}
            for cls, pred, prob in zip(self.cfg.CLASSES, predictions, probs)
            if pred
        ]
        
        return {
            "probabilities": dict(zip(self.cfg.CLASSES, probs.tolist())),
            "predictions": dict(zip(self.cfg.CLASSES, predictions.tolist())),
            "detected_labels": detected if detected else [{"label": "No Finding", "probability": 0.0}]
        }

# تهيئة الـ Manager (تأكد إن مسار الموديل صحيح)
ai_manager = APIInferenceManager("checkpoint/best_model.pth")