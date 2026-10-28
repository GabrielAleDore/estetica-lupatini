-- ==============================================================================
-- MIGRATION 20261026000009: CARTEIRA DE PACOTES, CONTROLE DE SESSÕES & HISTÓRICO
-- ==============================================================================
-- 1. Criação das tabelas clientes_pacotes e pacotes_sessoes_historico
-- 2. RLS e Publicação Realtime
-- 3. Stored Procedure para Contratação Direta de Pacote (contratar_pacote_cliente)
-- 4. Stored Procedure para Baixa Atômica de Sessão com Consumo de Insumo (dar_baixa_sessao_pacote)
-- 5. Stored Procedure para Obtenção de Saldo e Sessões por Cliente (obter_pacotes_cliente)
-- 6. Suporte na Stored Procedure realizar_venda para geração automática de pacote
-- ==============================================================================

-- 1. TABELA DE PACOTES DE CLIENTES (Tratamentos parcelados/múltiplas sessões)
CREATE TABLE IF NOT EXISTS public.clientes_pacotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
    servico_id UUID NOT NULL REFERENCES public.servicos(id) ON DELETE RESTRICT,
    venda_origem_id UUID REFERENCES public.vendas(id) ON DELETE SET NULL,
    titulo_personalizado VARCHAR(255),
    quantidade_total INTEGER NOT NULL CHECK (quantidade_total > 0),
    quantidade_consumida INTEGER NOT NULL DEFAULT 0 CHECK (quantidade_consumida >= 0),
    quantidade_restante INTEGER GENERATED ALWAYS AS (quantidade_total - quantidade_consumida) STORED,
    valor_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (valor_total >= 0),
    valor_por_sessao NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (valor_por_sessao >= 0),
    data_aquisicao TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    data_validade DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'CONCLUIDO', 'EXPIRADO', 'CANCELADO')),
    observacoes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_clientes_pacotes_cliente ON public.clientes_pacotes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_clientes_pacotes_status ON public.clientes_pacotes(status);
CREATE INDEX IF NOT EXISTS idx_clientes_pacotes_servico ON public.clientes_pacotes(servico_id);

