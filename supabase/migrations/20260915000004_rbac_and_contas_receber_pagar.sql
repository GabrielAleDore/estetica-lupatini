-- ==============================================================================
-- Migration: 20260915000004_rbac_and_contas_receber_pagar.sql
-- RBAC, Vendas a Prazo (Fiado), Contas a Pagar e Atualização do Dashboard
-- ==============================================================================

-- 1. CAMPOS ADICIONAIS NA TABELA VENDAS (Vendas a Prazo / Fiado)
ALTER TABLE vendas ADD COLUMN IF NOT EXISTS status_pagamento VARCHAR(20) NOT NULL DEFAULT 'EFETIVADO';
ALTER TABLE vendas ADD COLUMN IF NOT EXISTS data_prevista_pagamento DATE;
CREATE INDEX IF NOT EXISTS idx_vendas_status_pagamento ON vendas(status_pagamento);

-- 2. CAMPOS ADICIONAIS NA TABELA TRANSACOES_FINANCEIRAS (Contas a Pagar / Receber)
ALTER TABLE transacoes_financeiras ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'PAGO';
ALTER TABLE transacoes_financeiras ADD COLUMN IF NOT EXISTS data_vencimento DATE DEFAULT CURRENT_DATE;
ALTER TABLE transacoes_financeiras ADD COLUMN IF NOT EXISTS data_pagamento DATE;
ALTER TABLE transacoes_financeiras ADD COLUMN IF NOT EXISTS tipo_recorrencia VARCHAR(20) NOT NULL DEFAULT 'AVULSA';
CREATE INDEX IF NOT EXISTS idx_transacoes_status ON transacoes_financeiras(status);
CREATE INDEX IF NOT EXISTS idx_transacoes_vencimento ON transacoes_financeiras(data_vencimento);

-- 3. TABELA DE PERFIS DE USUÁRIOS (RBAC)
CREATE TABLE IF NOT EXISTS perfis_usuarios (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL DEFAULT 'ATENDIMENTO' CHECK (role IN ('ADMIN', 'RECEPCAO', 'ATENDIMENTO')),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS para perfis_usuarios
ALTER TABLE perfis_usuarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso total perfis_usuarios" ON perfis_usuarios;
CREATE POLICY "Acesso total perfis_usuarios" ON perfis_usuarios FOR ALL TO public, anon, authenticated USING (true) WITH CHECK (true);
GRANT ALL ON TABLE perfis_usuarios TO anon, authenticated, service_role;

-- Trigger para sincronizar auth.users com perfis_usuarios
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.perfis_usuarios (id, nome, email, role, ativo)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nome', split_part(NEW.email, '@', 1)),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'role', 'ATENDIMENTO'),
        COALESCE((NEW.raw_user_meta_data->>'ativo')::boolean, true)
    )
    ON CONFLICT (id) DO UPDATE
    SET nome = EXCLUDED.nome,
        email = EXCLUDED.email,
        role = EXCLUDED.role,
        ativo = EXCLUDED.ativo,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 4. PROCEDURE: ADMIN CRIAR USUÁRIO
CREATE OR REPLACE FUNCTION admin_criar_usuario(
    p_nome TEXT,
    p_email TEXT,
    p_password TEXT,
    p_role TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := gen_random_uuid();
    v_encrypted_pw TEXT;
    v_email_clean TEXT := lower(trim(p_email));
BEGIN
    IF v_email_clean IS NULL OR v_email_clean = '' THEN
        RAISE EXCEPTION 'E-mail é obrigatório.';
    END IF;
    IF p_password IS NULL OR length(p_password) < 6 THEN
        RAISE EXCEPTION 'A senha deve ter pelo menos 6 caracteres.';
    END IF;
    IF p_role NOT IN ('ADMIN', 'RECEPCAO', 'ATENDIMENTO') THEN
        RAISE EXCEPTION 'Perfil de acesso inválido. Use ADMIN, RECEPCAO ou ATENDIMENTO.';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email_clean) THEN
        RAISE EXCEPTION 'Já existe um usuário cadastrado com o e-mail "%".', v_email_clean;
    END IF;

    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        confirmation_token,
        recovery_token,
        email_change_token_new,
        email_change,
        email_change_token_current,
        phone_change,
        phone_change_token,
        reauthentication_token,
        is_super_admin,
        is_sso_user,
        is_anonymous,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        'authenticated',
        'authenticated',
        v_email_clean,
        v_encrypted_pw,
        NOW(),
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        false,
        false,
        false,
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object('nome', p_nome, 'role', p_role, 'ativo', true),
        NOW(),
        NOW()
    );

    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        v_user_id,
        jsonb_build_object('sub', v_user_id::text, 'email', v_email_clean, 'email_verified', true),
        'email',
        v_user_id::text,
        NOW(),
        NOW(),
        NOW()
    );

    INSERT INTO public.perfis_usuarios (id, nome, email, role, ativo)
    VALUES (v_user_id, p_nome, v_email_clean, p_role, true)
    ON CONFLICT (id) DO UPDATE
    SET nome = EXCLUDED.nome,
        role = EXCLUDED.role,
        ativo = EXCLUDED.ativo,
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', v_email_clean,
        'nome', p_nome,
        'role', p_role
    );
