# Orca Xano Vue — Agent Guide

> **Regra do usuário (2026-08)**: **NÃO fazer `git commit` nem `git push`** — essas ações ficam sempre com o usuário. Implementar/corrigir e deixar as mudanças prontas no working tree, com resumo claro, para o usuário decidir quando commitar/pushar.

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
- `src/router/index.ts` — routes: `/` (HomeView, eager), `/clientes`, `/orcamentos` (lista), `/pedidos`, `/orcamentos/novo` e `/orcamentos/:codOrca` (OrcamentosView), `/login`, `/signup`, `/oauth/callback` e dev tools `/dev/produtos|/dev/fatores|/dev/materiais|/dev/configuracoes` (lazy, só em DEV)
- `src/services/xano.ts` — singleton `XanoClient` do `@xano/js-sdk`, configurado via `VITE_XANO_BASE_URL`. Expõe um **wrapper** (`get/post/put/patch/delete/setAuthToken`) que detecta `XanoRequestError` com status **401** e dispara o handler global `onUnauthorized` (registrado em `main.ts`). O handler faz `logout()` + redireciona para `/login?expired=1` (ignora rotas guest). `unauthorizedFired` guarda múltiplos 401 em paralelo e é resetado quando um novo token é definido.
- `src/stores/catalogo.ts` — `useCatalogoStore`: árvore completa Material/Linha/Tipo/Nivel/Borda + **taxas de banco** (`taxasBanco`, cache por versão), cache localStorage por versão via `/configuracoes`, loaded flag de sessão
- `src/stores/counter.ts` — scaffold example store (not used by any view)
- `.env` contains `VITE_XANO_BASE_URL` (committed — override via `.env.local` for production)
- `src/views/HomeView.vue` fetches from Xano endpoint `/api:-qqRIakp/cliente_user` on mount
- `index.html` `<title>` is still "Vite App" — customize as needed
- `src/components/HelloWorld.vue`, `TheWelcome.vue`, `WelcomeItem.vue`, `icons/*` are unused scaffold boilerplate

## Catálogo de Produtos

`src/stores/catalogo.ts` — store responsável por fornecer a árvore completa de materiais, linhas, tipos, níveis e bordas em uma única chamada de API, com cache persistente por versão. Também carrega as **taxas de banco** (`fetchTaxasBanco()`), usadas no cálculo das condições de pagamento.

### APIs consumidas

- `GET /configuracoes` → `{ configuracoes-mae: [{ versao_materiais: N, versao_produtos: M, versao_taxas_banco: T }] }` — chamada leve (~200 bytes)
- `GET /produtos_para_selecao` → `{ lista_para_selecao: { Material: { material }, Linha, Tipo, Nivel, Borda } }` — árvore de dropdowns
- `GET /produtos_all` → array de produtos com `_variacao[]` (produtos mães, filhos e variações); input zerado traz tudo
- `GET /taxas_banco` → array `[{ id, provedor_id, parcelas, cc_taxa, provedor, ativo }]` — taxas de cartão por instituição (cache `orca_taxas_banco_cache`, versionado por `versao_taxas_banco`)

### Ciclo de vida (`fetchCatalogo()`)

As três partes (árvore de materiais, produtos e taxas de banco) têm caches **independentes** e são baixadas separadamente — só a API cuja versão mudou é chamada (numa primeira carga sem cache, todas são chamadas).

| Etapa | Descrição |
|---|---|
| `loaded` da sessão | Se `true`, retorna imediatamente (0 chamadas de API) |
| `/configuracoes` | Busca `versao_materiais`, `versao_produtos` e `versao_taxas_banco` atuais no servidor (popula `versaoMateriais`/`versaoProdutos`/`versaoTaxasBanco`/`versaoLabel`) |
| Cache materiais (`orca_catalogo_materiais_cache`) | Se `cache.versao === versao_materiais`, popula árvore do cache; senão baixa `/produtos_para_selecao` e salva |
| Cache produtos (`orca_catalogo_produtos_cache`) | Se `cache.versao === versao_produtos`, popula produtos do cache; senão baixa `/produtos_all` e salva |
| Cache taxas (`orca_taxas_banco_cache`) | `fetchTaxasBanco()` — se `cache.versao === versao_taxas_banco`, usa o cache; senão baixa `/taxas_banco` (filtra `ativo !== false`) e salva |
| `loaded = true` | Marca sessão como carregada |

