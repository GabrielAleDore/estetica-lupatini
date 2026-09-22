from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.api import api_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    description="""
    ## Estética Lupatini - API Backend
    Sistema Integrado de Gestão Clínica, Estoque e Fluxo Financeiro Híbrido (PF vs. PJ).
    - **PDV Transacional**: Baixa atômica de estoque de produtos e insumos de procedimentos.
    - **Financeiro Híbrido**: Projeção de faturas de cartão de crédito e segregação estrita PF vs PJ.
    - **Controle Técnico**: Consumo detalhado de ampolas, seringas e descartáveis por procedimento estético.
    - **Relatórios**: DRE Gerencial mensal automatizado.
    """
)

# Configuração de CORS para suportar clientes Flutter (Mobile, Desktop e Web em qualquer porta do Chrome)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://.*",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registra as rotas tanto com /api/v1 quanto diretamente na raiz para evitar problemas de barra relativa no Dio
app.include_router(api_router, prefix=settings.API_V1_STR)
app.include_router(api_router)


@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["Infra"])
async def health_check():
    import time
    from sqlalchemy import text
    from app.core.database import engine
    from fastapi.responses import JSONResponse

    start = time.perf_counter()
    try:
        async with engine.connect() as conn:
            res = await conn.execute(text("SELECT 1"))
            val = res.scalar()
        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        return {
            "status": "healthy",
            "service": settings.PROJECT_NAME,
            "version": "1.0.0",
            "environment": settings.ENVIRONMENT,
            "database": {
                "status": "connected" if val == 1 else "error",
                "latency_ms": latency_ms
            }
        }
    except Exception as e:
        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": settings.PROJECT_NAME,
                "version": "1.0.0",
                "environment": settings.ENVIRONMENT,
                "database": {
                    "status": "disconnected",
                    "latency_ms": latency_ms,
                    "error": str(e)
                }
            }
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
