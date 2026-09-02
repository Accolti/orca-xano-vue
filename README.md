# Orca Xano Vue

Sistema de gestão de tapetes personalizados (Orca Systems) com autenticação, CRUD de clientes, orçamento multi-item com calculadora de preços, catálogo de produtos com cache por versão, e backend Xano.

> **Documentação:**
> - [`docs/FUNCIONALIDADES.md`](./docs/FUNCIONALIDADES.md) — estado atual do sistema (orçamento, status, pedido, Kapazi, perfil, tema, PDF/WhatsApp)
> - [`ROADMAP.md`](./ROADMAP.md) — ideias futuras (Google Drive, condições parametrizáveis, multi-vendedor/comissões, relatórios, dashboard)
> - [`LEGADO.md`](./LEGADO.md) — funções/endpoints órfãos e migração

## Stack

- **Vue 3.5** + **TypeScript 6** com `<script setup lang="ts">`
- **Vite 8** (Rolldown bundler)
- **Pinia 3** — stores com Composition API
- **Vue Router 5** — HTML5 history, navigation guard (rotas autenticadas)
- **Xano SDK** (`@xano/js-sdk`) — cliente HTTP para o backend
- **Prettier** — formatação (sem ponto e vírgula, aspas simples, 100 colunas)
- Path alias `@/` → `./src/*`

## Funcionalidades

- **Autenticação** — login/signup com token persistido no `localStorage`
- **Sidebar** — menu lateral escuro com toggle, 8 itens de navegação
- **GlobalHeader** — cabeçalho com dados do usuário + hamburger
- **CRUD de Clientes** — modal de criação/edição com formulário completo, dropdowns Ramo/Mercado/Regime/Benefício Fiscal
- **Busca por CNPJ** — consulta via endpoint Xano `/capturarDados_CNPJ_IE`
- **Busca por CEP** — consulta automática via ViaCEP
- **Busca de clientes** — server-side com debounce de 350ms, mínimo 3 caracteres
- **Orçamento multi-item** — calculadora com Material/Linha/Tipo/Nível/Borda, dimensões, quantidade
- **Recálculo em tempo real** — 4 mecanismos (Novo Vlr Venda B2B, Nova Margem, Novo Frete B2B, Novo Lcr Total)
- **Simulação de margens** — gerada no front (faixa 50–100 passo 10, rótulos c5..c10), com olho 👁 para custo/lucro e condições de pagamento ao clicar na linha
- **Edição de orçamento** — suporte a `/orcamentos/:codOrca` com modo read-only se vinculado
- **Catálogo versionado** — cache localStorage com controle por versão (`versao_materiais` + `versao_produtos` + `versao_taxas_banco`) via `/configuracoes`; baixa produtos mães/filhos e variações (`/produtos_all`) e taxas de cartão (`/taxas_banco`)
- **Variação** — listbox com `_variacao` do produto quando o produto tem `detalhe_id > 0`
- **Versões no header** — badge `M..P..T..` (ex.: `M2P1T3`) com popover mostrando as versões de materiais/produtos/taxas
- **Nível inteligente** — a combo de Nível é derivada dos produtos reais ativos (`ativo` na tabela `Produto`) cruzando a seleção Material+Linha+Tipo; sem exceções hardcoded (Vinil+Liso some sozinho; Vinil Alto Tráfego Vulcanizado sem Nível 3)
- **Duplicar orçamento** — botão na listagem (`POST /Orcamento_Duplicar`, case-sensitive) que abre o duplicado em modo edição
- **Condições de pagamento** — seletor avançado (instituição + mais vantajosa ⭐, checkboxes Pix/Boleto/Cartão, desconto Pix com impacto em lucro/margem, mesclagem de métodos)
- **Detalhes ML** — `detalhes_calculo.ml` gravado (rolos/metros/orientação) e exibido na tabela, WhatsApp e PDFs
- **Quantidade decimal** — `item.qtd` aceita frações (ex.: metros lineares), input com `step="0.01"`
- **Controle Financeiro** — página `/pagamentos`: parcelas por orçamento com abas de status (Em aberto = não pagas / A vencer / Vencidos / Pagos) + baixa/estorno manual; barra **"Período a partir de"** (Mensal/Trimestral/Semestral/Anual)
- **Faturar** — em `AGUARDANDO_FATURAMENTO`, salva as parcelas via `PagamentoModal` e avança para `FATURADO`; status pós-conversão: FATURADO/ENTREGUE/CANCELADO
- **Dashboard com período** — Home vira painel (cards + funil de status) filtrável por mês de início e Mensal/Trimestral/Semestral/Anual (`/dashboard?periodo&mes_inicio`)
- **Novo cliente dentro do orçamento** — botão "＋ Novo cliente" na seção Cliente cria o cliente e já o vincula ao orçamento aberto

