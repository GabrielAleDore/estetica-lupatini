-- ==============================================================================
-- Migration: 20260923000006_contas_bancarias.sql
-- Módulo de Cadastro e Gestão de Contas Bancárias (PJ vs. PF)
-- ==============================================================================

-- 1. TABELA DE CONTAS BANCÁRIAS
CREATE TABLE IF NOT EXISTS public.contas_bancarias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_conta VARCHAR(100) NOT NULL,
    banco_nome VARCHAR(80) NOT NULL,
    agencia VARCHAR(20),
    numero_conta VARCHAR(30),
    tipo_conta VARCHAR(30) NOT NULL DEFAULT 'CORRENTE' CHECK (tipo_conta IN ('CORRENTE', 'POUPANCA', 'INVESTIMENTO')),
    escopo VARCHAR(10) NOT NULL DEFAULT 'PJ' CHECK (escopo IN ('PJ', 'PF')),
    chave_pix VARCHAR(150),
    saldo_inicial NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    saldo_atual NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    cor_identificadora VARCHAR(20) DEFAULT '#8D5B4C',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_contas_bancarias_escopo ON public.contas_bancarias(escopo);
CREATE INDEX IF NOT EXISTS idx_contas_bancarias_ativo ON public.contas_bancarias(ativo);

-- 2. TRIGGER PARA ATUALIZAÇÃO AUTOMÁTICA DE updated_at
CREATE OR REPLACE FUNCTION trigger_atualizar_updated_at_contas_bancarias()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_contas_bancarias_updated_at ON public.contas_bancarias;
CREATE TRIGGER trg_contas_bancarias_updated_at
    BEFORE UPDATE ON public.contas_bancarias
    FOR EACH ROW
    EXECUTE FUNCTION trigger_atualizar_updated_at_contas_bancarias();

-- 3. POLÍTICAS DE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.contas_bancarias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acesso total contas_bancarias" ON public.contas_bancarias;
CREATE POLICY "Acesso total contas_bancarias" ON public.contas_bancarias
    FOR ALL TO public, anon, authenticated
    USING (true)
    WITH CHECK (true);

GRANT ALL ON TABLE public.contas_bancarias TO anon, authenticated, service_role;

-- 4. REALTIME HABILITADO
ALTER TABLE public.contas_bancarias REPLICA IDENTITY FULL;
DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.contas_bancarias;
EXCEPTION
    WHEN duplicate_object THEN null;
    WHEN others THEN null;
END $$;

-- 5. CARGA INICIAL DE DEMONSTRAÇÃO (SEED) SE A TABELA ESTIVER VAZIA
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.contas_bancarias LIMIT 1) THEN
        INSERT INTO public.contas_bancarias (nome_conta, banco_nome, agencia, numero_conta, tipo_conta, escopo, chave_pix, saldo_inicial, saldo_atual, cor_identificadora, ativo)
        VALUES
            ('Nubank PJ Clínica', 'Nubank', '0001', '1234567-8', 'CORRENTE', 'PJ', 'contato@esteticalupatini.com.br', 5000.00, 5000.00, '#820AD1', true),
            ('Itaú PJ Operacional', 'Itaú Unibanco', '4050', '98765-4', 'CORRENTE', 'PJ', '12.345.678/0001-90', 8500.00, 8500.00, '#EC7000', true),
            ('Inter PF Pessoal Sócia', 'Banco Inter', '0001', '554433-2', 'CORRENTE', 'PF', 'mariana.lupatini@email.com', 2500.00, 2500.00, '#FF7A00', true);
    END IF;
END $$;

-- 6. RECARREGAMENTO DO CACHE DO POSTGREST
NOTIFY pgrst, 'reload schema';
