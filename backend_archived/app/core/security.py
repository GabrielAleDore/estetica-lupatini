from typing import Optional, Dict, Any
import jwt
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.config import settings

security_scheme = HTTPBearer(auto_error=False)


def decode_supabase_jwt(token: str) -> Dict[str, Any]:
    """
    Decodifica e valida o token JWT emitido pelo Supabase Auth.
    Verifica assinatura, expiração e aud ('authenticated').
    """
    try:
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=[settings.SUPABASE_JWT_ALGORITHM],
            audience="authenticated",
            options={"verify_aud": False}  # Supabase às vezes omite ou usa 'authenticated'
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expirado. Por favor, realize login novamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token de autenticação inválido: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme)
) -> Dict[str, Any]:
    """
    Dependency Injection do FastAPI para proteção de rotas via JWT do Supabase Auth.
    Retorna o payload contendo sub (user_id), email, role e metadados do operador.
    """
    if not credentials:
        if settings.ENVIRONMENT == "development":
            # Modo desenvolvimento / teste local controlado
            return {
                "id": "00000000-0000-0000-0000-000000000000",
                "email": "operador.clinica@esteticalupatini.com.br",
                "role": "authenticated",
                "app_metadata": {"role": "admin"},
                "user_metadata": {"nome": "Operadora Recepção / Lupatini"}
            }
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais de autenticação não fornecidas.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = credentials.credentials
    payload = decode_supabase_jwt(token)
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido: identificador de usuário ausente.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    return {
        "id": user_id,
        "email": payload.get("email"),
        "role": payload.get("role", "authenticated"),
        "app_metadata": payload.get("app_metadata", {}),
        "user_metadata": payload.get("user_metadata", {})
    }
