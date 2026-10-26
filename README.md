# Estética Lupatini - ERP Clínico & Fluxo Financeiro Híbrido (PF vs. PJ)

Sistema de alta performance e arquitetura moderna para clínicas de estética e dermatologia, com foco em:
- **PDV e Atendimento Integrado**: Registro ágil de procedimentos e produtos com baixa atômica de insumos técnicos (ampolas, agulhas, descartáveis) via stored procedures transacionais.
- **Fluxo Financeiro Híbrido**: Segregação contábil rigorosa entre despesas da Pessoa Jurídica (Clínica) e gastos pessoais dos sócios (Pessoa Física).
- **Gestão de Contas Bancárias & Transferências**: Conciliação automática de saldo, transferências entre contas com débito/crédito atômico e rastreabilidade total.
- **Motor de Cartões de Crédito**: Projeção e apuração de faturas futuras (`YYYY-MM`) com ajuste de vencimentos (regra Febraban), controle de limite disponível e edição de parcelas.
- **DRE Gerencial Mensal**: Apuração instantânea de Receita Líquida, Custos de Mercadorias/Insumos (CMV/CSV), Despesas Fixas/Variáveis e Lucro Operacional Real.
- **Navegação Fluida (60 FPS)**: Estrutura em `IndexedStack` que preserva o estado completo do carrinho, filtros e abas durante a navegação.

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia | Detalhes |
|---|---|---|
| **Frontend** | Flutter 3.20+ (Dart 3.11+) | Flutter BLoC / Cubit, Equatable, Design System Responsivo (Desktop / Mobile / Web), 60 FPS |
| **Banco de Dados & Auth** | Supabase / PostgreSQL 15+ | Supabase SDK direto, Row Level Security (RLS), Triggers atômicos de saldo e estoque, Stored Procedures com `SECURITY DEFINER` |
| **Backend Legado** | `backend_archived/` | Arquivado como referência histórica (a aplicação opera 100% Client-to-Supabase moderno) |

---

## 📁 Arquitetura Monorepo

```
ERP-Clinica/
├── supabase/
│   ├── migrations/
│   │   ├── 20260914000001_init_schema.sql  # Schema inicial, tabelas, enums e triggers
│   │   └── ...
│   │   └── 20261026000008_correcoes_reconciliacao_transferencias_e_saldo.sql # Stored procedures de reconciliação, transferência e baixa de vendas
│   └── seed.sql                            # Carga demonstrativa completa (serviços, produtos, contas e usuários)
├── frontend/
│   ├── lib/
│   │   ├── core/                           # Supabase Client, Constantes de Autenticação, Utilitários de Moeda
│   │   ├── features/
│   │   │   ├── auth/                       # Autenticação, RBAC e Gestão de Perfil
│   │   │   ├── shell/                      # NavigationRail responsivo com IndexedStack de alta performance
│   │   │   ├── dashboard/                  # Visão Geral, DRE Gerencial, Entradas Avulsas e Transferências
│   │   │   ├── vendas/                     # PDV, Comandas, Carrinho com desconto fidelidade e Contas a Receber
│   │   │   ├── contas_pagar/               # Registro de Despesas PJ/PF, baixas de boletos e parcelamentos
│   │   │   ├── cartoes/                    # Gestão de Faturas, parcelas e controle de limite disponível
│   │   │   ├── contas_bancarias/           # Liquidez imediata, reconciliação e transferências entre contas
│   │   │   ├── clientes/                   # Fichas completas, anamnese e fidelização
│   │   │   ├── catalogo/                   # Procedimentos estéticos, insumos e composição técnica (BOM)
│   │   │   ├── estoque/                    # Movimentação e auditoria física de estoque
│   │   │   ├── agenda/                     # Agendamentos e integração WhatsApp
│   │   │   └── operacoes/                  # Cockpit de Operações diárias da recepção
│   │   └── main.dart
│   └── test/
│       └── widget_test.dart                # Bateria completa de testes automatizados (100% aprovados)
└── backend_archived/                       # Código legado FastAPI (descomissionado)
```

---

## 🚀 Como Executar

### 1. Banco de Dados (Supabase / PostgreSQL)
1. Crie um projeto no Supabase ou inicie o ambiente local com o Supabase CLI:
```bash
supabase db push
# Ou execute as migrações em ordem via Supabase SQL Editor:
# 1. supabase/migrations/20260914000001_init_schema.sql ... até 20261026000008
# 2. supabase/seed.sql (opcional para dados de teste)
```

### 2. Frontend (Flutter)
1. Instale as dependências:
```bash
cd frontend
flutter pub get
```

2. Execute a suíte de testes e análise:
```bash
flutter analyze
flutter test
```

3. Inicie a aplicação na sua plataforma desejada:
```bash
flutter run -d chrome      # Web (Google Chrome)
flutter run -d windows     # Desktop Windows Nativo
flutter run -d edge        # Web (Microsoft Edge)
```

### 3. Credenciais Padrão de Acesso (Demonstração)
- **E-mail**: `admin@lupatini.com`
- **Senha**: `Admin@123`