-- 2. TABELA DE HISTÓRICO DE SESSÕES REALIZADAS (Evolução clínica por atendimento)
CREATE TABLE IF NOT EXISTS public.pacotes_sessoes_historico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacote_id UUID NOT NULL REFERENCES public.clientes_pacotes(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
    servico_id UUID NOT NULL REFERENCES public.servicos(id) ON DELETE RESTRICT,
    profissional_id UUID REFERENCES public.perfis_usuarios(id) ON DELETE SET NULL,
    agendamento_id UUID REFERENCES public.agendamentos(id) ON DELETE SET NULL,
    numero_sessao INTEGER NOT NULL CHECK (numero_sessao > 0),
    parametros_utilizados JSONB DEFAULT '{}'::jsonb,
    observacoes_evolucao TEXT,
    fotos_sessao_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
    data_realizacao TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_sessoes_pacote ON public.pacotes_sessoes_historico(pacote_id);
CREATE INDEX IF NOT EXISTS idx_sessoes_cliente ON public.pacotes_sessoes_historico(cliente_id);
CREATE INDEX IF NOT EXISTS idx_sessoes_data ON public.pacotes_sessoes_historico(data_realizacao);

-- 3. HABILITAÇÃO DE ROW LEVEL SECURITY (RLS) & REALTIME
ALTER TABLE public.clientes_pacotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacotes_sessoes_historico ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acesso total clientes_pacotes" ON public.clientes_pacotes;
CREATE POLICY "Acesso total clientes_pacotes" ON public.clientes_pacotes FOR ALL TO public, anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Acesso total sessoes_historico" ON public.pacotes_sessoes_historico;
CREATE POLICY "Acesso total sessoes_historico" ON public.pacotes_sessoes_historico FOR ALL TO public, anon, authenticated USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.clientes_pacotes TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.pacotes_sessoes_historico TO anon, authenticated, service_role;

ALTER TABLE public.clientes_pacotes REPLICA IDENTITY FULL;
ALTER TABLE public.pacotes_sessoes_historico REPLICA IDENTITY FULL;

DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.clientes_pacotes;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.pacotes_sessoes_historico;
EXCEPTION
    WHEN duplicate_object THEN null;
    WHEN others THEN null;
END $$;

-- 4. STORED PROCEDURE: CONTRATAR PACOTE PARA CLIENTE
CREATE OR REPLACE FUNCTION public.contratar_pacote_cliente(
    p_cliente_id UUID,
    p_servico_id UUID,
    p_quantidade_total INT,
    p_valor_total NUMERIC DEFAULT 0.00,
    p_venda_origem_id UUID DEFAULT NULL,
    p_titulo_personalizado TEXT DEFAULT NULL,
    p_validade_meses INT DEFAULT NULL,
    p_observacoes TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pacote_id UUID;
    v_servico_nome TEXT;
    v_valor_sessao NUMERIC(12, 2);
    v_data_validade DATE := NULL;
BEGIN
    IF p_quantidade_total IS NULL OR p_quantidade_total <= 0 THEN
        RAISE EXCEPTION 'A quantidade total de sessões deve ser maior que zero.';
    END IF;

    SELECT nome INTO v_servico_nome FROM public.servicos WHERE id = p_servico_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Serviço com ID % não encontrado.', p_servico_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.clientes WHERE id = p_cliente_id) THEN
        RAISE EXCEPTION 'Cliente com ID % não encontrado.', p_cliente_id;
    END IF;

    v_valor_sessao := ROUND(COALESCE(p_valor_total, 0.00) / p_quantidade_total, 2);

    IF p_validade_meses IS NOT NULL AND p_validade_meses > 0 THEN
        v_data_validade := (CURRENT_DATE + (p_validade_meses || ' months')::INTERVAL)::DATE;
    END IF;

    v_pacote_id := gen_random_uuid();

    INSERT INTO public.clientes_pacotes (
        id, cliente_id, servico_id, venda_origem_id, titulo_personalizado,
        quantidade_total, quantidade_consumida, valor_total, valor_por_sessao,
        data_aquisicao, data_validade, status, observacoes
    ) VALUES (
        v_pacote_id, p_cliente_id, p_servico_id, p_venda_origem_id,
        COALESCE(p_titulo_personalizado, 'Pacote ' || p_quantidade_total || 'x ' || v_servico_nome),
        p_quantidade_total, 0, COALESCE(p_valor_total, 0.00), v_valor_sessao,
        NOW(), v_data_validade, 'ATIVO', p_observacoes
    );

    RETURN jsonb_build_object(
        'success', true,
        'pacote_id', v_pacote_id,
        'cliente_id', p_cliente_id,
        'servico_id', p_servico_id,
        'servico_nome', v_servico_nome,
        'quantidade_total', p_quantidade_total,
        'quantidade_restante', p_quantidade_total,
        'valor_total', COALESCE(p_valor_total, 0.00),
        'valor_por_sessao', v_valor_sessao,
        'status', 'ATIVO'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.contratar_pacote_cliente(UUID, UUID, INT, NUMERIC, UUID, TEXT, INT, TEXT) TO anon, authenticated, service_role;

-- 5. STORED PROCEDURE: DAR BAIXA EM SESSÃO DE PACOTE (Com baixa técnica de insumos)
CREATE OR REPLACE FUNCTION public.dar_baixa_sessao_pacote(
    p_pacote_id UUID,
    p_profissional_id UUID DEFAULT NULL,
    p_agendamento_id UUID DEFAULT NULL,
    p_observacoes_evolucao TEXT DEFAULT NULL,
    p_parametros JSONB DEFAULT '{}'::jsonb,
    p_fotos_urls TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pacote RECORD;
    v_sessao_id UUID;
    v_numero_sessao INT;
    v_novo_status TEXT;
    v_insumo RECORD;
    v_qtd_insumo NUMERIC(12, 3);
BEGIN
    -- Trava concorrente na linha do pacote
    SELECT * INTO v_pacote
    FROM public.clientes_pacotes
    WHERE id = p_pacote_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pacote com ID % não encontrado.', p_pacote_id;
    END IF;

    IF v_pacote.status != 'ATIVO' THEN
        RAISE EXCEPTION 'Este pacote não está ativo. Status atual: %', v_pacote.status;
    END IF;

    IF v_pacote.quantidade_consumida >= v_pacote.quantidade_total THEN
        RAISE EXCEPTION 'Todas as % sessões deste pacote já foram consumidas.', v_pacote.quantidade_total;
    END IF;

    v_numero_sessao := v_pacote.quantidade_consumida + 1;
    v_novo_status := CASE WHEN v_numero_sessao >= v_pacote.quantidade_total THEN 'CONCLUIDO' ELSE 'ATIVO' END;

    -- Atualiza pacote
    UPDATE public.clientes_pacotes
    SET quantidade_consumida = v_numero_sessao,
        status = v_novo_status,
        updated_at = NOW()
    WHERE id = p_pacote_id;

    -- Registra sessão no histórico clínico
    v_sessao_id := gen_random_uuid();
    INSERT INTO public.pacotes_sessoes_historico (
        id, pacote_id, cliente_id, servico_id, profissional_id, agendamento_id,
        numero_sessao, parametros_utilizados, observacoes_evolucao, fotos_sessao_urls, data_realizacao
    ) VALUES (
        v_sessao_id, p_pacote_id, v_pacote.cliente_id, v_pacote.servico_id, p_profissional_id, p_agendamento_id,
        v_numero_sessao, COALESCE(p_parametros, '{}'::jsonb), p_observacoes_evolucao, COALESCE(p_fotos_urls, ARRAY[]::TEXT[]), NOW()
    );

    -- Se houver agendamento vinculado, atualiza status para CONCLUIDO
    IF p_agendamento_id IS NOT NULL THEN
        UPDATE public.agendamentos
        SET status = 'CONCLUIDO',
            updated_at = NOW()
        WHERE id = p_agendamento_id;
    END IF;

    -- Baixa técnica de insumos do procedimento consumido nesta sessão
    FOR v_insumo IN
        SELECT si.produto_id, si.quantidade_consumo, p.nome, p.quantidade_estoque
        FROM public.servico_insumos si
        JOIN public.produtos p ON p.id = si.produto_id
        WHERE si.servico_id = v_pacote.servico_id
        FOR UPDATE OF p
    LOOP
        v_qtd_insumo := v_insumo.quantidade_consumo;
        IF v_insumo.quantidade_estoque >= v_qtd_insumo THEN
            UPDATE public.produtos
            SET quantidade_estoque = quantidade_estoque - v_qtd_insumo
            WHERE id = v_insumo.produto_id;

            INSERT INTO public.movimentacoes_estoque (
                produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, motivo
            ) VALUES (
                v_insumo.produto_id, 'CONSUMO', v_qtd_insumo,
                v_insumo.quantidade_estoque, v_insumo.quantidade_estoque - v_qtd_insumo,
                'Consumo Sessão ' || v_numero_sessao || '/' || v_pacote.quantidade_total || ' Pacote #' || SUBSTRING(p_pacote_id::TEXT FROM 1 FOR 8)
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'sessao_id', v_sessao_id,
        'pacote_id', p_pacote_id,
        'cliente_id', v_pacote.cliente_id,
        'numero_sessao', v_numero_sessao,
        'quantidade_total', v_pacote.quantidade_total,
        'quantidade_consumida', v_numero_sessao,
        'quantidade_restante', v_pacote.quantidade_total - v_numero_sessao,
        'status_pacote', v_novo_status,
        'mensagem', 'Sessão ' || v_numero_sessao || ' de ' || v_pacote.quantidade_total || ' registrada com sucesso!'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dar_baixa_sessao_pacote(UUID, UUID, UUID, TEXT, JSONB, TEXT[]) TO anon, authenticated, service_role;

-- 6. STORED PROCEDURE: OBTER PACOTES E SESSÕES DO CLIENTE
CREATE OR REPLACE FUNCTION public.obter_pacotes_cliente(
    p_cliente_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_resultado jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(pacote_obj ORDER BY data_aquisicao DESC), '[]'::jsonb)
    INTO v_resultado
    FROM (
        SELECT 
            cp.id,
            cp.cliente_id,
            cp.servico_id,
            s.nome AS servico_nome,
            cp.titulo_personalizado,
            cp.quantidade_total,
            cp.quantidade_consumida,
            cp.quantidade_restante,
            cp.valor_total,
            cp.valor_por_sessao,
            cp.data_aquisicao,
            cp.data_validade,
            cp.status,
            cp.observacoes,
            (
                SELECT COALESCE(jsonb_agg(sessao_obj ORDER BY numero_sessao ASC), '[]'::jsonb)
                FROM (
                    SELECT 
                        psh.id,
                        psh.numero_sessao,
                        psh.data_realizacao,
                        psh.profissional_id,
                        u.nome AS profissional_nome,
                        psh.observacoes_evolucao,
                        psh.parametros_utilizados,
                        psh.fotos_sessao_urls
                    FROM public.pacotes_sessoes_historico psh
                    LEFT JOIN public.perfis_usuarios u ON u.id = psh.profissional_id
                    WHERE psh.pacote_id = cp.id
                ) sessao_obj
            ) AS sessoes
        FROM public.clientes_pacotes cp
        JOIN public.servicos s ON s.id = cp.servico_id
        WHERE cp.cliente_id = p_cliente_id
    ) pacote_obj;

    RETURN v_resultado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.obter_pacotes_cliente(UUID) TO anon, authenticated, service_role;