### Badge de versão no header

`GlobalHeader` mostra `versaoLabel` (`M{versao_materiais}P{versao_produtos}T{versao_taxas_banco}`, ex. `M2P1T3`) como um badge clicável que abre um popover com os três valores (Materiais/Produtos/Taxas). Usa `catalogo.carregarConfiguracoes()` (só `/configuracoes`, sem baixar catálogo) no `onMounted`.

### Logout

`authStore.logout()` chama `catalogo.resetarSessao()` — zera `loaded` + `selectedMaterialId` + `taxasLoaded`, forçando revalidação no próximo login.

### Login Google OAuth

Fluxo OAuth no grupo `google-oauth` (URL canônica `8ebaG5ZN`), endpoints **`/api:8ebaG5ZN/oauth/google/init`** e **`/api:8ebaG5ZN/oauth/google/continue`**:

- **`auth.ts`**: `googleLogin()` chama `init` com `redirect_uri = window.location.origin + '/oauth/callback'` → redireciona para `body.authUrl` (Google). `googleCallback(code, redirectUri)` chama `continue` → salva `data.token` (JWT) no localStorage + `setAuthToken` → `fetchMe()`.
- **`LoginView.vue`**: botão "Entrar com o Google" (ícone SVG) abaixo do form.
- **`OAuthCallbackView.vue`** (rota `/oauth/callback`): lê `code` da query, processa (redirect_uri é sempre reconstruído a partir do origin para evitar mismatch), redireciona para `/`; erro → mensagem amigável ("Acesso restrito a usuários previamente autorizados.").
- **Router**: `/oauth/callback` incluída em `guestRoutes` (não exige login).
- **Env vars Xano**: `google_client_id` e `google_client_secret` (a função `google_oauth_getauthurl` lê esses nomes).
- **`prompt=select_account`**: a URL gerada por `google_oauth_getauthurl` inclui `prompt=select_account` → o Google **sempre mostra o seletor de contas** ao clicar em "Entrar com o Google" (permite trocar entre contas Google já cadastradas sem limpar a sessão do Google).
- **Usuário novo via Google**: o `continue` **não cria** o usuário — `db.get User { email }` + `precondition ($user != null)` → rejeita com "Usuário não cadastrado" (acesso restrito). Para usar, **pré-criar** o `User` com o e-mail do Google (via `/signup` ou dashboard); o 1º login Google auto-vincula `google_oauth`.

### Troca de usuário (dev)

