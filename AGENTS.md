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
- `src/stores/counter.ts` — scaffold example store (not used by any view)
- `.env` contains `VITE_XANO_BASE_URL` (committed — override via `.env.local` for production)
- `src/views/HomeView.vue` fetches from Xano endpoint `/api:-qqRIakp/cliente_user` on mount
- `index.html` `<title>` is still "Vite App" — customize as needed
- `src/components/HelloWorld.vue`, `TheWelcome.vue`, `WelcomeItem.vue`, `icons/*` are unused scaffold boilerplate

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
