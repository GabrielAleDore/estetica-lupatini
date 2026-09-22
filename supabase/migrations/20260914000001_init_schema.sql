-- ==============================================================================
-- Migration: 20260914000001_init_schema.sql
-- Sistema: Estética Lupatini (Gestão Clínica, Estoque e Fluxo Financeiro Híbrido)
-- Banco de Dados: PostgreSQL 15+ (Supabase)
-- ==============================================================================

-- Habilita extensão UUID caso não esteja habilitada
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. TIPOS ENUMERADOS
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE categoria_tipo AS ENUM ('SERVICO', 'PRODUTO', 'DESPESA', 'RECEITA');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE escopo_tipo AS ENUM ('PF', 'PJ');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE transacao_tipo AS ENUM ('ENTRADA', 'SAIDA');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE movimentacao_tipo AS ENUM ('ENTRADA', 'SAIDA', 'CONSUMO');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE status_venda AS ENUM ('PENDENTE', 'CONCLUIDA', 'CANCELADA');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE status_parcela AS ENUM ('PENDENTE', 'PAGA', 'ATRASADA', 'CANCELADA');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE item_tipo AS ENUM ('PRODUTO', 'SERVICO');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE forma_pagamento_tipo AS ENUM ('DINHEIRO', 'PIX', 'CARTAO_CREDITO', 'CARTAO_DEBITO', 'BOLETO', 'TRANSFERENCIA');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TABELAS: CADASTROS BÁSICOS E CLÍNICA
-- ------------------------------------------------------------------------------

-- Tabela de Clientes com Anamnese Dermatológica em JSONB
CREATE TABLE IF NOT EXISTS clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    cpf VARCHAR(14) UNIQUE,
    data_nascimento DATE,
    anamnese JSONB DEFAULT '{
        "tipo_pele": null,
        "alergias": [],
        "medicamentos_uso": [],
        "historico_cirurgico": null,
        "queixa_principal": null,
        "observacoes_tecnicas": null
    }'::jsonb,
    status VARCHAR(20) NOT NULL DEFAULT 'ATIVO',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de Categorias
CREATE TABLE IF NOT EXISTS categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL,
    tipo categoria_tipo NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de Produtos (Insumos e Produtos para Venda)
CREATE TABLE IF NOT EXISTS produtos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria_id UUID REFERENCES categorias(id) ON DELETE SET NULL,
    nome VARCHAR(255) NOT NULL,
    codigo_barras VARCHAR(50) UNIQUE,
    preco_custo NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    preco_venda NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    quantidade_estoque NUMERIC(12, 3) NOT NULL DEFAULT 0.000,
    estoque_minimo NUMERIC(12, 3) NOT NULL DEFAULT 5.000,
    permite_venda BOOLEAN NOT NULL DEFAULT TRUE,
    unidade_medida VARCHAR(20) NOT NULL DEFAULT 'UN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de Serviços Clínicos
CREATE TABLE IF NOT EXISTS servicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria_id UUID REFERENCES categorias(id) ON DELETE SET NULL,
    nome VARCHAR(255) NOT NULL,
    duracao_minutos INT NOT NULL DEFAULT 60,
    preco NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de Insumos por Serviço (Mapeamento do Gasto Técnico por Atendimento)
CREATE TABLE IF NOT EXISTS servico_insumos (
    servico_id UUID NOT NULL REFERENCES servicos(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES produtos(id) ON DELETE RESTRICT,
    quantidade_consumo NUMERIC(12, 3) NOT NULL CHECK (quantidade_consumo > 0),
    PRIMARY KEY (servico_id, produto_id)
);

-- ------------------------------------------------------------------------------
-- 3. TABELAS: VENDAS, PDV E MOVIMENTAÇÃO DE ESTOQUE
-- ------------------------------------------------------------------------------

-- Tabela de Vendas
CREATE TABLE IF NOT EXISTS vendas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID REFERENCES clientes(id) ON DELETE SET NULL,
    data_hora TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valor_bruto NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (valor_bruto >= 0),
    desconto NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (desconto >= 0),
    valor_liquido NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (valor_liquido >= 0),
    forma_pagamento forma_pagamento_tipo NOT NULL DEFAULT 'PIX',
    status status_venda NOT NULL DEFAULT 'CONCLUIDA',
    observacoes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de Itens da Venda (Produtos e Serviços)
CREATE TABLE IF NOT EXISTS itens_venda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venda_id UUID NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
    tipo_item item_tipo NOT NULL,
    produto_id UUID REFERENCES produtos(id) ON DELETE RESTRICT,
    servico_id UUID REFERENCES servicos(id) ON DELETE RESTRICT,
    quantidade NUMERIC(12, 3) NOT NULL DEFAULT 1.000 CHECK (quantidade > 0),
    preco_unitario NUMERIC(12, 2) NOT NULL CHECK (preco_unitario >= 0),
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT chk_item_referencia CHECK (
        (tipo_item = 'PRODUTO' AND produto_id IS NOT NULL AND servico_id IS NULL) OR
        (tipo_item = 'SERVICO' AND servico_id IS NOT NULL AND produto_id IS NULL)
    )
);