- **`DevUserSwitcher.vue`** (novo) + botão **👥** no `GlobalHeader` (só `isDev`): popover que guarda contas de teste em `localStorage` (`orca_dev_usuarios`: `[{ nome, email, senha }]`) com formulário add/remove, botões **"Entrar"** (`authStore.login` + redirect `/`) e **"Sair"** (logout → `/login`). Some do build de produção.
- Troca entre contas Google: fluxo Google com `prompt=select_account` (seletor). Troca por senha: switcher ou logout→login.

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
- `item` ganhou campos `vlr_cst_nota` (MP×área/qtd + IPI + IMP + frete B2B — pago à Kapazi) e `vlr_cst_entrada` (vlr_cst_nota + DIFAL − crédito ICMS). `qtd` é **decimal** (metade fracionada de ML), `detalhes_calculo` (JSON, playkap/ml), `vlr_vnd_unit_bruto`, `com_medida_exata`/`porcentagem_acrescimo`, `fc`, `base_calculo`.

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
- **ML grava `detalhes_calculo.ml`**: `f_valor_custo_ml` retorna `detalhes_calculo: { ml: { totalMetrosLineares, rolosFechados, metrosFracionados, orientacaoIdeal, valor_ml, largura_fixa, tam_rolo, fator_corte, resumoTexto } }` (antes `null`) → o orquestrador expõe (`f_orcamento_orquestrador.xs:409`) e o front envia em `inserirOrcamento` → `post_item` persiste. `composicaoML()`/`composicaoItem()` no `pdf.ts` e cópia na view exibem **rolos/metros fracionados/orientação** na tabela de itens, WhatsApp e PDFs. Ex.: `5 m fracionado — Passar a faixa no sentido do comprimento (3 m)`; com rolos, o total entra na frente (`32,5 m — 3 rolo(s) — 2,5 m fracionado`). **Atenção (lição)**: ML também retorna `detalhes_calculo` no `$mod1` — manter os outros ramos do switch (M2/UND/KIT) com `null`.

### Quantidade decimal (`qtd`)

A coluna `item.qtd` (e o input `quantidade` dos endpoints/funções de cálculo) mudou de **`int` para `decimal`** — itens ML (metros lineares fracionados, ex. `12.5`) persistem sem truncar. Pontos alterados no backend: `table/item.xs`, inputs de `OrcamentoItem_Inserir`/`Atualizar`, `orcamento_calcular`, `f_Orcamento_Orquestrador`, `f_valor_custo_m2`/`_und`, `Orcamento_Orquestrador`. Front: `OrcamentoInsertPayload.qtd` é `number` (não mais `String(...)` no payload), input Quantidade com `step="0.01"`. `qtdCantos` (PLAYKAP) continua `step="1"`.

### Duplicar orçamento

- Backend: `POST /orcamento_duplicar` → `Orcamento/f_DuplicaOrcamento` copia a **Orca** (fretes, validade, margens, `markup_alvo/efetivo`, custos/vendas totais, `desconto`, `mao_de_obra`, `observacao`, `condicoes_pagamento`, `condicoes_pagamento_params`) e os **itens** com todos os campos fiscais + `detalhes_calculo` + `vlr_vnd_unit_bruto` + `fc` — abrindo o duplicado **em modo edição** para ajustar itens/bordas/qtd/dimensões.
- Front: `orcamentoStore.duplicarOrcamento(orcaId)` → `POST /Orcamento_Duplicar` (⚠️ **CamelCase no path**, como `OrcamentoItem_Inserir` — Xano é case-sensitive na URL; `orcamento_duplicar` minúsculo dava 404). Botão "Duplicar" (ícone copy) na listagem de orçamentos (desktop + mobile) → navega para `/orcamentos/{novoCod}`.

### Condições de Pagamento (seletor avançado)

`src/utils/condicoesPagamento.ts` + `src/utils/taxasBanco.ts` (+ `OrcamentosView.vue`):

