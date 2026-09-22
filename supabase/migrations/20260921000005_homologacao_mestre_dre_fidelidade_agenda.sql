-- ==============================================================================
-- Migration: 20260921000005_homologacao_mestre_dre_fidelidade_agenda.sql
-- Homologação Final: Usuário Mestre, DRE Contábil, Fidelidade, Sequência & Agenda
-- ==============================================================================

-- 1. SEGURANÇA E ROLE MESTRE
ALTER TABLE public.perfis_usuarios DROP CONSTRAINT IF EXISTS perfis_usuarios_role_check;
ALTER TABLE public.perfis_usuarios ADD CONSTRAINT perfis_usuarios_role_check 
    CHECK (role IN ('MESTRE', 'ADMIN', 'RECEPCAO', 'ATENDIMENTO'));

-- Stored Procedure Atualizada para criação de usuários com suporte a MESTRE
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
    IF p_role NOT IN ('MESTRE', 'ADMIN', 'RECEPCAO', 'ATENDIMENTO') THEN
        RAISE EXCEPTION 'Perfil de acesso inválido. Use MESTRE, ADMIN, RECEPCAO ou ATENDIMENTO.';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email_clean) THEN
        RAISE EXCEPTION 'Já existe um usuário cadastrado com o e-mail "%".', v_email_clean;
    END IF;

    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        confirmation_token, recovery_token, email_change_token_new, email_change,
        email_change_token_current, phone_change, phone_change_token, reauthentication_token,
        is_super_admin, is_sso_user, is_anonymous, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at
    ) VALUES (
        v_user_id, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated',
        v_email_clean, v_encrypted_pw, NOW(), '', '', '', '', '', '', '', '',
        false, false, false, '{"provider": "email", "providers": ["email"]}'::jsonb,
        jsonb_build_object('nome', p_nome, 'role', p_role, 'ativo', true),
        NOW(), NOW()
    );

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        gen_random_uuid(), v_user_id,
        jsonb_build_object('sub', v_user_id::text, 'email', v_email_clean, 'email_verified', true),
        'email', v_user_id::text, NOW(), NOW(), NOW()
    );

    INSERT INTO public.perfis_usuarios (id, nome, email, role, ativo)
    VALUES (v_user_id, p_nome, v_email_clean, p_role, true)
    ON CONFLICT (id) DO UPDATE
    SET nome = EXCLUDED.nome, email = EXCLUDED.email, role = EXCLUDED.role, ativo = EXCLUDED.ativo, updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', v_email_clean,
        'nome', p_nome,
        'role', p_role
    );
END;
$$;

-- 2. CÓDIGOS SEQUENCIAIS EM PRODUTOS E SERVIÇOS
CREATE SEQUENCE IF NOT EXISTS produtos_codigo_seq START 1;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS codigo_sequencial BIGINT;
ALTER TABLE produtos ALTER COLUMN codigo_sequencial SET DEFAULT nextval('produtos_codigo_seq');
UPDATE produtos SET codigo_sequencial = nextval('produtos_codigo_seq') WHERE codigo_sequencial IS NULL;

CREATE SEQUENCE IF NOT EXISTS servicos_codigo_seq START 1;
ALTER TABLE servicos ADD COLUMN IF NOT EXISTS codigo_sequencial BIGINT;
ALTER TABLE servicos ALTER COLUMN codigo_sequencial SET DEFAULT nextval('servicos_codigo_seq');
UPDATE servicos SET codigo_sequencial = nextval('servicos_codigo_seq') WHERE codigo_sequencial IS NULL;

-- 3. MOTOR DE PROMOÇÕES EM PRODUTOS E SERVIÇOS
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS preco_promocional NUMERIC(10,2);
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS em_promocao BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS inicio_promocao TIMESTAMPTZ;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS fim_promocao TIMESTAMPTZ;

ALTER TABLE servicos ADD COLUMN IF NOT EXISTS preco_promocional NUMERIC(10,2);
ALTER TABLE servicos ADD COLUMN IF NOT EXISTS em_promocao BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE servicos ADD COLUMN IF NOT EXISTS inicio_promocao TIMESTAMPTZ;
ALTER TABLE servicos ADD COLUMN IF NOT EXISTS fim_promocao TIMESTAMPTZ;

-- 4. CLIENTES FIDELIZADAS / VIP
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS is_fidelizada BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS desconto_fidelidade_padrao NUMERIC(5,2) NOT NULL DEFAULT 0.00;