-- Tabela de Movimentações de Estoque (Auditoria e Rastreabilidade)
CREATE TABLE IF NOT EXISTS movimentacoes_estoque (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produto_id UUID NOT NULL REFERENCES produtos(id) ON DELETE CASCADE,
    tipo movimentacao_tipo NOT NULL,
    quantidade NUMERIC(12, 3) NOT NULL CHECK (quantidade > 0),
    saldo_anterior NUMERIC(12, 3) NOT NULL,
    saldo_posterior NUMERIC(12, 3) NOT NULL,
    venda_id UUID REFERENCES vendas(id) ON DELETE SET NULL,
    motivo VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 4. TABELAS: MÓDULO FINANCEIRO HÍBRIDO (PF vs. PJ)
-- ------------------------------------------------------------------------------

-- Tabela de Contas e Cartões (Segregação Rigorosa PF / PJ)
CREATE TABLE IF NOT EXISTS contas_cartoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL,
    escopo escopo_tipo NOT NULL, -- 'PF' (Pessoal) ou 'PJ' (Clínica)
    dia_fechamento INT NOT NULL CHECK (dia_fechamento BETWEEN 1 AND 31),
    dia_vencimento INT NOT NULL CHECK (dia_vencimento BETWEEN 1 AND 31),
    limite NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela Mestre de Transações Financeiras
CREATE TABLE IF NOT EXISTS transacoes_financeiras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    descricao VARCHAR(255) NOT NULL,
    escopo escopo_tipo NOT NULL, -- 'PF' ou 'PJ'
    tipo transacao_tipo NOT NULL, -- 'ENTRADA' ou 'SAIDA'
    categoria_id UUID REFERENCES categorias(id) ON DELETE SET NULL,
    cartao_id UUID REFERENCES contas_cartoes(id) ON DELETE SET NULL,
    venda_id UUID REFERENCES vendas(id) ON DELETE SET NULL,
    valor_total NUMERIC(12, 2) NOT NULL CHECK (valor_total > 0),
    parcelas INT NOT NULL DEFAULT 1 CHECK (parcelas >= 1),
    data_competencia DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de Parcelas Financeiras (Controle de Faturas e Vencimentos Futuros)
CREATE TABLE IF NOT EXISTS parcelas_financeiras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transacao_id UUID NOT NULL REFERENCES transacoes_financeiras(id) ON DELETE CASCADE,
    cartao_id UUID REFERENCES contas_cartoes(id) ON DELETE SET NULL,
    numero_parcela INT NOT NULL CHECK (numero_parcela >= 1),
    valor_parcela NUMERIC(12, 2) NOT NULL CHECK (valor_parcela > 0),
    data_vencimento DATE NOT NULL,
    status status_parcela NOT NULL DEFAULT 'PENDENTE',
    mes_fatura_referencia VARCHAR(7) NOT NULL, -- Formato 'YYYY-MM'
    data_pagamento DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 5. ÍNDICES DE PERFORMANCE E INTEGRIDADE
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_clientes_cpf ON clientes(cpf);
CREATE INDEX IF NOT EXISTS idx_clientes_nome ON clientes(nome);
CREATE INDEX IF NOT EXISTS idx_produtos_codigo_barras ON produtos(codigo_barras);
CREATE INDEX IF NOT EXISTS idx_produtos_alerta_estoque ON produtos(quantidade_estoque, estoque_minimo);
CREATE INDEX IF NOT EXISTS idx_vendas_data_hora ON vendas(data_hora);
CREATE INDEX IF NOT EXISTS idx_itens_venda_venda ON itens_venda(venda_id);
CREATE INDEX IF NOT EXISTS idx_movimentacoes_produto ON movimentacoes_estoque(produto_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transacoes_escopo_competencia ON transacoes_financeiras(escopo, data_competencia);
CREATE INDEX IF NOT EXISTS idx_parcelas_fatura ON parcelas_financeiras(cartao_id, mes_fatura_referencia);
CREATE INDEX IF NOT EXISTS idx_parcelas_status_vencimento ON parcelas_financeiras(status, data_vencimento);

-- ------------------------------------------------------------------------------
-- 6. TRIGGER DE ATUALIZAÇÃO AUTOMÁTICA DE TIMESTAMP (updated_at)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_clientes_updated_at ON clientes;
CREATE TRIGGER trg_clientes_updated_at
    BEFORE UPDATE ON clientes
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_produtos_updated_at ON produtos;
CREATE TRIGGER trg_produtos_updated_at
    BEFORE UPDATE ON produtos
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_servicos_updated_at ON servicos;
CREATE TRIGGER trg_servicos_updated_at
    BEFORE UPDATE ON servicos
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();