- **Instituição**: cada opção de cartão mostra o `provedor`; se há >1 instituição na tabela, aparece um seletor de provedor (`provedorSelecionado`). A melhor opção por nº de parcelas (menor custo p/ cliente) ganha ⭐ (`opcoesMaisVantajosas`).
- **Checkboxes Pix/Boleto/Cartão** (`metodosPagamento`) ditam o que entra no texto do "Gerar Condições" (todas marcadas por padrão).
- **Desconto Pix (%)** (`descontoPixPercentual`): reduz a venda e retorna o impacto em **lucro/margem** (`pixImpacto`), exibido na aba Pix. Quando > 0, o texto da condição inclui `— X% de desconto` (ex.: `Pix (2x de R$ 490,00) — 2% de desconto: ...`).
- **Mesclagem**: checkbox `mesclarMetodos` combina os métodos marcados na saída; com cartão e uma parcela escolhida (`cartaoSelecionado` por chave `provedor_id|parcelas`), entra **só a parcela selecionada**, a menos do checkbox `trazerTodasParcelas`.
- **Banco não aparece nos outputs**: o nome do `provedor` é exibido só no seletor (UI); o texto das condições (PDF/WhatsApp/Pedido de Venda) mostra apenas `Cartão de Crédito (Nx de R$ X): total de R$ Y.` — mas o provedor fica **gravado** no estado do seletor.
- **Persistência do estado do seletor**: `condicoes_pagamento` (texto) + `condicoes_pagamento_params` (JSON) são gravados via `orcamento_recalcular`. O JSON guarda `{ metodos, mesclar, trazerTodasParcelas, descontoPixPercentual, provedorId, provedor, parcelas, repassarTaxas, aba }`. Ao reabrir, `restaurarCondicoesParams()` (`sincronizarSimulacao` + watch de `catalogo.taxasBanco`) reaplica os refs; instituição/parcela só voltam se ainda existirem nas taxas atuais. Campo novo na tabela `Orca`; `f_DuplicaOrcamento` copia. `SimulacaoModal` usa o mesmo módulo com defaults.

### Garantia (por material)

A garantia exibida no **PDF do orçamento**, **WhatsApp** e **PDF do Pedido de Venda** vem da tabela **`Material.garantia`** (meses) — **não** é mais um texto fixo. O campo é baixado no catálogo via `f_material_todos` (output de `/produtos_para_selecao`) e precisa de **bump de `versao_materiais`** (dev tool `/dev/configuracoes`) para o cache antigo pegar o campo.

- `src/utils/garantia.ts` — funções puras:
  - `formatarDuracaoGarantia(meses)`: `< 12` → `3 meses contra defeito de fábrica`; `>= 12` inteiro → `1 ano de garantia contra defeito de fábrica`; resto (18) → `1 ano de garantia e 6 meses contra defeito de fábrica`; `0`/nulo → vazio (item pulado).
  - `montarLinhasGarantia(itens, produtos, materiais)`: resolve `item.produto_id → allProdutos[].material_id → Material.garantia`, **dedupe por material** (1 linha por material) e **dedupe por duração** (materiais com a mesma garantia viram 1 linha com nomes agrupados: `Vinil, EVA e Fibra de Coco 1 ano de garantia contra defeito de fábrica`).
- `pdf.ts`: `linhasGarantia(itens)` (usa `useCatalogoStore()`) alimenta o **bloco "Garantia"** no orçamento PDF (seção após Condições), o bloco **`🛡️ *Garantia*`** no WhatsApp e a linha **`Garantia:`** na tabela Condições e Entrega do Pedido de Venda. Bloco/linha **omitidos** quando não há linhas (catálogo vazio ou nenhum material com garantia).

### Pendências

- Stub vazia `orcamento_orquestrador` (lowercase, id antigo) ainda existe no workspace — remover manualmente no dashboard.
- O orquestrador aceita `produto_id` opcional (busca direta pelo id); sem ele, faz fallback pelas FKs (material/classificacao/linha/tipo/nivel). Para M2 com `variacao_id`, usa `Variacao.valor_custo` como custo base.
- Migração futura: `f_CalculoValorVenda_IDs` e `Orcamento_Detalhes_Function` passam a usar o orquestrador.

### Perfil (UF + Regime Tributário) e precificação

A precificação (DIFAL, crédito ICMS, ST) usa `User.uf` + `User.regime_id` (editados em `PerfilModal.vue` → `POST /user/{id}`; `/auth/me` retorna os campos). Sem eles, o backend `Precificar` cai no ramo **Lucro Real/Presumido** (abate crédito ICMS) — **errado** para MEI/Simples. Garantias implementadas:

- **Banner informativo (sem bloqueio)**: `OrcamentosView.vue` — computed `perfilPrecificacaoIncompleto` (`!user.uf || !user.regime_id`) mostra banner no topo com botão "Abrir Meus Dados" (`uiStore.perfilOpen`). **Não bloqueia o cálculo nem abre o modal automaticamente** — o app funciona normal com qualquer usuário; se faltar UF/Regime, o backend usa fallback (`SP`/`regime_id=0`).
- **Consistência por orçamento**: `calcularOrquestrador` (`orcamento.ts`) envia `uf_destino: header?.uf_destino ?? user?.uf ?? 'SP'` e `regime_id: header?.regime_id ?? user?.regime_id ?? 0` — recalcular/adicionar item num orçamento existente usa o regime/UF **gravados na criação** (`Orca.regime_id`/`Orca.uf_destino`, persistidos via `post_orca`), honrando o aviso do modal "mudança só vale para novos orçamentos". `OrcamentoItem_Inserir` é pass-through dos valores fiscais calculados no front (não recalcula regime).

## Controle Financeiro (Frente 6) e Faturamento

Parcelas financeiras na tabela **`Boleto`** com `orca_id` (vínculo no Orçamento/Orca) + `user_id`. **Sem gateway** — controle interno + baixa manual.

- **Backend** (auth User): `pagamentos` (GET, join Orca → `cod_orca`/`eh_pedido`/`cliente_id` e `Forma_Pagamento` → `tipo`; filtro opcional `orca_id`), `pagamento_salvar` (POST, **substitui** as parcelas de uma orca — valida owner), `pagamento_baixa` (POST, marca `pagamento = now` / estorno `null`), `pagamento_excluir` (POST). Forma_Pagamento: 1=Boleto, 2=PIX, 3=Espécie — **"Cartão de Crédito" (id 4) criar manualmente no dashboard** (o POST da forma não grava `tipo`).
- **Front**: `utils/pagamentos.ts` (`FORMAS_PAGAMENTO`, `gerarParcelasFinanceiras`, `nomeForma`), `stores/pagamentos.ts`, `PagamentoModal.vue` (prop `modoFaturamento`), `PagamentosView.vue` (rota `/pagamentos`, menu **"Boletos"** habilitado). Botões **"💳 Financeiro"** e **"Faturar"** na `OrcamentosView`.
- **Faturar = cadastrar parcelas + avançar status**: em `AGUARDANDO_FATURAMENTO` + `eh_pedido`, `faturarComParcelas()` abre o `PagamentoModal` em modo faturamento ("Salvar e Faturar"); `@saved` → `aoSalvarFinanceiro()` → `mudarStatus('FATURADO')`. Pós-conversão os status permitidos são **FATURADO/ENTREGUE/CANCELADO** — reversões e RECUSADO ficam bloqueados (backend `orcamento_status` + botão "Recusar" oculto quando `isVinculado`).
- **Filtros `/pagamentos`**: abas de status (Todos/Em aberto/A vencer/Vencidos/Pagos) — ids alinhados ao `statusParcela` (`em_aberto`/`a_vencer`); **"Em aberto" = todas as NÃO pagas**. Barra de **período**: "Período a partir de" (`type="month"`, default mês atual) + chips Todos os períodos/Mensal/Trimestral/Semestral/Anual — janela pelo `vencimento` a partir do **dia 1º** do mês + 1/3/6/12 meses; **sem limite inferior** (vencidas sempre entram); combina (AND) com a aba de status. Parcela sem vencimento só aparece em "Todos os períodos".
- **Lição de template**: modais/Teleports que precisam abrir nas DUAS visões do `OrcamentosView` (edição `!mostrarResumo` e resumo `v-else`) devem ficar na **raiz** de `.orcamento-page`, fora dos blocos v-if/v-else — o `PagamentoModal` estava dentro do bloco de edição e os botões "Faturar"/"💳 Financeiro" (na visão resumo) setavam o `modelValue` sem modal no DOM → "não abriu nenhum modal". Posição no DOM é irrelevante (Teleport → body); o que importa é o modal estar **montado**.

