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
- `src/services/xano.ts` — singleton `XanoClient` do `@xano/js-sdk`, configurado via `VITE_XANO_BASE_URL`. Expõe um **wrapper** (`get/post/put/patch/delete/setAuthToken`) que detecta `XanoRequestError` com status **401** e dispara o handler global `onUnauthorized` (registrado em `main.ts`). O handler faz `logout()` + redireciona para `/login?expired=1` (ignora rotas guest). `unauthorizedFired` guarda múltiplos 401 em paralelo e é resetado quando um novo token é definido.
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

### Login Google OAuth

Fluxo OAuth no grupo `google-oauth` (URL canônica `8ebaG5ZN`), endpoints **`/api:8ebaG5ZN/oauth/google/init`** e **`/api:8ebaG5ZN/oauth/google/continue`**:

- **`auth.ts`**: `googleLogin()` chama `init` com `redirect_uri = window.location.origin + '/oauth/callback'` → redireciona para `body.authUrl` (Google). `googleCallback(code, redirectUri)` chama `continue` → salva `data.token` (JWT) no localStorage + `setAuthToken` → `fetchMe()`.
- **`LoginView.vue`**: botão "Entrar com o Google" (ícone SVG) abaixo do form.
- **`OAuthCallbackView.vue`** (rota `/oauth/callback`): lê `code` da query, processa (redirect_uri é sempre reconstruído a partir do origin para evitar mismatch), redireciona para `/`; erro → mensagem amigável ("Acesso restrito a usuários previamente autorizados.").
- **Router**: `/oauth/callback` incluída em `guestRoutes` (não exige login).
- **Env vars Xano**: `google_client_id` e `google_client_secret` (a função `google_oauth_getauthurl` lê esses nomes).

### Consumo no `orcamentoStore`

As refs `materiais`, `linhas`, `tipos`, `niveis`, `bordas` agora são **computed** que consomem `useCatalogoStore()`.  
`carregarMateriais()` delega para `catalogo.fetchCatalogo()`.  
`selecionarMaterial()` virou síncrona — apenas seta `materialSelecionado` + `catalogo.selectedMaterialId`.

### Listbox de Variação

Produtos com `detalhe_id > 0` no `produtos_all` têm `_variacao[]`. A store cruza a seleção atual (`material_id`, `linha_id ?? 0`, `tipo_id ?? 0`, `nivel_id ?? 0`) com os produtos e monta `variacoes` (união dos `_variacao`, dedupe por `id`, ordenado por `ordem`).  
`mostrarVariacao` = `variacoes.length > 0`; `watch` limpa `variacaoSelecionada` ao ocultar ou quando sai da lista.  
O `inserirOrcamento()` envia `variacao_id: variacaoSelecionada?.id ?? 0` (antes era `0` fixo). O cálculo (`CalculoValorVenda_IDs`) **não** recebe variação por enquanto.

### `suc` refinado por seleção (`filtrarSuc`)

O `suc` de cada material (Linha/Tipo/Nivel/Borda/Variacao contagens) é usado para mostrar/ocultar dropdowns. O problema: o aggregate `Ret_TabMaeEFilhas_2` conta **todas** as opções do material, sem considerar a linha/tipo já selecionados — ex.: Fibra de Coco (id 50) tem `Nivel=1` porque existe o tipo Personalizado, mas o dropdown de Nível aparecia também para o tipo **Liso**.

Solução: nova função **`Ret_Suc_Filtrado`** + endpoint **`GET /produtos_suc_filtrado?material_id&linha_id&tipo_id`** que repete o aggregate com raiz em `Produto` e filtros condicionais (`==?`) por `linha_id`/`tipo_id`. Sem filtro → mesmas contagens totais; com filtro → contagens restritas à seleção.