-- 5. DETALHAMENTO DE DESCONTOS EM VENDAS E ITENS
ALTER TABLE vendas ADD COLUMN IF NOT EXISTS valor_original NUMERIC(12,2);
ALTER TABLE vendas ADD COLUMN IF NOT EXISTS valor_desconto NUMERIC(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE vendas ADD COLUMN IF NOT EXISTS tipo_desconto VARCHAR(30) NOT NULL DEFAULT 'NENHUM';
ALTER TABLE vendas ADD COLUMN IF NOT EXISTS valor_final NUMERIC(12,2);

UPDATE vendas SET 
    valor_original = COALESCE(valor_original, valor_bruto),
    valor_desconto = COALESCE(valor_desconto, desconto),
    valor_final = COALESCE(valor_final, valor_liquido)
WHERE valor_original IS NULL;

ALTER TABLE itens_venda ADD COLUMN IF NOT EXISTS valor_original NUMERIC(12,2);
ALTER TABLE itens_venda ADD COLUMN IF NOT EXISTS valor_desconto NUMERIC(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE itens_venda ADD COLUMN IF NOT EXISTS tipo_desconto VARCHAR(30) NOT NULL DEFAULT 'NENHUM';
ALTER TABLE itens_venda ADD COLUMN IF NOT EXISTS valor_final NUMERIC(12,2);

UPDATE itens_venda SET 
    valor_original = COALESCE(valor_original, subtotal),
    valor_desconto = COALESCE(valor_desconto, 0.00),
    valor_final = COALESCE(valor_final, subtotal)
WHERE valor_original IS NULL;

-- Atualização da procedure realizar_venda para registrar descontos e tipos
CREATE OR REPLACE FUNCTION realizar_venda(p_venda jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venda_id UUID := gen_random_uuid();
    v_cliente_id UUID := NULL;
    v_forma_pagamento forma_pagamento_tipo;
    v_desconto NUMERIC(12, 2) := 0.00;
    v_tipo_desconto VARCHAR(30) := 'NENHUM';
    v_observacoes TEXT;
    v_status_pagamento VARCHAR(20) := 'EFETIVADO';
    v_data_prevista DATE := NULL;
    v_cartao_id UUID := NULL;
    v_parcelas INT := 1;
    v_itens jsonb;
    v_item jsonb;
    
    v_tipo_item VARCHAR(20);
    v_prod_id UUID;
    v_serv_id UUID;
    v_qtd NUMERIC(12, 3);
    v_preco_unit NUMERIC(12, 2);
    v_preco_orig NUMERIC(12, 2);
    v_subtotal NUMERIC(12, 2);
    v_item_desconto NUMERIC(12, 2);
    v_item_final NUMERIC(12, 2);
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
    v_tipo_desconto := COALESCE(p_venda->>'tipo_desconto', 'NENHUM');
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
        valor_original, valor_desconto, tipo_desconto, valor_final,
        forma_pagamento, status, status_pagamento, data_prevista_pagamento, observacoes
    ) VALUES (
        v_venda_id, v_cliente_id, NOW(), 0.00, v_desconto, 0.00,
        0.00, v_desconto, v_tipo_desconto, 0.00,
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
            
            v_preco_orig := COALESCE((v_item->>'preco_original')::NUMERIC, v_prod_record.preco_venda);
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, 
                                     CASE WHEN v_prod_record.em_promocao AND v_prod_record.preco_promocional IS NOT NULL 
                                          THEN v_prod_record.preco_promocional 
                                          ELSE v_prod_record.preco_venda END);
            v_subtotal := ROUND(v_preco_orig * v_qtd, 2);
            v_item_final := ROUND(v_preco_unit * v_qtd, 2);
            v_item_desconto := GREATEST(v_subtotal - v_item_final, 0.00);
            
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
            
            INSERT INTO itens_venda (
                venda_id, tipo_item, produto_id, quantidade, preco_unitario, subtotal,
                valor_original, valor_desconto, tipo_desconto, valor_final
            ) VALUES (
                v_venda_id, 'PRODUTO', v_prod_id, v_qtd, v_preco_unit, v_subtotal,
                v_subtotal, v_item_desconto, COALESCE(v_item->>'tipo_desconto', 'NENHUM'), v_item_final
            );
            
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
            
            v_preco_orig := COALESCE((v_item->>'preco_original')::NUMERIC, v_serv_record.preco);
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, 
                                     CASE WHEN v_serv_record.em_promocao AND v_serv_record.preco_promocional IS NOT NULL 
                                          THEN v_serv_record.preco_promocional 
                                          ELSE v_serv_record.preco END);
            v_subtotal := ROUND(v_preco_orig * v_qtd, 2);
            v_item_final := ROUND(v_preco_unit * v_qtd, 2);
            v_item_desconto := GREATEST(v_subtotal - v_item_final, 0.00);
            
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            INSERT INTO itens_venda (
                venda_id, tipo_item, servico_id, quantidade, preco_unitario, subtotal,
                valor_original, valor_desconto, tipo_desconto, valor_final
            ) VALUES (
                v_venda_id, 'SERVICO', v_serv_id, v_qtd, v_preco_unit, v_subtotal,
                v_subtotal, v_item_desconto, COALESCE(v_item->>'tipo_desconto', 'NENHUM'), v_item_final
            );
            
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
        valor_liquido = v_valor_liquido,
        valor_original = v_valor_bruto,
        valor_desconto = v_desconto,
        tipo_desconto = v_tipo_desconto,
        valor_final = v_valor_liquido
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
        'valor_original', v_valor_bruto,
        'valor_desconto', v_desconto,
        'tipo_desconto', v_tipo_desconto,
        'valor_final', v_valor_liquido,
        'forma_pagamento', v_forma_pagamento,
        'status_pagamento', v_status_pagamento,
        'data_prevista_pagamento', v_data_prevista,
        'transacao_id', v_transacao_id,
        'status', 'CONCLUIDA'
    );