## Rotas

| Path | View | Protegida |
|---|---|---|
| `/` | HomeView (dashboard) | Sim |
| `/clientes` | ClientesView | Sim |
| `/orcamentos` | OrcamentosListView (paginada) | Sim |
| `/pedidos` | PedidosView | Sim |
| `/pagamentos` | PagamentosView (controle financeiro) | Sim |
| `/orcamentos/novo` | OrcamentosView (criação) | Sim |
| `/orcamentos/:codOrca` | OrcamentosView (edição) | Sim |
| `/login` | LoginView | Não (redireciona se logado) |
| `/signup` | SignupView | Não (redireciona se logado) |
| `/oauth/callback` | OAuthCallbackView | Não |
| `/dev/*` | Dev tools (Produtos/Fatores/Materiais/Configurações) | Sim + DEV |

## Endpoints Xano

Todos usam o prefixo de API group `/api:-qqRIakp`:

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/auth/login` | Login |
| `POST` | `/auth/signup` | Cadastro |
| `GET` | `/auth/me` | Dados do usuário logado |
| `GET` | `/configuracoes` | Versões atuais do catálogo (`versao_materiais` + `versao_produtos` + `versao_taxas_banco`, ~200 bytes) |
| `GET` | `/produtos_para_selecao` | Catálogo para dropdowns (Material, Linha, Tipo, Nivel, Borda) |
| `GET` | `/produtos_all` | Produtos mães, filhos e variações (`_variacao[]`) |
| `GET` | `/taxas_banco` | Taxas de cartão por instituição (`provedor`, `parcelas`, `cc_taxa`) |
| `POST` | `/orcamento_calcular` | Cálculo pelo orquestrador (novo fluxo) |
| `POST` | `/Orcamento_Duplicar` | Duplicar orçamento (case-sensitive) |
| `GET` | `/CalculoValorVenda_IDs` | Cálculo de preços do item (legado) |
| `GET` | `/Calc_new_Valor_Venda` | Recálculo: novo valor venda → nova margem |
| `GET` | `/Calc_new_Valor_Lucro` | Recálculo: novo lucro → nova margem |
| `GET` | `/Novo_Numero_Orcamento` | Gerar número de orçamento |
| `POST` | `/OrcamentoItem_Inserir` | Inserir item no orçamento |
| `GET` | `/Orcamento_Detalhes` | Carregar orçamento existente |
| `DELETE` | `/orcamento_deletar` | Excluir orçamento |
| `GET` | `/orca_por_cliente_busca` | Lista paginada de orçamentos |
| `GET` | `/cliente_user_busca` | Busca de clientes |
| `GET` | `/capturarDados_CNPJ_IE` | Buscar CNPJ |
| `POST` | `/Cliente_Endereco_Telefone` | Criar cliente |
| `PATCH` | `/Cliente_Endereco_Telefone` | Atualizar cliente |
| `GET` | `/cliente/{id}` | Ler um cliente |
| `DELETE` | `/cliente/{id}` | Excluir cliente |
| `GET` | `/pagamentos` | Listar parcelas financeiras (filtro `orca_id` opcional) |
| `POST` | `/pagamento_salvar` | Substituir parcelas de uma orça |
| `POST` | `/pagamento_baixa` | Baixar/estornar uma parcela |
| `POST` | `/pagamento_excluir` | Excluir parcela |
| `GET` | `/dashboard` | Resumo do dashboard (`mes_inicio` + `periodo`) |

## APIs externas

- **ViaCEP** — `https://viacep.com.br/ws/{cep}/json/`

## Proxy (dev)

O Vite faz proxy para evitar CORS em desenvolvimento:

| Prefixo | Target |
|---|---|
| `/auth`, `/api` | Xano |

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `VITE_XANO_BASE_URL` | Base URL da instância Xano (apenas produção) |

> `.env` é versionado. Crie `.env.local` para override em produção.

## Comandos

```sh
npm install        # instalar dependências
npm run dev        # servidor dev com HMR
npm run build      # type-check + build em paralelo
npm run preview    # preview do build
npm run type-check # apenas type-check
npm run format     # formatar src/ com Prettier
```

## Projeto

```
src/
├── assets/           # CSS global (base.css, main.css)
├── components/       # SidebarNav, ClienteModal, GlobalHeader, SimulacaoModal
├── data/             # mappings.ts (dropdowns Ramo/Mercado/Regime/Benefício)
├── router/           # Vue Router + navigation guard
├── services/         # XanoClient singleton
├── stores/           # Pinia (auth, orcamento, catalogo, cliente)
├── types/            # Interfaces (Cliente, Orcamento, etc.)
└── views/            # Home, Login, Signup, Clientes, Orcamentos, OrcamentosList, About
```