- `catalogo.ts`: `sucFiltrado` ref + action `filtrarSuc(materialId, linhaId?, tipoId?)` que chama o endpoint e guarda a resposta.
- `orcamento.ts`: computed `sucAtual` (usa `catalogo.sucFiltrado` se houver, senão `material.suc`) alimenta `mostrarLinha/Tipo/Nivel/Borda`. `watch([linhaSelecionada, tipoSelecionado])` dispara `filtrarSuc`. Limpa `sucFiltrado` em `selecionarMaterial`/`limparMaterial`/`limparFormItem`.

### Nível derivado dos produtos reais (sem exceção hardcoded)

O **conteúdo** da combo de Nível não vem mais de `niveisFiltrados` (só por `material_id`). `niveis` em `orcamento.ts` cruza `catalogo.allProdutos` com a seleção atual (`material_id` + `linha_id`/`tipo_id` quando selecionados), exige `ativo !== false` e `nivel_id > 0`, dedupe por id e ordena pela ordem de `allNiveis`. Assim:

- **Vinil Alto Tráfego Vulcanizado** sem Nível 3 → o produto com `ativo=false` some do `/produtos_all` (backend filtra `$db.Produto.ativo == true` em `fTodos_Produtos`/`Ret_Suc_Filtrado`/`Ret_TabMaeEFilhas_2`) e o dropdown só mostra níveis 1 e 2.
- **Vinil+Liso** → nenhum produto ativo com nível para essa combinação → `niveis` vazio → dropdown some. **A exceção hardcoded foi removida** (`mostrarNivel` agora é `sucAtual.Nivel > 0 && niveis.length > 0`).

### Produtos inativos (flag `ativo`)

A tabela `Produto.ativo` (default `true`) controla se o produto existe na precificação. `fTodos_Produtos` (endpoint `produtos_all`), `Ret_Suc_Filtrado` (`produtos_suc_filtrado`) e `Ret_TabMaeEFilhas_2` (suc base) filtram `$db.Produto.ativo == true`. O `output` de `fTodos_Produtos` inclui `ativo` para o front filtrar defensivamente (protege contra cache antigo até o bump de `versao_produtos`). Para "desativar" um produto, basta setar `ativo=false` no dashboard — ele sai da listbox sem JS nem exceção.

**Borda** segue o mesmo padrão: a tabela `Borda.ativo` é respeitada em `f_produtos_selecao` (catálogo), `Ret_Suc_Filtrado` e `Ret_TabMaeEFilhas_2`, e `bordasFiltradas` filtra `ativo !== false` defensivamente.

### Recálculo dinâmico (resumo tela verde)

O orçamento é **dinâmico**: toda mudança (inserir/remover item, margem, frete B2C, desconto) dispara `Orcamento_Recalcular_Totais` que refaz o **frete B2B sobre o somatório dos custos**, rateia proporcionalmente, aplica markup (efetivo), desconto e frete B2C, e atualiza itens + cabeçalho ORCA. O mínimo do frete B2B vem de **`User.frtB2B`** (`f_calcula_frete` lê `$User1.frtB2B`); o parâmetro morto `seu_frete_minimo: 52` foi removido do `Orcamento_Recalcular_Totais`.

**Simulação de margens (front JS)**: `src/utils/simulacao.ts` — `gerarSimulacaoFront(custo, qtd)` gera a lista (faixa padrão **50–100 passo 10**, rótulos **`c5..c10`** = margem ÷ 10) sem depender do backend (o orquestrador novo não gera `simulacao`; a modal antes nunca abria). `handleSimular` e o botão "Simulação" no Ajustar Orçamento abrem a `SimulacaoModal`; escolher uma linha aplica a margem no resumo (`simularPorMargem`). A modal tem **olho 👁** (`btn-eye`) para mostrar/ocultar custo e lucro (oculto por padrão) e clique na linha mostra condições de pagamento.