END;
$$;


-- 5. ATUALIZAÇÃO DA PROCEDURE ATÔMICA REALIZAR_VENDA (com suporte a PENDENTE / A PRAZO)
CREATE OR REPLACE FUNCTION realizar_venda(p_venda jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venda_id UUID := gen_random_uuid();
    v_cliente_id UUID;
    v_forma_pagamento forma_pagamento_tipo;
    v_desconto NUMERIC(12, 2) := 0.00;
    v_observacoes TEXT;
    v_cartao_id UUID;
    v_parcelas INT := 1;
    v_itens jsonb;
    v_item jsonb;
    v_status_pagamento VARCHAR(20) := 'EFETIVADO';
    v_data_prevista DATE;
    
    v_tipo_item VARCHAR(20);
    v_prod_id UUID;
    v_serv_id UUID;
    v_qtd NUMERIC(12, 3);
    v_preco_unit NUMERIC(12, 2);
    v_subtotal NUMERIC(12, 2);
    v_valor_bruto NUMERIC(12, 2) := 0.00;
    v_valor_liquido NUMERIC(12, 2) := 0.00;
    
    v_prod_record RECORD;
    v_serv_record RECORD;
    v_insumo_record RECORD;
    v_qtd_insumo_total NUMERIC(12, 3);
    v_transacao_id UUID;
BEGIN
    IF p_venda IS NULL THEN
        RAISE EXCEPTION 'Dados da venda não fornecidos.';
    END IF;

    IF p_venda->>'cliente_id' IS NOT NULL AND p_venda->>'cliente_id' <> '' THEN
        v_cliente_id := (p_venda->>'cliente_id')::UUID;
    END IF;

    v_forma_pagamento := COALESCE((p_venda->>'forma_pagamento')::forma_pagamento_tipo, 'PIX'::forma_pagamento_tipo);
    v_desconto := COALESCE((p_venda->>'desconto')::NUMERIC, 0.00);
    v_observacoes := p_venda->>'observacoes';
    
    IF p_venda->>'status_pagamento' IS NOT NULL THEN
        v_status_pagamento := UPPER(p_venda->>'status_pagamento');
    END IF;

    IF p_venda->>'data_prevista_pagamento' IS NOT NULL AND p_venda->>'data_prevista_pagamento' <> '' THEN
        v_data_prevista := (p_venda->>'data_prevista_pagamento')::DATE;
    END IF;
    
    IF p_venda->>'cartao_id' IS NOT NULL AND p_venda->>'cartao_id' <> '' THEN
        v_cartao_id := (p_venda->>'cartao_id')::UUID;
    END IF;
    v_parcelas := COALESCE((p_venda->>'parcelas')::INT, 1);
    
    v_itens := p_venda->'itens';
    IF v_itens IS NULL OR jsonb_array_length(v_itens) = 0 THEN
        RAISE EXCEPTION 'A venda deve conter pelo menos um item.';
    END IF;

    -- 1. Cria a venda inicial
    INSERT INTO vendas (
        id, cliente_id, data_hora, valor_bruto, desconto, valor_liquido, 
        forma_pagamento, status, status_pagamento, data_prevista_pagamento, observacoes
    ) VALUES (
        v_venda_id, v_cliente_id, NOW(), 0.00, v_desconto, 0.00, 
        v_forma_pagamento, 'CONCLUIDA', v_status_pagamento, v_data_prevista, v_observacoes
    );

    -- 2. Processa itens com baixa atômica de estoque
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_itens)
    LOOP
        v_tipo_item := UPPER(v_item->>'tipo_item');
        v_qtd := COALESCE((v_item->>'quantidade')::NUMERIC, 1.000);
        
        IF v_tipo_item = 'PRODUTO' THEN
            v_prod_id := (v_item->>'produto_id')::UUID;
            
            SELECT * INTO v_prod_record 
            FROM produtos 
            WHERE id = v_prod_id 
            FOR UPDATE;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Produto com ID % não encontrado.', v_prod_id;
            END IF;
            
            IF NOT v_prod_record.permite_venda THEN
                RAISE EXCEPTION 'O item "%" é insumo técnico de uso interno e não permite venda direta.', v_prod_record.nome;
            END IF;
            
            IF v_prod_record.quantidade_estoque < v_qtd THEN
                RAISE EXCEPTION 'Estoque insuficiente para o produto "%". Saldo atual: %, Solicitado: %', 
                    v_prod_record.nome, v_prod_record.quantidade_estoque, v_qtd;
            END IF;
            
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, v_prod_record.preco_venda);
            v_subtotal := ROUND(v_preco_unit * v_qtd, 2);
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            UPDATE produtos 
            SET quantidade_estoque = quantidade_estoque - v_qtd 
            WHERE id = v_prod_id;
            
            INSERT INTO movimentacoes_estoque (produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, venda_id, motivo)
            VALUES (
                v_prod_id, 
                'SAIDA', 
                v_qtd, 
                v_prod_record.quantidade_estoque, 
                v_prod_record.quantidade_estoque - v_qtd, 
                v_venda_id, 
                'Venda PDV - ' || v_prod_record.nome
            );
            
            INSERT INTO itens_venda (venda_id, tipo_item, produto_id, quantidade, preco_unitario, subtotal)
            VALUES (v_venda_id, 'PRODUTO', v_prod_id, v_qtd, v_preco_unit, v_subtotal);
            
        ELSIF v_tipo_item = 'SERVICO' THEN
            v_serv_id := (v_item->>'servico_id')::UUID;
            
            SELECT * INTO v_serv_record 
            FROM servicos 
            WHERE id = v_serv_id;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Serviço com ID % não encontrado.', v_serv_id;
            END IF;
            
            IF NOT v_serv_record.ativo THEN
                RAISE EXCEPTION 'O serviço "%" está desativado.', v_serv_record.nome;
            END IF;
            
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, v_serv_record.preco);
            v_subtotal := ROUND(v_preco_unit * v_qtd, 2);
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            INSERT INTO itens_venda (venda_id, tipo_item, servico_id, quantidade, preco_unitario, subtotal)
            VALUES (v_venda_id, 'SERVICO', v_serv_id, v_qtd, v_preco_unit, v_subtotal);
            
            -- Baixa técnica dos insumos consumidos pelo procedimento
            FOR v_insumo_record IN 
                SELECT si.produto_id, si.quantidade_consumo, p.nome, p.quantidade_estoque, p.unidade_medida
                FROM servico_insumos si
                JOIN produtos p ON p.id = si.produto_id
                WHERE si.servico_id = v_serv_id
                FOR UPDATE OF p
            LOOP
                v_qtd_insumo_total := v_insumo_record.quantidade_consumo * v_qtd;
                
                IF v_insumo_record.quantidade_estoque < v_qtd_insumo_total THEN
                    RAISE EXCEPTION 'Estoque insuficiente do insumo técnico "%" para o procedimento "%". Saldo atual: % %, Necessário: % %',
                        v_insumo_record.nome, v_serv_record.nome, v_insumo_record.quantidade_estoque, v_insumo_record.unidade_medida,
                        v_qtd_insumo_total, v_insumo_record.unidade_medida;
                END IF;
                
                UPDATE produtos 
                SET quantidade_estoque = quantidade_estoque - v_qtd_insumo_total 
                WHERE id = v_insumo_record.produto_id;
                
                INSERT INTO movimentacoes_estoque (produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, venda_id, motivo)
                VALUES (
                    v_insumo_record.produto_id,
                    'CONSUMO',
                    v_qtd_insumo_total,
                    v_insumo_record.quantidade_estoque,
                    v_insumo_record.quantidade_estoque - v_qtd_insumo_total,
                    v_venda_id,
                    'Consumo técnico: ' || v_serv_record.nome
                );
            END LOOP;
        ELSE
            RAISE EXCEPTION 'Tipo de item desconhecido: %', v_tipo_item;
        END IF;
    END LOOP;

    v_valor_liquido := GREATEST(v_valor_bruto - v_desconto, 0.00);

    UPDATE vendas 
    SET valor_bruto = v_valor_bruto,
        valor_liquido = v_valor_liquido
    WHERE id = v_venda_id;

    -- 3. Registro na Transação Financeira (com status PAGO ou PENDENTE)
    v_transacao_id := gen_random_uuid();
    INSERT INTO transacoes_financeiras (
        id, descricao, escopo, tipo, cartao_id, venda_id, valor_total, 
        parcelas, data_competencia, data_vencimento, data_pagamento, status
    ) VALUES (
        v_transacao_id,
        CASE WHEN v_status_pagamento = 'PENDENTE' 
             THEN 'Venda a Receber (Fiado) #' || UPPER(SUBSTRING(v_venda_id::TEXT FROM 1 FOR 8))
             ELSE 'Receita Venda PDV #' || UPPER(SUBSTRING(v_venda_id::TEXT FROM 1 FOR 8))
        END,
        'PJ',
        'ENTRADA',
        v_cartao_id,
        v_venda_id,
        v_valor_liquido,
        v_parcelas,
        CURRENT_DATE,
        COALESCE(v_data_prevista, CURRENT_DATE),
        CASE WHEN v_status_pagamento = 'EFETIVADO' THEN CURRENT_DATE ELSE NULL END,
        CASE WHEN v_status_pagamento = 'EFETIVADO' THEN 'PAGO' ELSE 'PENDENTE' END
    );

    RETURN jsonb_build_object(
        'success', true,
        'venda_id', v_venda_id,
        'valor_bruto', v_valor_bruto,
        'desconto', v_desconto,
        'valor_liquido', v_valor_liquido,
        'forma_pagamento', v_forma_pagamento,
        'status_pagamento', v_status_pagamento,
        'data_prevista_pagamento', v_data_prevista,
        'transacao_id', v_transacao_id,
        'status', 'CONCLUIDA'
    );
