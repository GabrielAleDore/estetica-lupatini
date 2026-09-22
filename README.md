# Estética Lupatini - ERP Clínico & Fluxo Financeiro Híbrido (PF vs. PJ)

Sistema de alta performance para clínicas de estética e dermatologia, com foco em:
- **PDV e Atendimento Integrado**: Registro ágil de procedimentos e produtos com baixa atômica de insumos técnicos (ampolas, agulhas, descartáveis).
- **Fluxo Financeiro Híbrido**: Segregação matemática rigorosa entre despesas da Pessoa Jurídica (Clínica) e gastos pessoais dos sócios (Pessoa Física).
- **Motor de Cartões de Crédito**: Projeção de faturas futuras (`YYYY-MM`) baseadas no melhor dia de compra (fechamento) e vencimento.
- **DRE Gerencial Mensal**: Apuração de Margem Operacional e Lucro Líquido Real.

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| **Frontend** | Flutter 3.20+ (Dart 3.11+) com BLoC/Cubit, Dio e Design System Responsivo (Desktop / Mobile / Web) |
| **Backend API** | Python 3.11+ com FastAPI, Pydantic v2 e SQLAlchemy 2.0 Async (AsyncPG) |
| **Banco de Dados & Auth** | Supabase / PostgreSQL 15+ com Row Level Security (RLS) e JSONB |

---

## 📁 Arquitetura Monorepo

```
ERP-Clinica/
├── supabase/
│   ├── migrations/
│   │   └── 20260914000001_init_schema.sql  # DDL, Enums, Índices e Triggers
│   └── seed.sql                            # Carga de demonstração com serviços e insumos
├── backend/
│   ├── app/
│   │   ├── core/                           # Configurações Pydantic e JWT Supabase
│   │   ├── models/                         # Modelos ORM SQLAlchemy 2.0
│   │   ├── schemas/                        # Contratos Pydantic v2 (Validações rigorosas)
│   │   ├── services/                       # VendasService, CartaoEngineService, FinanceiroService
│   │   ├── api/                            # Rotas RESTful (/vendas, /financeiro, /produtos, /relatorios)
│   │   └── main.py                         # App FastAPI e Middlewares CORS
│   ├── tests/                              # Testes automatizados do motor de cartões e vendas
│   └── requirements.txt
└── frontend/
    ├── lib/
    │   ├── core/                           # DioClient, Tema adaptativo, Breakpoints
    │   ├── features/
    │   │   ├── shell/                      # NavigationRail (Desktop) vs NavigationBar (Mobile)
    │   │   └── vendas/                     # PDV, Carrinho, Cubit e Catálogo Reativo
    │   └── main.dart
    └── pubspec.yaml
```

---

## 🚀 Como Executar

### 1. Banco de Dados (Supabase / PostgreSQL)
1. Execute as migrações no seu painel do Supabase (SQL Editor) ou via Supabase CLI:
```bash
supabase db push
# Ou execute o conteúdo de supabase/migrations/20260914000001_init_schema.sql
# e opcionalmente o supabase/seed.sql
```

### 2. Backend (FastAPI)
```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```
- A documentação interativa estará disponível em: `http://localhost:8000/docs`

### 3. Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run -d chrome      # Para Web
flutter run -d windows     # Para Desktop Windows
flutter run -d edge        # Para navegador alternativo
```