**Ajustar Orçamento** (tela verde, `.card-totais` `#f0fdf4`):
- **Nova Margem (%)** → `POST /orcamento_recalcular { newMargem }` (markup **efetivo** — Opção B)
- **Novo Vlr de Venda Total B2B** → `GET /Calc_new_Valor_Venda` → `new_margem` → recalc
- **Novo Lucro Total** → `GET /Calc_new_Valor_Lucro` → `new_margem` → recalc
- **Frete B2C (R$)** → `POST /orcamento_recalcular { frtB2C }` (editável, negociação)
- **Desconto (R$)** → `POST /orcamento_recalcular { desconto }` (editável, reduz markup efetivo)

Fórmulas-chave:
```
cst_tot      = Σ custo_entrada (por item: custo_nota + difal − credito + frete_rateado)
venda_bruta  = Σ [custo_entrada × (1 + markup/100)]
vnd_tot      = venda_bruta − desconto
markup_efetivo = (vnd_tot / cst_tot − 1) × 100   ← exibido no cabeçalho
vnd_B2B_tot  = vnd_tot
vnd_B2B_B2C_tot = vnd_tot + frtB2C
```

O **frete B2B não é editável** (Kapazi automático sobre o somatório). Remover item usa `DELETE /orcamento_item_deletar { item_id }` → recalc.

**Tabela de itens (resumo)**: cada linha mostra **Valor Unit B2B** e **Total B2B** (venda, não custo) — ex.: qtd 20m × `vlr_vnd_unit_b2b` 200.32 = 4006.38. O `itemS` retornado vem do `Orcamento_Recalcular_Totais` (com `Descricao` concatenada Material+Linha+Tipo+Nivel+Borda), **não** do `Orcamento_Detalhes_Function` legado. Cabeçalho = somatório dos totais B2B + custos + `markup_efetivo = (V/C − 1) × 100`.

**M2 (fator de corte)**: o orquestrador chama a função **`f_retorna_fc(comp, larg, fc)`** → `new_comp`/`new_larg` → área real com FC → custo. A lógica inline antiga foi removida.

## Orquestrador de Cálculo (`Orcamento_Orquestrador`)

Nova arquitetura de precificação no Xano (paralela às funções legadas — não altera `Valor_Venda_*`, `f_CalculoValorVenda_IDs`, `Orcamento_Detalhes_Function`).

### Conceitos

- **Markup** (não margem): `venda = custo_entrada × (1 + markup/100)`. Ex.: custo 100, markup 80% → venda 180, lucro 80.
- **`custo_nota`** = custo fábrica + IPI% + IMP% (base para DIFAL — o IPI compõe a base de cálculo do ICMS).
- **DIFAL por regime**: MEI/Simples pagam DIFAL (entra no custo) e não têm crédito; Lucro Real/Presumido não pagam DIFAL na compra para revenda e abatem crédito ICMS (`custo_nota × aliq_inter%`).
- **Frete B2B** (Kapazi) sobre a soma dos `custo_nota`: ≥ R$ 1.000 → R$ 0; ≥ R$ 300 → 10%; < R$ 300 → R$ 52. Rateado **proporcionalmente ao custo_nota** de cada item.

### Funções criadas (workspace OrcaKap, branch v1)

| Função | Papel |
|---|---|
| `Precificar` | Fiscal puro: recebe `custo_nota` + `uf_origem` + `uf_destino` + `regime_empresa` + `eh_importado`, consulta `Aliquotas_icms`, devolve `valor_difal`, `credito_icms`, `perc_difal`, `aliq_inter`, `custo_fiscal` |
| `Orcamento_Orquestrador` | Entrada `object[] itens` (unidade M2/ML/KIT/UND + IDs + dimensões + markup + uf/regime). Faz lookups (Produto, Material, Borda, Tipo_Fator/Fator_de_Corte, Variacao, Organizacao), calcula `custo_nota` por tipo, chama `Precificar` por item, soma → frete → rateio → markup. Saída: `{ itens: [...], totais: {...} }` |
| `Orcamento_Recalcular_Totais` | **Recálculo dinâmico**: lê itens do orçamento, soma custos_nota, refaz frete B2B (Kapazi) sobre o somatório, rateia, aplica markup efetivo (`newMargem` opcional), desconto e frete B2C; atualiza itens + ORCA. Chamado após insert/delete/mudança de markup |
| `Ret_Suc_Filtrado` | Aggregate de `suc` (Linha/Tipo/Nivel/Borda/Variacao) com filtros condicionais por `linha_id`/`tipo_id` — resolve o caso Fibra de Coco Liso vs Personalizado |

