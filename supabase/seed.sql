-- ==============================================================================
-- Seed: seed.sql
-- Dados iniciais para demonstração e homologação do sistema Estética Lupatini
-- ==============================================================================

-- 1. Categorias Padrão
INSERT INTO categorias (id, nome, tipo) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Procedimentos Faciais', 'SERVICO'),
    ('a0000000-0000-0000-0000-000000000002', 'Procedimentos Corporais', 'SERVICO'),
    ('a0000000-0000-0000-0000-000000000003', 'Home Care e Cosméticos', 'PRODUTO'),
    ('a0000000-0000-0000-0000-000000000004', 'Insumos Técnicos e Descartáveis', 'PRODUTO'),
    ('a0000000-0000-0000-0000-000000000005', 'Despesas Operacionais Clínica', 'DESPESA'),
    ('a0000000-0000-0000-0000-000000000006', 'Retiradas e Despesas Pessoais (PF)', 'DESPESA'),
    ('a0000000-0000-0000-0000-000000000007', 'Receitas de Atendimento', 'RECEITA')
ON CONFLICT (id) DO NOTHING;

-- 2. Produtos e Insumos
INSERT INTO produtos (id, categoria_id, nome, codigo_barras, preco_custo, preco_venda, quantidade_estoque, estoque_minimo, permite_venda, unidade_medida) VALUES
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'Sérum Ácido Hialurônico 30ml', '789123456001', 45.00, 140.00, 18.000, 5.000, TRUE, 'UN'),
    ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 'Protetor Solar FPS 60 Toque Seco 50g', '789123456002', 32.00, 95.00, 24.000, 8.000, TRUE, 'UN'),
    ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000004', 'Toxina Botulínica 100U', '789123456003', 480.00, 0.00, 6.000, 4.000, FALSE, 'AMPOLA'),
    ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000004', 'Preenchedor Ácido Hialurônico 1ml', '789123456004', 320.00, 0.00, 3.000, 5.000, FALSE, 'SERINGA'),
    ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000004', 'Kit Descartável (Luva, Máscara, Gaze)', '789123456005', 4.50, 0.00, 42.000, 20.000, FALSE, 'KIT')
ON CONFLICT (id) DO NOTHING;

-- 3. Serviços Clínicos
INSERT INTO servicos (id, categoria_id, nome, duracao_minutos, preco, ativo) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Aplicação de Botox Terço Superior', 45, 950.00, TRUE),
    ('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Preenchimento Labial 1ml', 60, 1200.00, TRUE),
    ('c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Limpeza de Pele Profunda', 75, 220.00, TRUE)
ON CONFLICT (id) DO NOTHING;

-- 4. Insumos por Serviço (Ficha Técnica de Consumo por Atendimento)
-- Botox consome 0.5 ampola de Toxina e 1 Kit Descartável
INSERT INTO servico_insumos (servico_id, produto_id, quantidade_consumo) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 0.500),
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 1.000)
ON CONFLICT DO NOTHING;

-- 5. Contas e Cartões (Híbrido PF vs. PJ)
INSERT INTO contas_cartoes (id, nome, escopo, dia_fechamento, dia_vencimento, limite, ativo) VALUES
    ('d0000000-0000-0000-0000-000000000001', 'Nubank Platinum Lupatini', 'PF', 18, 25, 25000.00, TRUE),
    ('d0000000-0000-0000-0000-000000000002', 'Itaú Empresas Business', 'PJ', 10, 17, 60000.00, TRUE)
ON CONFLICT (id) DO NOTHING;

-- 6. Cliente Padrão com Ficha de Anamnese Dermatológica
INSERT INTO clientes (id, nome, telefone, email, cpf, anamnese, status) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'Mariana Alcantara Silveira', '(11) 98765-4321', 'mariana.silveira@email.com', '123.456.789-00', '{
        "tipo_pele": "Mista com tendência a oleosidade",
        "fototipo_fitzpatrick": "III",
        "alergias": ["Dipirona"],
        "medicamentos_uso": ["Anticoncepcional oral"],
        "historico_cirurgico": "Rinoplastia em 2022",
        "queixa_principal": "Linhas de expressão na fronte e glabela",
        "observacoes_tecnicas": "Pele bem hidratada, boa resposta a bioestimuladores"
    }'::jsonb, 'ATIVO')
ON CONFLICT (id) DO NOTHING;
