from decimal import Decimal
from typing import Dict, Optional, List
from pydantic import BaseModel, Field
from app.schemas.produto import AlertaEstoqueResponse


class DREResumidoResponse(BaseModel):
    mes_referencia: str  # 'YYYY-MM'
    
    # 1. Receitas Clínicas (PJ)
    receita_bruta: Decimal = Field(default=Decimal("0.00"), description="Total faturado em vendas e serviços")
    descontos_concedidos: Decimal = Field(default=Decimal("0.00"), description="Descontos totais")
    receita_liquida: Decimal = Field(default=Decimal("0.00"), description="Receita bruta menos descontos")
    
    # 2. Custos Variáveis / Técnicos (PJ)
    custo_produtos_vendidos: Decimal = Field(default=Decimal("0.00"), description="Custo de aquisição de produtos de revenda (Home care)")
    custo_insumos_procedimentos: Decimal = Field(default=Decimal("0.00"), description="Custo técnico dos insumos consumidos nos serviços")
    custo_total_variavel: Decimal = Field(default=Decimal("0.00"))
    
    # 3. Lucro Bruto Operacional (PJ)
    lucro_bruto_pj: Decimal = Field(default=Decimal("0.00"))
    
    # 4. Despesas Fixas e Operacionais (PJ)
    despesas_operacionais_pj: Decimal = Field(default=Decimal("0.00"), description="Aluguel, luz, salários, software, etc.")
    
    # 5. Resultado Líquido da Clínica (PJ)
    resultado_operacional_pj: Decimal = Field(default=Decimal("0.00"), description="Lucro Bruto PJ menos Despesas Operacionais PJ")
    margem_operacional_percentual: float = Field(default=0.0)
    
    # 6. Segregação Rigorosa: Gastos Pessoais dos Sócios (PF)
    gastos_pessoais_pf: Decimal = Field(default=Decimal("0.00"), description="Despesas pessoais e retiradas em cartões/contas PF")
    
    # 7. Saldo Final Consolidado
    saldo_caixa_final: Decimal = Field(default=Decimal("0.00"), description="Resultado Operacional PJ menos Retiradas PF")


class DashboardResumoResponse(BaseModel):
    mes_referencia: str
    dre: DREResumidoResponse
    total_itens_alerta_estoque: int
    alertas_estoque: List[AlertaEstoqueResponse] = Field(default_factory=list)
    # Resumo Agregado Rápido
    total_faturado_pj: Decimal
    total_despesas_pf: Decimal
    balanco_liquido: Decimal
