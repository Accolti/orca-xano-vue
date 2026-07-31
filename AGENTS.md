# Orca Xano Vue — Agent Guide

## Dev commands

| Command | What |
|---|---|
| `npm run dev` | Vite dev server with HMR |
| `npm run build` | `vue-tsc --build` + `vite build` **in parallel** (via `npm-run-all2`) |
| `npm run preview` | Vite preview of production build |
| `npm run type-check` | `vue-tsc --build` (project references) |
| `npm run format` | Prettier on `src/` |
| `npm run build-only` | `vite build` alone (skip type-check) |

## Framework & tooling

- **Vite 8** (Rolldown bundler), **Vue 3.5**, **Pinia 3**, **Vue Router 5**, **TypeScript 6**
- Path alias `@/` → `./src/*` (configured in both `vite.config.ts` and `tsconfig.app.json`)
- Type-check uses `vue-tsc` (not `tsc`); run `npm run type-check` or `npm run build`
- Pinia stores use Composition API style (`defineStore('name', () => { ... })`)
- Vue Router uses `createWebHistory` (HTML5 history mode)
- Prettier: no semicolons, single quotes, 100 print width (`.prettierrc.json`)

## Architecture

- `src/main.ts` — bootstrap: global CSS, Pinia, router, mount
- `src/router/index.ts` — routes: `/` (HomeView, eager), `/about` (AboutView, lazy)
- `src/services/xano.ts` — singleton `XanoClient` from `@xano/js-sdk`, configured via `VITE_XANO_BASE_URL` env var
- `src/stores/catalogo.ts` — `useCatalogoStore`: árvore completa Material/Linha/Tipo/Nivel/Borda, cache localStorage por versão via `/configuracoes`, loaded flag de sessão
- `src/stores/counter.ts` — scaffold example store (not used by any view)
- `.env` contains `VITE_XANO_BASE_URL` (committed — override via `.env.local` for production)
- `src/views/HomeView.vue` fetches from Xano endpoint `/api:-qqRIakp/cliente_user` on mount
- `index.html` `<title>` is still "Vite App" — customize as needed
- `src/components/HelloWorld.vue`, `TheWelcome.vue`, `WelcomeItem.vue`, `icons/*` are unused scaffold boilerplate

## Catálogo de Produtos

`src/stores/catalogo.ts` — store responsável por fornecer a árvore completa de materiais, linhas, tipos, níveis e bordas em uma única chamada de API, com cache persistente por versão.

### APIs consumidas

- `GET /configuracoes` → `{ configuracoes-mae: [{ versao_materiais: N, versao_produtos: M }] }` — chamada leve (~200 bytes)
- `GET /produtos_para_selecao` → `{ lista_para_selecao: { Material: { material }, Linha, Tipo, Nivel, Borda } }` — árvore de dropdowns
- `GET /produtos_all` → array de produtos com `_variacao[]` (produtos mães, filhos e variações); input zerado traz tudo

### Ciclo de vida (`fetchCatalogo()`)

As duas partes (árvore de materiais e produtos) têm caches **independentes** e são baixadas separadamente — só a API cuja versão mudou é chamada (numa primeira carga sem cache, as duas são chamadas).

| Etapa | Descrição |
|---|---|
| `loaded` da sessão | Se `true`, retorna imediatamente (0 chamadas de API) |
| `/configuracoes` | Busca `versao_materiais` **e** `versao_produtos` atuais no servidor (popula `versaoMateriais`/`versaoProdutos`/`versaoLabel`) |
| Cache materiais (`orca_catalogo_materiais_cache`) | Se `cache.versao === versao_materiais`, popula árvore do cache; senão baixa `/produtos_para_selecao` e salva |
| Cache produtos (`orca_catalogo_produtos_cache`) | Se `cache.versao === versao_produtos`, popula produtos do cache; senão baixa `/produtos_all` e salva |
| `loaded = true` | Marca sessão como carregada |

### Badge de versão no header

`GlobalHeader` mostra `versaoLabel` (`M{versao_materiais}P{versao_produtos}`, ex. `M2P1`) como um badge clicável que abre um popover com os dois valores. Usa `catalogo.carregarConfiguracoes()` (só `/configuracoes`, sem baixar catálogo) no `onMounted`.

### Logout

`authStore.logout()` chama `catalogo.resetarSessao()` — zera `loaded` + `selectedMaterialId`, forçando revalidação no próximo login.

### Consumo no `orcamentoStore`

As refs `materiais`, `linhas`, `tipos`, `niveis`, `bordas` agora são **computed** que consomem `useCatalogoStore()`.  
`carregarMateriais()` delega para `catalogo.fetchCatalogo()`.  
`selecionarMaterial()` virou síncrona — apenas seta `materialSelecionado` + `catalogo.selectedMaterialId`.

### Listbox de Variação

Produtos com `detalhe_id > 0` no `produtos_all` têm `_variacao[]`. A store cruza a seleção atual (`material_id`, `linha_id ?? 0`, `tipo_id ?? 0`, `nivel_id ?? 0`) com os produtos e monta `variacoes` (união dos `_variacao`, dedupe por `id`, ordenado por `ordem`).  
`mostrarVariacao` = `variacoes.length > 0`; `watch` limpa `variacaoSelecionada` ao ocultar ou quando sai da lista.  
O `inserirOrcamento()` envia `variacao_id: variacaoSelecionada?.id ?? 0` (antes era `0` fixo). O cálculo (`CalculoValorVenda_IDs`) **não** recebe variação por enquanto.

### Exceção Vinil+Liso (`mostrarNivel`)

Quando Material = Vinil, Linha = Gold ou Alto Tráfego, Tipo = Liso → Nível (cores) não faz sentido, então `mostrarNivel` retorna `false` e o campo some. Um `watch` limpa `nivelSelecionado` automaticamente.

## What's NOT set up

- **No test runner** — Vitest, Cypress, Playwright configs do not exist. If adding tests, create the config files.
- **No ESLint** — lint config was removed from scaffold. If adding linting, create `eslint.config.*` from scratch.
- **No CI** — no `.github/` directory.
- **No `typed-router.d.ts`** — VS Code file-nesting config references it, but it doesn't exist. Generate if needed (Vue Router 5 typegen).
- **No commit hooks** — no Husky or lint-staged.

## Conventions

- Composition API with `<script setup lang="ts">` for all components
- Scoped CSS in components (HomeView.vue uses `#42b883` green theme)
- Format before committing: `npm run format`

## Skills

- `.agents/skills/xano-sdk-error-handling/` — como extrair `message` e `payload` reais dos erros da SDK do Xano (usar `err.getResponse().getBody()` em vez de `err.message`)
- `.agents/skills/orcamento-recalculo-flow/` — fluxo dos 4 mecanismos de recálculo (Novo Vlr Venda B2B, Nova Margem, Novo Frete B2B, Novo Lcr Total) com APIs Xano, store Pinia e guardrails