### Tabelas

- `Organizacao` ganhou campo `uf?` (UF do fornecedor, ex. "PR" da Kapazi) — usado como `uf_origem` quando o item não informa.
- `Aliquotas_icms` (já existia): `uf`, `aliquota_modal`, `regiao` (SUL_SUDESTE / OUTROS).
- `Regime` ganhou campo `slug?` (`MEI`/`SIMPLES`/`LUCRO_REAL`/`LUCRO_PRESUMIDO`) — o `Precificar` resolve o regime pelo `regime_id` do usuário via lookup na tabela (sem mapeamento no frontend).
- `Fator_de_Corte` ganhou campos `larg_base`, `comp_corte`, `tam_total` (largura base, fator de corte, tamanho total do rolo).
- `Variacao` ganhou campos `fator_de_corte_id` (FK p/ Fator_de_Corte) e `ativo` (bool).
- `item` ganhou campos `vlr_cst_nota` (MP×área/qtd + IPI + IMP + frete B2B — pago à Kapazi) e `vlr_cst_entrada` (vlr_cst_nota + DIFAL − crédito ICMS).

### Contrato de saída por item (unificado)

```
Valor_Custo_Unit, Valor_Venda_Unit, Valor_Lucro_Unit, Valor_Venda_Unit_B2B,
AreaFC, Qtd_Unidades, Valor_Custo_Total, Valor_Venda_Total, Valor_Lucro_Total,
Valor_Venda_Total_B2B, margem, markup,
custo_nota, custo_mp_base, valor_difal, credito_icms, custo_fiscal, custo_entrada,
frete_rateado, vlr_cst_nota, vlr_cst_entrada,
produto_id, detalhe_id, tipo_fator_id, fator_de_corte_id, base_de_calculo, unidade_venda
```

ML extra: `totalMetrosLineares`, `valorMetroLinearConvertido`, `rolosFechados`, `metrosFracionados`, `orientacaoIdeal`, `largura_fixa`.

`totais`: `custo_nota_total, frete_total, difal_total, credito_icms_total, custo_entrada_total, venda_total, lucro_total, qtd_itens`.

### Integração no frontend (novo fluxo)

O endpoint **`POST /orcamento_calcular`** (auth User) encapsula o `Orcamento_Orquestrador`. O `handleCalcular()`/`handleSimular()` da view agora chamam `orcamentoStore.calcularOrquestrador()` em vez do `calcular(false)` legado.

- `auth.ts`: `User.uf` (novo, da tabela User) + `User.regime_id` (FK da tabela Regime). O frontend envia `regime_id`; o backend resolve o slug.
- `orcamento.ts`: refs `areaML`, `resultadoNovo`; computeds `produtoSelecionado`, `unidadeSelecionada` (M2/ML/KIT/UND via **`Base_de_Calculo`**, não `Unidade` — Grama tem Unidade=M2 do custo, mas Base_de_Calculo=ML), `ehML`. Action `calcularOrquestrador()` monta o payload por IDs + dimensões + `uf_destino`/`regime_id` (do perfil) + `markup` e chama `POST /orcamento_calcular`. O `inserirOrcamento()` monta o payload a partir de `resultadoNovo.itens[0]` quando disponível (senão fallback legado por nomes).
- `OrcamentosView.vue`: inputs de dimensão dinâmicos por unidade — ML mostra toggle **Área (m²) / Largura × Comprimento**, UND só quantidade, M2/KIT mostra Largura × Comprimento. Quantidade só para M2/UND. Computeds `itemCalc` e `simulacaoLista` leem o novo formato.
- **ML (custo M2 → ML)**: quando `Produto.Unidade == "M2"` e venda por ML, o orquestrador converte `custo_mp × larg_fixa` (largura do rolo) antes de calcular.
- **ML usa `f_fator_corte_variacao`**: para ML, o orquestrador chama a função `f_fator_corte_variacao(variacao_id)` que cruza `Variacao` com `Fator_de_Corte` (via `fator_de_corte_id`) e devolve `larg_base` (→ `largura_fixa`), `comp_corte` (→ `fator_corte`), `tam_rolo_total` (→ `tam_rolo`). Se a variação estiver inativa (`ativo=false`) ou sem FC, lança `Variação desativada.`
- **Lógica ML exata = `f_Valor_Custo_ML`**: paginação inteligente (2 sentidos), conversão M2→ML, fator de corte, rolos/metros fracionados — incorporada no lambda do orquestrador.
- **`inserirOrcamento()`** envia `vlr_cst_nota`/`vlr_cst_entrada` (do `resultadoNovo.itens[0]`) → `post_item` grava na tabela `item`.

