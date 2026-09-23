-- ==============================================================================
-- Migration: 20260923000007_receitas_avulsas_e_saldo_trigger.sql
-- Módulo de Receitas e Entradas Avulsas + Atualização Automática de Saldo Bancário
-- ==============================================================================

-- 1. GARANTIR COLUNAS EM transacoes_financeiras
ALTER TABLE public.transacoes_financeiras ADD COLUMN IF NOT EXISTS valor NUMERIC(12, 2);
ALTER TABLE public.transacoes_financeiras ADD COLUMN IF NOT EXISTS data_transacao DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.transacoes_financeiras ADD COLUMN IF NOT EXISTS categoria_nome VARCHAR(80);
ALTER TABLE public.transacoes_financeiras ADD COLUMN IF NOT EXISTS observacoes TEXT;
ALTER TABLE public.transacoes_financeiras ADD COLUMN IF NOT EXISTS origem VARCHAR(30) DEFAULT 'MANUAL';

-- Sincronizar valor e valor_total se existirem linhas anteriores
UPDATE public.transacoes_financeiras SET valor = valor_total WHERE valor IS NULL AND valor_total IS NOT NULL;
UPDATE public.transacoes_financeiras SET valor_total = valor WHERE valor_total IS NULL AND valor IS NOT NULL;

-- 2. GARANTIR A COLUNA conta_bancaria_id COM O TIPO COMPATÍVEL
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'transacoes_financeiras' 
          AND column_name = 'conta_bancaria_id'
    ) THEN
        -- Verifica o tipo da chave primária de contas_bancarias
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = 'contas_bancarias' 
              AND column_name = 'id' 
              AND data_type = 'uuid'
        ) THEN
            ALTER TABLE public.transacoes_financeiras 
            ADD COLUMN conta_bancaria_id UUID REFERENCES public.contas_bancarias(id) ON DELETE SET NULL;
        ELSIF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = 'contas_bancarias' 
              AND column_name = 'id' 
              AND (data_type LIKE '%int%' OR data_type = 'bigint')
        ) THEN
            ALTER TABLE public.transacoes_financeiras 
            ADD COLUMN conta_bancaria_id BIGINT REFERENCES public.contas_bancarias(id) ON DELETE SET NULL;
        ELSE
            ALTER TABLE public.transacoes_financeiras 
            ADD COLUMN conta_bancaria_id TEXT;
        END IF;
    END IF;
END $$;

-- 3. PERMITIR TIPOS 'RECEITA' E 'DESPESA' FLEXÍVEIS
DO $$
BEGIN
    -- Se o tipo de coluna for enum transacao_tipo, converte para VARCHAR para flexibilidade total
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'transacoes_financeiras' 
          AND column_name = 'tipo' 
          AND udt_name = 'transacao_tipo'
    ) THEN
        ALTER TABLE public.transacoes_financeiras ALTER COLUMN tipo TYPE VARCHAR(30) USING tipo::text;
    END IF;
EXCEPTION
    WHEN others THEN null;
END $$;

-- 4. ÍNDICES DE PERFORMANCE PARA BUSCA DE RECEITAS
CREATE INDEX IF NOT EXISTS idx_transacoes_tipo_status ON public.transacoes_financeiras(tipo, status);
CREATE INDEX IF NOT EXISTS idx_transacoes_conta_bancaria ON public.transacoes_financeiras(conta_bancaria_id);
CREATE INDEX IF NOT EXISTS idx_transacoes_data_transacao ON public.transacoes_financeiras(data_transacao);

-- 5. TRIGGER SQL: ATUALIZAÇÃO AUTOMÁTICA DE SALDO EM CONTAS BANCÁRIAS
CREATE OR REPLACE FUNCTION public.fn_atualizar_saldo_conta_bancaria()
RETURNS TRIGGER AS $$
DECLARE
    v_valor NUMERIC(12, 2);
BEGIN
    v_valor := COALESCE(NEW.valor, NEW.valor_total, 0.00);

    -- Ao inserir uma nova transação efetivada vinculada a uma conta bancária
    IF TG_OP = 'INSERT' THEN
        IF NEW.conta_bancaria_id IS NOT NULL AND NEW.status IN ('EFETIVADO', 'PAGO') THEN
            IF NEW.tipo IN ('RECEITA', 'ENTRADA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual + v_valor,
                    updated_at = NOW()
                WHERE id::text = NEW.conta_bancaria_id::text;
            ELSIF NEW.tipo IN ('DESPESA', 'SAIDA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual - v_valor,
                    updated_at = NOW()
                WHERE id::text = NEW.conta_bancaria_id::text;
            END IF;
        END IF;
    END IF;

    -- Ao atualizar transação (por exemplo: mudar de PENDENTE para EFETIVADO)
    IF TG_OP = 'UPDATE' THEN
        IF NEW.conta_bancaria_id IS NOT NULL THEN
            -- Caso tenha mudado de não-pago para pago/efetivado
            IF (OLD.status NOT IN ('EFETIVADO', 'PAGO') AND NEW.status IN ('EFETIVADO', 'PAGO')) THEN
                IF NEW.tipo IN ('RECEITA', 'ENTRADA') THEN
                    UPDATE public.contas_bancarias
                    SET saldo_atual = saldo_atual + v_valor,
                        updated_at = NOW()
                    WHERE id::text = NEW.conta_bancaria_id::text;
                ELSIF NEW.tipo IN ('DESPESA', 'SAIDA') THEN
                    UPDATE public.contas_bancarias
                    SET saldo_atual = saldo_atual - v_valor,
                        updated_at = NOW()
                    WHERE id::text = NEW.conta_bancaria_id::text;
                END IF;
            -- Caso tenha sido cancelada ou estornada
            ELSIF (OLD.status IN ('EFETIVADO', 'PAGO') AND NEW.status IN ('CANCELADA', 'ESTORNADA')) THEN
                IF NEW.tipo IN ('RECEITA', 'ENTRADA') THEN
                    UPDATE public.contas_bancarias
                    SET saldo_atual = saldo_atual - v_valor,
                        updated_at = NOW()
                    WHERE id::text = NEW.conta_bancaria_id::text;
                ELSIF NEW.tipo IN ('DESPESA', 'SAIDA') THEN
                    UPDATE public.contas_bancarias
                    SET saldo_atual = saldo_atual + v_valor,
                        updated_at = NOW()
                    WHERE id::text = NEW.conta_bancaria_id::text;
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_atualizar_saldo_conta_bancaria ON public.transacoes_financeiras;
CREATE TRIGGER trg_atualizar_saldo_conta_bancaria
    AFTER INSERT OR UPDATE ON public.transacoes_financeiras
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_atualizar_saldo_conta_bancaria();

-- 6. RECARREGAR O CACHE DO SCHEMA POSTGREST
NOTIFY pgrst, 'reload schema';
