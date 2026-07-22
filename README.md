# Orca Xano Vue

Sistema de gestão de clientes (Orca Systems) com autenticação, CRUD de clientes com busca por CNPJ (via Xano) e CEP (via ViaCEP), e backend Xano.

## Stack

- **Vue 3.5** + **TypeScript 6** com `<script setup lang="ts">`
- **Vite 8** (Rolndown bundler)
- **Pinia 3** — stores com Composition API
- **Vue Router 5** — HTML5 history, navigation guard (rotas autenticadas)
- **Xano SDK** (`@xano/js-sdk`) — cliente HTTP para o backend
- **Prettier** — formatação (sem ponto e vírgula, aspas simples, 100 colunas)
- Path alias `@/` → `./src/*`

## Funcionalidades

- **Autenticação** — login/signup com token persistido no `localStorage`
- **Sidebar** — menu lateral com navegação (Home, Clientes, demais itens desabilitados)
- **CRUD de Clientes** — modal de criação/edição com formulário completo
- **Busca por CNPJ** — consulta via endpoint Xano `/capturarDados_CNPJ_IE`
- **Busca por CEP** — consulta automática via ViaCEP
- **Busca de clientes** — server-side com debounce de 350ms, mínimo 3 caracteres
- **Exclusão** com confirmação e exibição de erros da SDK

## Rotas

| Path | View | Protegida |
|---|---|---|
| `/` | HomeView | Sim |
| `/clientes` | ClientesView | Sim |
| `/login` | LoginView | Não (redireciona se logado) |
| `/signup` | SignupView | Não (redireciona se logado) |
| `/about` | AboutView | Sim |

## Endpoints Xano

Todos usam o prefixo de API group `/api:-qqRIakp`:

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/api:-qqRIakp/auth/login` | Login |
| `POST` | `/api:-qqRIakp/auth/signup` | Cadastro |
| `GET` | `/api:-qqRIakp/auth/me` | Dados do usuário logado |
| `GET` | `/api:-qqRIakp/cliente_user_busca?busca={termo}` | Busca de clientes |
| `GET` | `/api:-qqRIakp/capturarDados_CNPJ_IE?cnpj={cnpj}` | Buscar CNPJ |
| `POST` | `/api:-qqRIakp/Cliente_Endereco_Telefone` | Criar cliente |
| `PATCH` | `/api:-qqRIakp/Cliente_Endereco_Telefone` | Atualizar cliente |
| `GET` | `/api:-qqRIakp/cliente/{id}` | Ler um cliente |
| `DELETE` | `/api:-qqRIakp/cliente/{id}` | Excluir cliente |

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
| `VITE_XANO_BASE_URL` | Base URL da instância Xano |

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
├── assets/         # CSS global
├── components/     # SidebarNav, ClienteModal
├── data/           # mappings.ts (dropdowns)
├── router/         # Vue Router + navigation guard
├── services/       # XanoClient singleton
├── stores/         # Pinia (auth, cliente)
├── types/          # Interfaces (Cliente, ClienteForm)
└── views/          # Home, Login, Signup, Clientes, About
```