## Dashboard (Home) com filtro de período (Frente 8)

`dashboard_GET` **reescrito** (sem a função legada `fDadosDashBoard`, que dava números divergentes): inputs `mes_inicio` (YYYY-MM) e `periodo` (`todos|mensal|trimestral|semestral|anual`). Busca Orcas (`status`/`eh_pedido`/`created_at`) e Boletos (`vencimento`/`pagamento`) do usuário e **conta em `api.lambda` (JS)** (evita sintaxe frágil de filtro de data do Xano):
- Orçamentos = não-pedidos com `created_at` na janela `[01/mês, fim)`; Pedidos = `eh_pedido` na janela; funil por status (mesma base).
- Boletos (mesma fonte/regra do `/pagamentos`): **Vencidos** = não pagos `vencimento < hoje` (sempre) · **A vencer** = não pagos `hoje ≤ venc < fim` · **Pagos** = pagos `venc < fim`.
`HomeView.vue` virou dashboard (cards clicáveis + chips do funil que navegam para `/orcamentos?status=`) e tem a barra "Período a partir de" (mês + chips) chamando `/dashboard?periodo&mes_inicio`.

## Cliente no orçamento — cadastro rápido com vínculo automático

Botão **"＋ Novo cliente"** (sempre visível no cabeçalho da seção Cliente, na visão de edição) abre o `ClienteModal` em **modo criação**. O `ClienteModal` agora emite `saved` **com o cliente salvo** (`Partial<Cliente>`; `id` vem do `Cliente_2` no response do POST de criação, ou do `editandoId` no PATCH). `aoSalvarCliente` (`OrcamentosView`) monta o `Cliente` completo e seta `clienteSelecionado` — o novo cliente já fica **vinculado ao orçamento aberto** (próximo Inserir/Calcular/Salvar usa `cliente.id`). Ver dados continua em modo somente leitura (`clienteModalSomenteLeitura`).

## What's NOT set up

- **No test runner** — Vitest, Cypress, Playwright configs do not exist. If adding tests, create the config files.
- **No ESLint** — lint config was removed from scaffold. If adding linting, create `eslint.config.*` from scratch.
- **No CI** — no `.github/` directory.
- **No `typed-router.d.ts`** — VS Code file-nesting config references it, but it doesn't exist. Generate if needed (Vue Router 5 typegen).
- **No commit hooks** — no Husky or lint-staged.

## Lições aprendidas (erros a evitar)

- **Sempre avaliar TODOS os ramos de um `switch`/dispatcher antes de alterar o contrato de saída.**
  Erro: adicionei `com_medida_exata`/`acrescimo_medida_exata` ao response de `f_valor_custo_m2` e `f_valor_custo_ml`, mas `f_Orcamento_Orquestrador` lê `$mod1.com_medida_exata`/`$mod1.acrescimo_medida_exata` para **todas** as bases de cálculo (`switch` M2/ML/UND/KIT → `$mod1`). `f_valor_custo_und` e `f_valor_custo_kit` não retornam esses campos → `ERROR_FATAL: Unable to locate var: mod1.com_medida_exata` ao precificar UND/KIT. **Regra**: quando o orquestrador (ou qualquer função com dispatch por `Base_de_Calculo`) consumir `$mod1.<campo>`, TODAS as funções de cálculo (M2, ML, UND, KIT) devem retornar esse campo — mesmo que `false`/`0`/`null`. Antes de dar push, conferir cada branch do switch.
  **Recorreu (2ª vez)**: ao adicionar `detalhes_calculo` ao response do orquestrador (para o PLAYKAP/COMPOSTO), só o `f_valor_custo_playkap` retornava o campo → M2 quebrou com `Unable to locate var: mod1.detalhes_calculo`. Correção: M2/ML/UND/KIT retornam `detalhes_calculo` (M2/UND/KIT: `null`; **ML passou a retornar `{ ml: {...} }`**). **Sempre conferir TODOS os ramos do switch (agora 5: M2/ML/UND/KIT/COMPOSTO) ao tocar o contrato de saída `$mod1`.**