END;
$$;

-- 6. TABELA DE AGENDAMENTOS E GESTÃO DE HORÁRIOS
CREATE TABLE IF NOT EXISTS agendamentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    servico_id UUID NOT NULL REFERENCES servicos(id) ON DELETE RESTRICT,
    data_hora_inicio TIMESTAMPTZ NOT NULL,
    data_hora_fim TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'AGENDADO' CHECK (status IN ('AGENDADO', 'CONFIRMADO', 'CANCELADO', 'CONCLUIDO')),
    observacoes TEXT,
    lembrete_enviado BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agendamentos_cliente ON agendamentos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_agendamentos_inicio ON agendamentos(data_hora_inicio);
CREATE INDEX IF NOT EXISTS idx_agendamentos_status ON agendamentos(status);

ALTER TABLE agendamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso total agendamentos" ON agendamentos;
CREATE POLICY "Acesso total agendamentos" ON agendamentos FOR ALL TO public, anon, authenticated USING (true) WITH CHECK (true);
GRANT ALL ON TABLE agendamentos TO anon, authenticated, service_role;

ALTER TABLE agendamentos REPLICA IDENTITY FULL;
DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE agendamentos;
EXCEPTION
    WHEN duplicate_object THEN null;
    WHEN others THEN null;
END $$;

