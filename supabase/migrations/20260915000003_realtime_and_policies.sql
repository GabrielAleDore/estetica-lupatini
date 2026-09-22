-- ==============================================================================
-- Migration: 20260915000003_realtime_and_policies.sql
-- Habilita Políticas RLS Abertas e Supabase Realtime para Flutter
-- ==============================================================================

-- 1. Políticas RLS permissivas para todas as tabelas clínicas
DO $$ 
DECLARE 
    t text;
    tables text[] := ARRAY[
        'clientes', 'categorias', 'produtos', 'servicos', 'servico_insumos',
        'vendas', 'itens_venda', 'movimentacoes_estoque', 'contas_cartoes',
        'transacoes_financeiras', 'parcelas_financeiras'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Acesso total publico e autenticado" ON %I;', t);
        EXECUTE format('CREATE POLICY "Acesso total publico e autenticado" ON %I FOR ALL TO public, anon, authenticated USING (true) WITH CHECK (true);', t);
        EXECUTE format('GRANT ALL ON TABLE %I TO anon, authenticated, service_role;', t);
    END LOOP;
END $$;

-- 2. Habilita Replica Identity FULL para suportar streaming de updates/deletes no Realtime
ALTER TABLE parcelas_financeiras REPLICA IDENTITY FULL;
ALTER TABLE contas_cartoes REPLICA IDENTITY FULL;
ALTER TABLE transacoes_financeiras REPLICA IDENTITY FULL;
ALTER TABLE vendas REPLICA IDENTITY FULL;
ALTER TABLE produtos REPLICA IDENTITY FULL;
ALTER TABLE servicos REPLICA IDENTITY FULL;
ALTER TABLE clientes REPLICA IDENTITY FULL;

-- 3. Adiciona as tabelas na publicação supabase_realtime
DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE 
        parcelas_financeiras,
        contas_cartoes,
        transacoes_financeiras,
        vendas,
        produtos,
        servicos,
        clientes;
EXCEPTION
    WHEN duplicate_object THEN null;
    WHEN others THEN null;
END $$;
