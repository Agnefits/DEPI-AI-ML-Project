from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from api_security import get_api_key
# from model_loader import ai_manager

app = FastAPI(title="ClinicAI Pro API", version="2.1")

# حماية إضافية: تحديد من يمكنه التحدث مع الـ API (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # في الإنتاج على Azure، ضع الدومين الخاص بك فقط
    allow_credentials=True,
    allow_methods=["POST"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Welcome to ClinicAI Secure API. Please use /predict endpoint with a valid API Key."}

@app.post("/predict")
async def predict_xray(
    model_name: str = Form("clinicai_v2"), # السماح باختيار الموديل
    file: UploadFile = File(...),
    client_data: dict = Depends(get_api_key) # خط الدفاع: التأكد من الـ API Key
):
    # 1. فحص هل العميل يمتلك صلاحية لاستخدام هذا الموديل؟
    if model_name not in client_data["allowed_models"]:
        raise HTTPException(
            status_code=403, 
            detail=f"Your subscription plan '{client_data['plan']}' does not have access to model '{model_name}'."
        )
    
    # 2. فحص نوع الملف (Security check to prevent malicious files)
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")
    
    try:
        # قراءة الصورة من الريكويست
        image_bytes = await file.read()
        
        # 3. إرسال الصورة للموديل
        # result = ai_manager.predict_from_bytes(image_bytes)
        
        # بيانات وهمية للتوضيح (يتم استبدالها بالسطر السابق)
        result = {"status": "Success", "detected_labels": ["Cardiomegaly"], "client": client_data["user"]}
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")