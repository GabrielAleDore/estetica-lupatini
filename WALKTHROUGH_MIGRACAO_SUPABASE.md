# Walkthrough: Migração Arquitetural 100% Flutter + Supabase SDK

A arquitetura do projeto **Estética Lupatini** foi completamente refatorada para **100% Flutter (Dart puro)**, eliminando a camada intermediária em Python/FastAPI e conectando o app diretamente ao **Supabase (PostgreSQL 15+)** via SDK oficial (`supabase_flutter`).

---

## 1. 🧹 Desativação e Arquivamento do Backend Antigo
- A pasta `backend/` foi renomeada para [`backend_archived/`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/backend_archived/README_ARCHIVED.md).
- O pacote `dio` e a classe legada `DioClient` foram removidos do Flutter.
- Não existem mais servidores adicionais (Uvicorn/FastAPI) necessários para rodar a aplicação: basta executar o app Flutter.

---

## 2. ⚡ Configuração Oficial do Supabase no Flutter
- Adicionada a dependência oficial [`supabase_flutter`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/pubspec.yaml).
- Criado o serviço unificado [`SupabaseService`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/core/services/supabase_service.dart).
- Inicialização configurada no [`main.dart`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/main.dart):
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SupabaseService.initialize();
    runApp(const EsteticaLupatiniApp());
  }
  ```
- Variáveis de ambiente configuradas em [`app_constants.dart`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/core/constants/app_constants.dart):
  - `SUPABASE_URL`: `https://qfphiraxxyknhvqjcyrt.supabase.co`
  - `SUPABASE_KEY`: Chave de autenticação pública/anon integrada.

---

## 3. 🛡️ Stored Procedures e Regras Atômicas (PostgreSQL)
Migrações aplicadas diretamente no Supabase:
1. **`realizar_venda(p_venda jsonb)`** ([`20260915000002_realizar_venda_rpc.sql`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/supabase/migrations/20260915000002_realizar_venda_rpc.sql)):
   - Bloqueio pessimista (`FOR UPDATE`) para concorrência de estoque.
   - Baixa atômica de produtos comercializados (`tipo = 'SAIDA'`).
   - Baixa atômica de insumos técnicos consumidos por serviços (`tipo = 'CONSUMO'`).
   - Registro de itens da venda e lançamento contábil em `transacoes_financeiras` (`escopo = 'PJ'`).
2. **`obter_dashboard_resumo()`**:
   - Agregação SQL em consulta única no PostgreSQL (Faturamento PJ, Despesas PF, Despesas PJ, Balanço Líquido e Alertas de Estoque).
3. **`20260915000003_realtime_and_policies.sql`**:
   - Habilitação de RLS e publicação `supabase_realtime` com `REPLICA IDENTITY FULL` em `parcelas_financeiras`, `contas_cartoes`, `vendas`, `produtos` e `clientes`.

---

## 4. 🔄 Repositórios 100% Supabase no Flutter

| Repositório | Funcionalidade Principal | Mecanismo Supabase |
| :--- | :--- | :--- |
| [`VendasRepository`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/features/vendas/data/repositories/vendas_repository.dart) | PDV, catálogo unificado e finalização | `.from('servicos')`, `.from('produtos')` e `.rpc('realizar_venda')` |
| [`ClientesRepository`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/features/clientes/data/clientes_repository.dart) | Listagem, busca e cadastro com Anamnese | `.from('clientes').select()` / `.insert()` com sanitização |
| [`CartoesRepository`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/features/cartoes/data/cartoes_repository.dart) | Cartões, faturas e parcelas | `.from('parcelas_financeiras').stream()` e cálculo de limite em tempo real |
| [`CatalogoRepository`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/features/catalogo/data/catalogo_repository.dart) | CRUD de Produtos e Procedimentos com BOM | `.from('servicos')`, `.from('servico_insumos')`, `.from('produtos')` |
| [`DashboardRepository`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/features/dashboard/data/dashboard_repository.dart) | Métricas agregadas e reposição de estoque | `.rpc('obter_dashboard_resumo')` e `.from('movimentacoes_estoque')` |

---

## 5. 📡 Reatividade em Tempo Real (Cartões)
- No [`CartoesCubit`](file:///c:/Users/gabriel.dore/.gemini/antigravity-ide/scratch/ERP-Clinica/frontend/lib/features/cartoes/presentation/cubit/cartoes_cubit.dart), foi criada a assinatura `_parcelasSubscription` via `streamParcelas(cartaoId)`.
- Qualquer compra parcelada cadastrada ou alterada dispara o recálculo automático da fatura e da barra de limite sem necessidade de refresh manual pelo usuário.

---

## 6. 🧪 Verificação de Qualidade e Compilação
- **`flutter analyze`:** `No issues found! (ran in 5.3s)`
- **`flutter test`:** `00:01 +4: All tests passed!`
- **`flutter build web`:** `√ Built build\web (55.1s)`

---

## 7. 🚀 Como Rodar o App (Apenas 1 Comando)

Agora que não há necessidade do servidor Python/FastAPI, você precisa apenas rodar o Flutter:

```bash
cd frontend
flutter run -d chrome
```

Para rodar especificando chaves em tempo de compilação (opcional, já há defaults seguros integrados):
```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://qfphiraxxyknhvqjcyrt.supabase.co --dart-define=SUPABASE_KEY=sua_chave_anon
```
