# Orca Xano Vue

Sistema de gestão de tapetes personalizados (Orca Systems) com autenticação, CRUD de clientes, orçamento multi-item com calculadora de preços, catálogo de produtos com cache por versão, e backend Xano.

> **Roadmap de ideias** (pastas compartilhadas/Google Drive, parametrização de condições de pagamento, multi-vendedor/comissão/permissões): ver [`ROADMAP.md`](./ROADMAP.md)

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
- **Simulação** — condições de pagamento (Pix/boleto)
- **Edição de orçamento** — suporte a `/orcamentos/:codOrca` com modo read-only se vinculado
- **Catálogo versionado** — cache localStorage com controle por versão (`versao_materiais` + `versao_produtos`) via `/configuracoes`; baixa produtos mães/filhos e variações (`/produtos_all`)
- **Variação** — listbox com `_variacao` do produto quando o produto tem `detalhe_id > 0`
- **Versões no header** — badge `M2P1` com popover mostrando as versões (badge de versão no cabeçalho)
- **Nível inteligente** — a combo de Nível é derivada dos produtos reais ativos (`ativo` na tabela `Produto`) cruzando a seleção Material+Linha+Tipo; sem exceções hardcoded (Vinil+Liso some sozinho; Vinil Alto Tráfego Vulcanizado sem Nível 3)

## Rotas

| Path | View | Protegida |
|---|---|---|
| `/` | HomeView | Sim |
| `/clientes` | ClientesView | Sim |
| `/orcamentos` | OrcamentosListView (paginada) | Sim |
| `/orcamentos/novo` | OrcamentosView (criação) | Sim |
| `/orcamentos/:codOrca` | OrcamentosView (edição) | Sim |
| `/login` | LoginView | Não (redireciona se logado) |
| `/signup` | SignupView | Não (redireciona se logado) |
| `/about` | AboutView | Sim |

## Endpoints Xano

Todos usam o prefixo de API group `/api:-qqRIakp`:

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/auth/login` | Login |
| `POST` | `/auth/signup` | Cadastro |
| `GET` | `/auth/me` | Dados do usuário logado |
| `GET` | `/configuracoes` | Versões atuais do catálogo (`versao_materiais` + `versao_produtos`, ~200 bytes) |
| `GET` | `/produtos_para_selecao` | Catálogo para dropdowns (Material, Linha, Tipo, Nivel, Borda) |
| `GET` | `/produtos_all` | Produtos mães, filhos e variações (`_variacao[]`) |
| `GET` | `/CalculoValorVenda_IDs` | Cálculo de preços do item |
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