### Pendências

- `user.uf` adicionado à tabela User e à interface TS; `user.regime_id` precisa ser **preenchido no perfil** de cada vendedor (e `user.uf`) para a precificação funcionar. Atualmente o frontend usa fallbacks (`SP`/`regime_id=0`).
- Stub vazia `orcamento_orquestrador` (lowercase, id antigo) ainda existe no workspace — remover manualmente no dashboard.
- O orquestrador aceita `produto_id` opcional (busca direta pelo id); sem ele, faz fallback pelas FKs (material/classificacao/linha/tipo/nivel). Para M2 com `variacao_id`, usa `Variacao.valor_custo` como custo base.
- Migração futura: `f_CalculoValorVenda_IDs` e `Orcamento_Detalhes_Function` passam a usar o orquestrador.

## What's NOT set up

- **No test runner** — Vitest, Cypress, Playwright configs do not exist. If adding tests, create the config files.
- **No ESLint** — lint config was removed from scaffold. If adding linting, create `eslint.config.*` from scratch.
- **No CI** — no `.github/` directory.
- **No `typed-router.d.ts`** — VS Code file-nesting config references it, but it doesn't exist. Generate if needed (Vue Router 5 typegen).
- **No commit hooks** — no Husky or lint-staged.

## Lições aprendidas (erros a evitar)

- **Sempre avaliar TODOS os ramos de um `switch`/dispatcher antes de alterar o contrato de saída.**
  Erro: adicionei `com_medida_exata`/`acrescimo_medida_exata` ao response de `f_valor_custo_m2` e `f_valor_custo_ml`, mas `f_Orcamento_Orquestrador` lê `$mod1.com_medida_exata`/`$mod1.acrescimo_medida_exata` para **todas** as bases de cálculo (`switch` M2/ML/UND/KIT → `$mod1`). `f_valor_custo_und` e `f_valor_custo_kit` não retornam esses campos → `ERROR_FATAL: Unable to locate var: mod1.com_medida_exata` ao precificar UND/KIT. **Regra**: quando o orquestrador (ou qualquer função com dispatch por `Base_de_Calculo`) consumir `$mod1.<campo>`, TODAS as funções de cálculo (M2, ML, UND, KIT) devem retornar esse campo — mesmo que `false`/`0` (medida exata não se aplica a UND/KIT). Antes de dar push, conferir cada branch do switch.

## Conventions

- Composition API with `<script setup lang="ts">` for all components
- Scoped CSS in components (HomeView.vue uses `#42b883` green theme)
- Format before committing: `npm run format`

## Skills

- `.agents/skills/xano-sdk-error-handling/` — como extrair `message` e `payload` reais dos erros da SDK do Xano (usar `err.getResponse().getBody()` em vez de `err.message`)
- `.agents/skills/orcamento-recalculo-flow/` — fluxo dos 4 mecanismos de recálculo (Novo Vlr Venda B2B, Nova Margem, Novo Frete B2B, Novo Lcr Total) com APIs Xano, store Pinia e guardrails