END;
$$;


-- 6. PROCEDURE: DAR BAIXA / RECEBER VENDA PENDENTE
CREATE OR REPLACE FUNCTION dar_baixa_venda_pendente(
    p_venda_id UUID,
    p_forma_pagamento TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venda RECORD;
    v_forma_enum forma_pagamento_tipo;
BEGIN
    v_forma_enum := COALESCE(p_forma_pagamento::forma_pagamento_tipo, 'PIX'::forma_pagamento_tipo);

    SELECT * INTO v_venda 
    FROM vendas 
    WHERE id = p_venda_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venda com ID % não encontrada.', p_venda_id;
    END IF;

    IF v_venda.status_pagamento = 'EFETIVADO' THEN
        RAISE EXCEPTION 'Esta venda já está liquidada/efetivada.';
    END IF;

    -- Atualiza venda
    UPDATE vendas
    SET status_pagamento = 'EFETIVADO',
        forma_pagamento = v_forma_enum
    WHERE id = p_venda_id;

    -- Atualiza transação financeira vinculada
    UPDATE transacoes_financeiras
    SET status = 'PAGO',
        data_pagamento = CURRENT_DATE,
        descricao = 'Receita Venda Liquidada #' || UPPER(SUBSTRING(p_venda_id::TEXT FROM 1 FOR 8))
    WHERE venda_id = p_venda_id;

    RETURN jsonb_build_object(
        'success', true,
        'venda_id', p_venda_id,
        'status_pagamento', 'EFETIVADO',
        'forma_pagamento', v_forma_enum,
        'data_liquidacao', CURRENT_DATE
    );
END;
$$;


-- 7. ATUALIZAÇÃO DA PROCEDURE DO DASHBOARD COM NOVOS CARDS (VENDAS EFETIVADAS VS A RECEBER)
CREATE OR REPLACE FUNCTION obter_dashboard_resumo()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_faturamento_pj NUMERIC(12, 2) := 0.00;
    v_despesas_pf NUMERIC(12, 2) := 0.00;
    v_despesas_pj NUMERIC(12, 2) := 0.00;
    v_balanco_liquido NUMERIC(12, 2) := 0.00;
    v_vendas_efetivadas NUMERIC(12, 2) := 0.00;
    v_vendas_a_receber NUMERIC(12, 2) := 0.00;
    v_total_vendas_mes INT := 0;
    v_alertas jsonb := '[]'::jsonb;
    v_transacoes jsonb := '[]'::jsonb;
    v_primeiro_dia_mes DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_ultimo_dia_mes DATE := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    -- 1. Vendas Efetivadas vs Vendas a Receber (Fiado) no mês corrente
    SELECT 
        COALESCE(SUM(CASE WHEN status_pagamento = 'EFETIVADO' THEN valor_liquido ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN status_pagamento = 'PENDENTE' THEN valor_liquido ELSE 0 END), 0.00),
        COUNT(*)
    INTO 
        v_vendas_efetivadas,
        v_vendas_a_receber,
        v_total_vendas_mes
    FROM vendas
    WHERE status = 'CONCLUIDA'
      AND data_hora::DATE BETWEEN v_primeiro_dia_mes AND v_ultimo_dia_mes;

    -- 2. Métricas de Caixa Real (Apenas transações efetivamente pagas)
    SELECT 
        COALESCE(SUM(CASE WHEN escopo = 'PJ' AND tipo = 'ENTRADA' AND status = 'PAGO' THEN valor_total ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN escopo = 'PF' AND tipo = 'SAIDA' AND status = 'PAGO' THEN valor_total ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN escopo = 'PJ' AND tipo = 'SAIDA' AND status = 'PAGO' THEN valor_total ELSE 0 END), 0.00)
    INTO 
        v_faturamento_pj,
        v_despesas_pf,
        v_despesas_pj
    FROM transacoes_financeiras
    WHERE data_competencia BETWEEN v_primeiro_dia_mes AND v_ultimo_dia_mes;

    -- O balanço líquido considera o caixa real da clínica
    v_balanco_liquido := v_faturamento_pj - v_despesas_pj;

    -- 3. Alertas de estoque crítico
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'nome', p.nome,
            'codigo_barras', p.codigo_barras,
            'quantidade_estoque', p.quantidade_estoque,
            'estoque_minimo', p.estoque_minimo,
            'unidade_medida', p.unidade_medida,
            'deficit', GREATEST(p.estoque_minimo - p.quantidade_estoque, 0.000),
            'status_alerta', CASE WHEN p.quantidade_estoque <= 0 THEN 'CRITICO' ELSE 'BAIXO' END
        )
    ), '[]'::jsonb)
    INTO v_alertas
    FROM produtos p
    WHERE p.quantidade_estoque <= p.estoque_minimo;

    -- 4. Últimas 10 transações
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'descricao', t.descricao,
            'escopo', t.escopo,
            'tipo', t.tipo,
            'valor_total', t.valor_total,
            'status', t.status,
            'data_vencimento', t.data_vencimento,
            'data_pagamento', t.data_pagamento,
            'data_competencia', t.data_competencia,
            'created_at', t.created_at
        ) ORDER BY t.created_at DESC
    ), '[]'::jsonb)
    INTO v_transacoes
    FROM (
        SELECT * FROM transacoes_financeiras
        ORDER BY created_at DESC
        LIMIT 10
    ) t;

    RETURN jsonb_build_object(
        'faturamento_pj', v_faturamento_pj,
        'despesas_pf', v_despesas_pf,
        'despesas_pj', v_despesas_pj,
        'balanco_liquido', v_balanco_liquido,
        'vendas_efetivadas', v_vendas_efetivadas,
        'vendas_a_receber', v_vendas_a_receber,
        'total_vendas_mes', v_total_vendas_mes,
        'alertas_estoque', v_alertas,
        'total_alertas_estoque', jsonb_array_length(v_alertas),
        'transacoes_recentes', v_transacoes
    );
END;
$$;

-- 8. REPLICA IDENTITY FULL E PUBLICAÇÃO REALTIME
ALTER TABLE perfis_usuarios REPLICA IDENTITY FULL;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE perfis_usuarios;
EXCEPTION
    WHEN duplicate_object THEN null;
    WHEN others THEN null;
END $$;
