from fastapi import APIRouter
from app.api.v1.endpoints import (
    vendas, financeiro, produtos, relatorios, clientes, servicos, categorias
)

api_router = APIRouter()

api_router.include_router(vendas.router, prefix="/vendas", tags=["Vendas & PDV"])
api_router.include_router(financeiro.router, prefix="/financeiro", tags=["Financeiro Híbrido (PF vs PJ)"])
api_router.include_router(produtos.router, prefix="/produtos", tags=["Produtos & Estoque"])
api_router.include_router(servicos.router, prefix="/servicos", tags=["Serviços & Procedimentos"])
api_router.include_router(categorias.router, prefix="/categorias", tags=["Categorias"])
api_router.include_router(relatorios.router, prefix="/relatorios", tags=["Relatórios & DRE"])
api_router.include_router(clientes.router, prefix="/clientes", tags=["Clientes & Anamnese"])