-- 7. STORED PROCEDURE DE DRE CONTÁBIL
CREATE OR REPLACE FUNCTION obter_relatorio_dre(
    p_mes INT,
    p_ano INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_data_inicio DATE;
    v_data_fim DATE;
    
    v_receita_bruta_servicos NUMERIC(12, 2) := 0.00;
    v_receita_bruta_produtos NUMERIC(12, 2) := 0.00;
    v_receita_bruta_total NUMERIC(12, 2) := 0.00;
    v_descontos_total NUMERIC(12, 2) := 0.00;
    v_receita_liquida NUMERIC(12, 2) := 0.00;
    v_custo_insumos NUMERIC(12, 2) := 0.00;
    v_despesas_fixas_pj NUMERIC(12, 2) := 0.00;
    v_despesas_variaveis_pj NUMERIC(12, 2) := 0.00;
    v_despesas_pj_total NUMERIC(12, 2) := 0.00;
    v_lucro_operacional NUMERIC(12, 2) := 0.00;
    v_retiradas_pf NUMERIC(12, 2) := 0.00;
    
    v_detalhe_despesas jsonb := '[]'::jsonb;
    v_detalhe_retiradas jsonb := '[]'::jsonb;
BEGIN
    v_data_inicio := make_date(p_ano, p_mes, 1);
    v_data_fim := (v_data_inicio + INTERVAL '1 month - 1 day')::DATE;

    -- 1. Receita Bruta de Serviços e Produtos
    SELECT 
        COALESCE(SUM(CASE WHEN iv.tipo_item = 'SERVICO' THEN COALESCE(iv.valor_original, iv.subtotal) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN iv.tipo_item = 'PRODUTO' THEN COALESCE(iv.valor_original, iv.subtotal) ELSE 0 END), 0.00),
        COALESCE(SUM(COALESCE(iv.valor_desconto, 0)), 0.00)
    INTO 
        v_receita_bruta_servicos,
        v_receita_bruta_produtos,
        v_descontos_total
    FROM itens_venda iv
    JOIN vendas v ON v.id = iv.venda_id
    WHERE v.status = 'CONCLUIDA'
      AND v.data_hora::DATE BETWEEN v_data_inicio AND v_data_fim;

    -- Ajusta descontos caso o total gravado na venda seja maior (desconto geral no carrinho)
    SELECT COALESCE(SUM(v.desconto), v_descontos_total)
    INTO v_descontos_total
    FROM vendas v
    WHERE v.status = 'CONCLUIDA'
      AND v.data_hora::DATE BETWEEN v_data_inicio AND v_data_fim;

    v_receita_bruta_total := v_receita_bruta_servicos + v_receita_bruta_produtos;
    v_receita_liquida := GREATEST(v_receita_bruta_total - v_descontos_total, 0.00);

    -- 2. Custo dos Insumos Consumidos (ficha técnica de serviços + custo de produtos vendidos)
    -- Custo de produtos vendidos
    SELECT COALESCE(SUM(p.preco_custo * iv.quantidade), 0.00)
    INTO v_custo_insumos
    FROM itens_venda iv
    JOIN vendas v ON v.id = iv.venda_id
    JOIN produtos p ON p.id = iv.produto_id
    WHERE v.status = 'CONCLUIDA'
      AND iv.tipo_item = 'PRODUTO'
      AND v.data_hora::DATE BETWEEN v_data_inicio AND v_data_fim;

    -- Soma com insumos técnicos dos serviços executados
    v_custo_insumos := v_custo_insumos + COALESCE((
        SELECT SUM(p.preco_custo * (si.quantidade_consumo * iv.quantidade))
        FROM itens_venda iv
        JOIN vendas v ON v.id = iv.venda_id
        JOIN servico_insumos si ON si.servico_id = iv.servico_id
        JOIN produtos p ON p.id = si.produto_id
        WHERE v.status = 'CONCLUIDA'
          AND iv.tipo_item = 'SERVICO'
          AND v.data_hora::DATE BETWEEN v_data_inicio AND v_data_fim
    ), 0.00);

    -- 3. Despesas Fixas vs Variáveis PJ (Pagas no período)
    SELECT 
        COALESCE(SUM(CASE WHEN tipo_recorrencia = 'FIXA_MENSAL' THEN valor_total ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN tipo_recorrencia <> 'FIXA_MENSAL' THEN valor_total ELSE 0 END), 0.00),
        COALESCE(SUM(valor_total), 0.00)
    INTO 
        v_despesas_fixas_pj,
        v_despesas_variaveis_pj,
        v_despesas_pj_total
    FROM transacoes_financeiras
    WHERE escopo = 'PJ'
      AND tipo = 'SAIDA'
      AND status = 'PAGO'
      AND data_competencia BETWEEN v_data_inicio AND v_data_fim;

    -- 4. Lucro Operacional Líquido
    v_lucro_operacional := v_receita_liquida - v_custo_insumos - v_despesas_pj_total;

    -- 5. Retiradas / Despesas Pessoais PF (Informativo)
    SELECT COALESCE(SUM(valor_total), 0.00)
    INTO v_retiradas_pf
    FROM transacoes_financeiras
    WHERE escopo = 'PF'
      AND tipo = 'SAIDA'
      AND status = 'PAGO'
      AND data_competencia BETWEEN v_data_inicio AND v_data_fim;

    -- 6. Detalhamento de Despesas PJ por Categoria
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'descricao', t.descricao,
            'valor', t.valor_total,
            'tipo_recorrencia', t.tipo_recorrencia,
            'data_pagamento', t.data_pagamento
        ) ORDER BY t.data_pagamento DESC
    ), '[]'::jsonb)
    INTO v_detalhe_despesas
    FROM transacoes_financeiras t
    WHERE t.escopo = 'PJ'
      AND t.tipo = 'SAIDA'
      AND t.status = 'PAGO'
      AND t.data_competencia BETWEEN v_data_inicio AND v_data_fim;

    -- 7. Detalhamento de Retiradas PF
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'descricao', t.descricao,
            'valor', t.valor_total,
            'data_pagamento', t.data_pagamento
        ) ORDER BY t.data_pagamento DESC
    ), '[]'::jsonb)
    INTO v_detalhe_retiradas
    FROM transacoes_financeiras t
    WHERE t.escopo = 'PF'
      AND t.tipo = 'SAIDA'
      AND t.status = 'PAGO'
      AND t.data_competencia BETWEEN v_data_inicio AND v_data_fim;

    RETURN jsonb_build_object(
        'competencia_mes', p_mes,
        'competencia_ano', p_ano,
        'data_inicio', v_data_inicio,
        'data_fim', v_data_fim,
        'receita_bruta_servicos', v_receita_bruta_servicos,
        'receita_bruta_produtos', v_receita_bruta_produtos,
        'receita_bruta_total', v_receita_bruta_total,
        'descontos_total', v_descontos_total,
        'receita_liquida', v_receita_liquida,
        'custo_insumos', v_custo_insumos,
        'despesas_fixas_pj', v_despesas_fixas_pj,
        'despesas_variaveis_pj', v_despesas_variaveis_pj,
        'despesas_pj_total', v_despesas_pj_total,
        'lucro_operacional_liquido', v_lucro_operacional,
        'retiradas_pf', v_retiradas_pf,
        'detalhe_despesas', v_detalhe_despesas,
        'detalhe_retiradas', v_detalhe_retiradas
    );
END;
$$;