- **Enum `status` não pode ir no `output` de `db.query` paginado** (`orca_por_cliente_busca` — erro `xdo.orca.cod_orca`). O status vem do endpoint auxiliar `orcamento_status_lista` (db.query simples) e é mesclado por `id` no frontend.
- **Referência de tabela base em `db.query` com join deve ser maiúscula** (`$db.Orca.cod_orca`, `sort = {Orca.created_at: "desc"}`); minúscula (`$db.orca.cod_orca`, `{orca.created_at: ...}`) quebra com `xdo.orca.*`.
- **URLs da API são case-sensitive no Xano**: o path segue o nome da query exatamente (`Orcamento_Duplicar`, `OrcamentoItem_Inserir`, `CalculoValorVenda_IDs`). Chamar `orcamento_duplicar` minúsculo (quando a query é `Orcamento_Duplicar`) dá **404**. Sempre conferir o case do nome da query antes de chamar no front.
- **Eval de `Descricao` com `concat` quebra se usarmos `first_notnull`/parênteses no argumento**: `concat:($db.X.nome|first_notnull:"")` não é aceito pelo XanoScript em `eval` → endpoint 500. Manter o `concat` simples e blindar a descrição no **frontend** (fallback `item.Descricao || item.descricao`).
- **`|default:<var.property>` no `value` de um `var`/`var.update` quebra com `Unable to locate func entry: default`**: em `Precificar`, `var $aliq_st { value = $input.aliq_st_interna |default:$estado_destino.aliquota_modal }` era parseado como chamada de função `default(...)` → erro só em regime ≠ MEI com produto com ST (`tem_st`). Correção: `value = $input.aliq_st_interna` + `conditional { if (!$aliq_st) { var.update $aliq_st { value = $estado_destino.aliquota_modal } } }`. Obs.: `|first_notnull`/`|first_notempty` com propriedade em `db.edit`/`db.add` **funcionam** — o problema é específico do `|default:` no `value` de variável.
- **`xano function run` NÃO é teste válido para chamadas entre funções**: o CLI falha com "Function does not exist: function:<id>" mesmo quando a função chamada existe e o app funciona. Verificar sempre no **app** (ou no teste do próprio Xano no dashboard).
- **Modais/Teleports usados por botões em visões condicionais precisam estar MONTADOS na visão onde o botão está.** A `OrcamentosView` tem duas visões mutuamente exclusivas (edição `<template v-if="!mostrarResumo">` e resumo `<template v-else>`). O `PagamentoModal` foi colocado dentro do bloco de edição, mas os botões "Faturar"/"💳 Financeiro" estão na visão resumo → clicavam, setavam o `modelValue` e nada abria (modal fora do DOM). Correção: mover o modal para a **raiz** de `.orcamento-page`, fora dos dois blocos (posição é irrelevante — Teleport → body). `SimulacaoModal`/`ClienteModal`, que só abrem na edição, podem permanecer dentro do bloco.

## Conventions

- Composition API with `<script setup lang="ts">` for all components
- Scoped CSS in components (HomeView.vue uses `#42b883` green theme)
- Format before committing: `npm run format`

## Skills

- `.agents/skills/xano-sdk-error-handling/` — como extrair `message` e `payload` reais dos erros da SDK do Xano (usar `err.getResponse().getBody()` em vez de `err.message`)
- `.agents/skills/orcamento-recalculo-flow/` — fluxo dos 4 mecanismos de recálculo (Novo Vlr Venda B2B, Nova Margem, Novo Frete B2B, Novo Lcr Total) com APIs Xano, store Pinia e guardrails
