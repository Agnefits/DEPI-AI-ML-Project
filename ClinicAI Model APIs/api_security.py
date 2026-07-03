from fastapi import Security, HTTPException, status
from fastapi.security.api_key import APIKeyHeader
from typing import Optional

# اسم الـ Header اللي العميل هيبعت فيه المفتاح
API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

# قاعدة بيانات مصغرة للمشتركين (في المستقبل هتربطها بـ Database حقيقية زي PostgreSQL/SQL Server)
# كل مفتاح مربوط بصلاحيات معينة (مثلاً يقدر يستخدم موديل v1 أو v2)
VALID_API_KEYS = {
    "sk_test_1234567890abcdef": {"user": "client_a", "plan": "premium", "allowed_models": ["clinicai_v2"]},
    "sk_test_0987654321fedcba": {"user": "client_b", "plan": "basic", "allowed_models": ["clinicai_v1"]}
}

async def get_api_key(api_key_header: str = Security(api_key_header)):
    if not api_key_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API Key is missing. Please provide it in the 'X-API-Key' header.",
        )
    
    user_data = VALID_API_KEYS.get(api_key_header)
    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid API Key. You are not authorized.",
        )
    
    return user_data # بنرجع بيانات المستخدم عشان نستخدمها في الـ API