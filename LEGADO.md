# LEGADO — Funções e Endpoints Órfãos

Inventário do que **não faz parte do novo sistema** de precificação/orçamento (`novo-sis`).

> **Status:** `NENHUM` = sem uso no frontend novo; `EM USO` = ainda referenciado; `PARA EXCLUIR` = candidato a exclusão após validação.
> **Regra:** só excluir depois que WhatsApp/PDF/Pedido forem validados com `Orcamento_Detalhes_v2`.

## Funções (Xano)

| Função | Status | Substituída por |
|---|---|---|
| `Orcamento_Detalhes_Function` | PARA EXCLUIR (quebrada: chama `fcalcularPrazo` 214058 inexistente) | `Orcamento_Detalhes_v2` |
| `Orcamento_Detalhes_Function_0_old` | PARA EXCLUIR | `Orcamento_Detalhes_v2` |
| `orcamento_orquestrador` (lowercase, stub antiga) | PARA EXCLUIR | `f_Orcamento_Orquestrador` |
| `fcalcularPrazo` | PARA EXCLUIR (referência quebrada) | `Orcamento_Detalhes_v2` (prazo fixo) |
| `Valor_Venda_M2` | PARA EXCLUIR | orquestrador (`f_Orcamento_Orquestrador`) |
| `Valor_Venda_ML` / `Valor_Venda_ML_old` | PARA EXCLUIR | orquestrador |
| `Valor_Venda_Kit` | PARA EXCLUIR | orquestrador |
| `Valor_Venda_Unidade` | PARA EXCLUIR | orquestrador |
| `Valor_Venda` | PARA EXCLUIR | orquestrador |
| `Valor_Venda_M2_teste` | PARA EXCLUIR | orquestrador |
| `valor_custo_m2_old` | PARA EXCLUIR | `f_valor_custo_m2` |
| `valor_custo_kit_old` | PARA EXCLUIR | `f_valor_custo_kit` |
| `valor_custo_und_old` | PARA EXCLUIR | `f_valor_custo_und` |
| `Marguem_Multiplicadora` | PARA EXCLUIR | orquestrador |
| `Valores_totais_Orcamento` | PARA EXCLUIR | `Orcamento_Recalcular_Totais` |
| `Calc_Nova_Venda_qual_Margem` | PARA EXCLUIR | conversão em memória (frontend) |
| `Calc_Novo_Lucro_qual_Marguem` | PARA EXCLUIR | conversão em memória (frontend) |
| `calcular_precificacao` | PARA EXCLUIR | orquestrador |
| `calculo_valor_venda` | PARA EXCLUIR | orquestrador |
| `f_calculo_valor_venda_ids` | PARA EXCLUIR | orquestrador |
| `f_modulo_calcula_valor_venda` | PARA EXCLUIR | orquestrador |
| `External API PDF` | PARA EXCLUIR (CraftMyPDF aposentado) | PDF no frontend (`src/services/pdf.ts`) |
| `fpdf_teste` | PARA EXCLUIR (teste) | — |
| `Item_alterar_margem` | EM USO (via `orca_change`) | revisar |
| `post_orca` | EM USO (via `OrcamentoItem_Inserir`) | revisar |
| `post_item` | EM USO (via `OrcamentoItem_Inserir`) | revisar |
| `orca_change` | EM USO (via `orca/{orca_id}` POST) | já sem `pedido_id` |
| `pedido_func` | PARA EXCLUIR após migração | fusão Pedido → Orca |

## Endpoints (Xano)

| Endpoint | Status | Substituído por |
|---|---|---|
| `Orcamento_Detalhes` GET | PARA EXCLUIR (quebrado) | `orca_por_codigo` + `orcamento_recalcular` |
| `Orcamento_Detalhes_OLD` GET | PARA EXCLUIR | acima |
| `CriarOrcamentoPdf` POST | PARA EXCLUIR (CraftMyPDF) | PDF no frontend (`src/services/pdf.ts`) |
| `Calc_new_Valor_Venda` GET | PARA EXCLUIR | simulação em memória (frontend) |
| `Calc_new_Valor_Lucro` GET | PARA EXCLUIR | simulação em memória (frontend) |
| `calculo_valor_venda_ids` GET | PARA EXCLUIR | orquestrador |
| `calculo_valor_venda_ids_2` GET | PARA EXCLUIR | orquestrador |
| `calculo_valor_venda_kit` GET | PARA EXCLUIR | orquestrador |
| `calculo_valor_venda_ml` GET | PARA EXCLUIR | orquestrador |
| `calculo_valor_venda_und` GET | PARA EXCLUIR | orquestrador |

## Endpoints novos (`novo-sis`)

| Endpoint/Função | Papel |
|---|---|
| `orca_por_codigo` GET | resolve `cod_orca → id` (substitui o `Orcamento_Detalhes` no fluxo de edição) |
| `Orcamento_Detalhes_v2` | contrato consolidado p/ WhatsApp/Pedido (consome `Orcamento_Recalcular_Totais`) |

## Próximos passos
1. Validar edição de orçamento (ORC12439 abre com cliente/descrição/negociação)
2. Validar WhatsApp com `Orcamento_Detalhes_v2`
3. ~~Gerar PDF no frontend (pdfmake)~~ → feito (`src/services/pdf.ts`; `/auth/me` expõe `_telefones`; `orca_detalhes` expõe `_enderecos`)
4. ~~Fusão Pedido → Orca~~ → feito (status estendido + `orcamento_converter_pedido` + `Orca_Status_Log` + trava de edição)
5. **Rodar `MigrarPedidosParaOrca` no dashboard** (marca as 83 Orcas vinculadas como `eh_pedido`) e depois **dropar** `Pedido`/`item_ped`/`controle_pedido` + funções/endpoints legados (`pedido_func`, `item_ped_func`, `PedidoItem_Inserir`, `pedido/*`, `controlepedido/*`, addons `boleto_of_pedido`) e a coluna `orca.pedido_id`
6. Excluir os itens `PARA EXCLUIR` no dashboard

## Notas (`mao_de_obra` / `observacao` / `condicoes_pagamento`)
- Tabela `Orca` ganhou `mao_de_obra` (soma apenas no Total Geral `vnd_B2B_B2C_tot`, não altera lucro/margem), `observacao` (texto livre, impresso no final do PDF) e `condicoes_pagamento` (texto salvo de Pix/Boleto/etc., exibido no PDF/WhatsApp).
- `Orcamento_Recalcular_Totais` e `orcamento_recalcular` aceitam/persistem os três; `OrcamentoItem_Inserir`/`post_orca` gravam a observação na criação.
- Campo "Condições de Pagamento" na área "Ajustar Orçamento" (junto das Observações) — prefill com o valor salvo ou calculado (`calcularCondicoesPagamento`), salvo no Aplicar via `recalcularTotais({ condicoesPagamento })`.
- **Edição antes do envio**: na tela finalizada e na área Ajustar, "Condições de Pagamento" é textarea editável (ref `condicoesPagamento`) com botões **"Gerar Condições"** (calcula Pix 2x + Boleto; pergunta antes de sobrescrever conteúdo existente) e **"Salvar Condições"** (persiste via `recalcularTotais`). O campo inicia em branco ou com o valor salvo (sem prefill). Ao clicar **WhatsApp**/**Gerar PDF**: campo vazio → calcula e salva; campo alterado vs salvo → pergunta se salva antes de enviar; caso contrário usa o salvo. Precedência: **override editado → salvo na ORCA → calculado (fallback)** — nunca sobrescreve conteúdo salvo.
- PDF: nome `{codOrca}_{contato}-{fantasia/razao}_{dd-MM-yyyy HH-mm-ss}_.pdf`, logo `src/assets/logo.png` (embutido via `?inline`), cabeçalho duplo (logo+emissora | card ORÇAMENTO Nº), dados do cliente em quadro cinza, tabela de itens zebrada (medidas zeradas → "Tamanho Padrão"), resumo financeiro à direita, condições comerciais em 2 colunas (pagamento + prazos, sem emoji, com `columnGap: 24`), observações em tópicos numerados e rodapé com contatos + endereço (`_endereco_user`) + "Página X de Y".
- PDF/WhatsApp — totais: **Subtotal = Σ (bruto × qtd) da tabela**; **Total Geral = Subtotal − Desconto + Frete B2C + Mão de Obra**. Medidas sanitizadas sem `$` (`valorNumericoLimpo`). Endereço do rodapé no padrão "Rua, nº X - Bairro - Cidade/UF - CEP: XXXXX-XXX".
- **Auditoria / desconto**: o backend `Orcamento_Recalcular_Totais` grava no `item` o **`vlr_vnd_unit_bruto`** (preço cheio antes do desconto = custo_entrada × (1 + markup_alvo/100)) e na `Orca` os campos **`venda_bruta_tot`**, **`markup_efetivo`** e **`markup_alvo`**. O PDF/WhatsApp leem o `vlr_vnd_unit_bruto` pronto da linha (fallback: recalcula com custo × markup alvo) e mostram o preço cheio na tabela + Desconto em linha separada — só há divergência margem efetiva vs alvo quando há desconto.
- WhatsApp: botão na tela finalizada e na listagem; mensagem montada no frontend (`montarTextoWhatsApp`) com emojis (📋📌↳💳📝📎), negrito nativo `*...*`, condições de pagamento (campo salvo ou fallback), "Frete: R$ X"/"Frete: Grátis" (sem B2C), linhas de Desconto/Frete/Mão de Obra só quando > 0 (Frete sempre presente); telefone do cliente com `tipo_telefone_id == 1` (addon `Telefone_Cliente_of_Cliente` no `orca_detalhes`).
- WhatsApp **copiar + colar** (`copiarEabrirWhatsApp` em `pdf.ts`): o `wa.me?text=` perde emojis de 4 bytes (📋📌💳📝📎 → ``) em alguns clientes (o ↳, 3 bytes, renderiza). Solução: **Web Share API SÓ em mobile** (`ehDispositivoMovel()` + `navigator.share`, texto nativo); **desktop**: copia a mensagem (`navigator.clipboard` com fallback `execCommand('copy')`) e abre `wa.me/<numero>` **sem** texto — o `navigator.share` no desktop abriria a caixa do SO sem WhatsApp; toast temporário avisa "cole na conversa (Ctrl+V)". Fallback: se não copiar, abre com o texto na URL. Retorno: `'shared' | 'copied' | 'failed'`.
- WhatsApp itens: `descricao.trim()` (o `concat` do backend deixa espaços finais que quebram o negrito `*...*` do WhatsApp a partir do item 4); item em 2 linhas (📌 nome / • métricas) com **linha em branco entre itens**.
- Campo "Observações do Orçamento" movido para o card "Ajustar Orçamento" (abaixo do botão Aplicar); botão Aplicar na cor primária.
- Margem (alvo) movida para a parte oculta (só com o olho); "Diferença Total c/ B2C" (preview simulado − total atual) no preview da negociação (oculto).
- Status do orçamento: enum completo **RASCUNHO → ENVIADO → AGUARDANDO_RETORNO → APROVADO → AGUARDANDO_FATURAMENTO → FATURADO → ENTREGUE** (+ RECUSADO/CANCELADO como alternativas). Endpoints: `orcamento_status` (POST, muda status + grava auditoria) e `orcamento_status_lista` (GET, para mesclar na listagem). Badges na finalizada + listagem. **Reversão**: AGUARDANDO_RETORNO/ENVIADO → RASCUNHO; APROVADO/RECUSADO/CANCELADO → AGUARDANDO_RETORNO; ENTREGUE/RECUSADO/CANCELADO são terminais. **Modal de confirmação** (Teleport) antes de cada mudança; RECUSADO/CANCELADO pedem **motivo** (opcional), que vai para `motivo_recusa` da Orca e para o log.
- **Fusão Pedido → Orca**: a tabela `Pedido`/`item_ped` foi **substituída** por marcar a própria Orca (`eh_pedido = true` + status `AGUARDANDO_FATURAMENTO`). Novo endpoint **`orcamento_converter_pedido`** (POST): exige `status == APROVADO` e `eh_pedido != true`, grava `eh_pedido` + status + auditoria. **Trava de edição no backend**: `orca_change`, `orcamento_recalcular`, `OrcamentoItem_Inserir` e `orcamento_item_deletar` recusam (`badrequest`) quando `eh_pedido == true`. No frontend, `isVinculado = orcamentoHeader.eh_pedido === true` e a tela finalizada mostra badge "Somente Leitura"; botão "Converter em Pedido" aparece só em APROVADO, e "Faturar"/"Entregar" quando `eh_pedido`. `post_orca`/`orca_change`/`orca_id_POST`/`f_DuplicaOrcamento` não escrevem mais `pedido_id`; coluna `pedido_id` da Orca ainda existe (legado) — remover após migração.
- **Trava de edição — guard de nulo (fix)**: a trava não pode acessar `$X.eh_pedido` quando a Orca é `null` (1º item de orçamento novo em `OrcamentoItem_Inserir` gerava 500 `Unable to locate var`). Padrão: `var $pedidoBloqueado {false}` + `conditional if ($X != null) { var.update $pedidoBloqueado { ($X.eh_pedido == true) } }` + `precondition ($pedidoBloqueado != true)`. Aplicado nos 4 endpoints. Em `OrcamentoItem_Inserir` o `Orca_0` é resolvido por **precedência**: `orca_id` (2º+ item / edição) > `cod_orca` (1º item, cria) — `cod_orca` não é indexado; o frontend envia `orca_id` via `orcaIdAtual` sempre que o orçamento já existe.
- **Auditoria de status (`Orca_Status_Log`)**: tabela append-only com `orca_id`, `status` (destino), `status_anterior`, `user_id` (quem), `motivo`, `created_at`. Escrita por `orcamento_status` e `orcamento_converter_pedido`. Endpoint **`orcamento_status_historico`** (GET) retorna por `orca_id` (mais recente primeiro); a tela finalizada mostra timeline ("Histórico de Status"). Servirá para relatórios de funil/apontamentos.
- **Migração legado**: função `MigrarPedidosParaOrca` (one-off) — para cada `Pedido`, acha a Orca por `cod_orca`, grava `eh_pedido=true` + mapeia status (AGUARDANDO_FATURAMENTO/FATURADO/ENTREGUE/CANCELADO) + auditoria. **Rodar no dashboard UMA vez** antes de dropar `Pedido`/`item_ped`/`controle_pedido` e os endpoints/funções legados (`pedido_func`, `item_ped_func`, `PedidoItem_Inserir`, `pedido/*`, `controlepedido/*`). `fDadosDashBoard` conta `eh_pedido != true` (orçamentos) e `eh_pedido == true` (pedidos).
- Layout da tela finalizada: badge de status fixo em cabeçalho dedicado (`.status-top`); subseção "Ações de Status" (`.status-section`) com os botões de transição (Enviar/Aprovar/Converter em Pedido/Faturar/Entregar/Recusar/Cancelar/reversões); timeline "Histórico de Status"; barra de ferramentas no rodapé (`.resumo-toolbar`) com Novo Orçamento / Faturar para cliente / WhatsApp / Gerar PDF. Condições de Pagamento + Observações são **read-only** na finalizada — a edição (com Gerar/Salvar Condições) fica só na área "Ajustar Orçamento", e `handleFinalizar` persiste tudo via `persistirCondicoesPagamento`.
- Botões: `.btn-sm`/`.btn-lg` ajustam **apenas tamanho** (padding/fonte) — não sobrescrevem cor/fundo das variantes `.btn-primary/.btn-secondary/.btn-outline/.btn-danger-outline/.btn-whatsapp` (bug antigo: ordem de declaração fazia `.btn-sm` "branco" sobrepor o primário).
- **Listagem de Pedidos (`/pedidos`)**: página dedicada `PedidosView.vue` (não reusa a lista de orçamentos). Busca com **`so_pedidos: true`** no `orca_por_cliente_busca` (filtro backend `$db.Orca.eh_pedido == true`) + status mesclado via `orcamento_status_lista` + **filtro client-side por status** (AGUARDANDO_FATURAMENTO/FATURADO/ENTREGUE/RECUSADO/CANCELADO — APROVADO é pré-pedido, não aparece). Colunas: Código, Cliente, Contato, CNPJ/CPF, Total Venda, Total c/ B2C, Data Envio, Status, Ações (Ver/PDF/WhatsApp). "Ver" abre a mesma tela `/orcamentos/:codOrca` (Somente Leitura). Output do `orca_por_cliente_busca` ganhou `data_envio`/`data_aprovacao`/`total_itens`/`mao_de_obra`.
- **Separação Orçamentos × Pedidos**: `orca_por_cliente_busca` ganhou **`somente_orcamentos`** (filtro `eh_pedido != true`); a lista de Orçamentos passa `somente_orcamentos: true` e **removeu o selo "Vinculado"** (desktop + mobile) — toda linha é acionável (Editar/PDF/WhatsApp/Excluir). Pedidos saem da lista de orçamentos e ficam só em `/pedidos`.
- **Resumo da tela finalizada**: adicionados **Custo Kapazi** (Σ `vlr_cst_nota_unit × qtd`, com fallback `vlr_custo` para dados antigos), **Mão de Obra** e **Margem Real** (2 casas, `margemRealResumo`) — os dois primeiros já existiam como computed, só não apareciam no resumo. Busca de clientes/orçamentos ignora acento via `unaccent` no `where` do Xano (`cliente_user_busca` já usava `normalize('NFD')` no lambda JS).
- **Pedido abre read-only (finalizada)**: no `onMounted` da `OrcamentosView`, se `isVinculado` (eh_pedido) → `mostrarResumo = true` — o pedido abre direto na tela finalizada (3 campos + itens sem lápis/lixeira + seção Kapazi + histórico). Orçamento comum abre na tela de edição.
- **Voltar com origem**: `editarOrcamento(row, origem)` navega com `?origem=pedidos` (PedidosView) ou `?origem=orcamentos` (OrcamentosListView); `voltarLista()` lê `route.query.origem` → `'pedidos'` → `/pedidos`, senão → `/orcamentos`.
- **Trava de recálculo**: `Orcamento_Recalcular_Totais` agora bloqueia (`badrequest`) quando `eh_pedido == true` (padrão `pedidoBloqueado` null-safe) — pedido convertido (incl. os 83 migrados) **não pode ser recalculado**, nem pela UI nem manualmente. Decisão: histórico antigo fica como está (não corrigir DIFAL/margem dos 83).
- **Perfil do usuário (modal no header)**: o bonequinho no `GlobalHeader` abre `PerfilModal.vue` — edita nome/sobrenome, empresa (razao/fantasia/cnpj/ie/cpf/isPJ), UF (obrigatória), regime, frete B2B, margem e dias de validade. **Email é read-only** (se `google_oauth`, mostra "Conectado via Google"). Regime é select dinâmico via `GET /regime` (fallback `regimeMap`); **trocar regime pede confirmação** ("orçamentos anteriores mantêm o cálculo fiscal; só vale para novos"). Salva via `POST /user/{user_id}` → `fetchMe()`. Backend: `user_id_POST` ganhou **`uf`** (precondition obrigatória) e trocou `first_notempty`→`first_notnull` nos numéricos (`frtB2B`, `margem`) para **0 persistir**. **2ª fase**: telefone/endereço do usuário, logo, troca de email com verificação.
- **Desconto Kapazi (`ControlePedido.desconto_kapazi_perc`)**: desconto concedido pela fábrica sobre o custo, em % (base = Σ `vlr_cst_nota_unit × qtd`). Só **aumenta o lucro**, não altera a venda. `controle_pedido_salvar` grava; na finalizada o resumo mostra linhas **derivadas** (não persistidas) quando `desconto_kapazi_perc > 0`: **Custo Kapazi efetivo** (`custoKapaziTotal − desconto`), **Lucro Real (c/ desconto)** (`luc_tot + desconto`) e **Margem Real (c/ desconto)** (`(luc_tot + desconto)/vnd_tot × 100`, 2 casas). **Decisão de arquitetura (Opção A)**: desconto fica como **metadado**; o **relatório** (futuro) deve calcular `lucro_real = luc_tot + (custoKapazi × perc/100)` — **não** assar no banco nem recalcular os 83. Campo preenchível em APROVADO (novas) ou no pedido read-only (legado, junto de nota/nº pedido venda/frete).
- **Dados para Kapazi (`ControlePedido`)**: tabela `ControlePedido` ganhou FK **`orca_id`** (mantém `pedido_id` legado) + campos do fluxo da fábrica (ordem lógica): `data_envio_fabrica`, `num_pedido_fabrica`, `data_aprovacao_layout`, `num_pedido_venda`, `num_nf`, `forma_pagamento_fabrica` (boleto/acerto CC/Pix), `cod_rastreio` (+ reusa `transportadoraB2B/B2C`, `dataPrevisao`, `dataChegada`, `freteB2BReal/B2CReal`). Endpoints novos: **`controle_pedido_por_orca`** GET e **`controle_pedido_salvar`** POST (upsert por `orca_id` — fora da trava de edição, então pedido pode editar esses campos). `orcamento_converter_pedido` agora **exige `num_pedido_fabrica` preenchido** (badrequest) antes de virar pedido. Tela finalizada/APROVADO ganhou seção **"Dados para Kapazi (Fábrica)"**.
- **Fluxo de status (Kapazi)**: RASCUNHO → AGUARDANDO_RETORNO → APROVADO (cliente aprova) → vendedor envia à fábrica e registra `num_pedido_fabrica`/datas (manual) → **Converter em Pedido** = AGUARDANDO_FATURAMENTO → Kapazi emite NF+boletos, vendedor registra (`num_nf`, acerto) e clica **Faturar** = FATURADO → recebe e **Entregar** (com `cod_rastreio`) = ENTREGUE. SAC = tabela própria futura (não engessar); automação Kapazi futura.
- **Tema claro/escuro + identidade Azul/Laranja (Fases 1-3 ✅)**: tokens semânticos em `main.css` (`:root` claro + `:root[data-theme='dark']` sem preto/branco puros: dark usa `#0f172a`/`#1e293b`/texto `#f8fafc`/`#94a3b8`). Azul `--primary` (#1e40af claro / #3b82f6 escuro), laranja `--accent` (#f97316 / #fb923c) só em CTA. `index.html` tem script anti-flash (lê `localStorage('orca_theme')`, fallback `prefers-color-scheme`); `stores/ui.ts` ganhou `tema`/`alternarTema`; botão sol/lua no `GlobalHeader`; header/sidebar navy (`--header-bg`/`--sidebar-bg`). `section-title` virou barra lateral gradiente azul→laranja; `card-totais` saiu do verde → `--primary-soft`; badges de status usam tokens soft (`--success-soft` etc.). **Fase 2 ✅**: `ClienteModal`, `PerfilModal`, `SimulacaoModal`, `ClientesView` migrados (CTA laranja em Alterar/Inserir, Salvar, Novo Cliente). **Fase 3 ✅**: `LoginView`/`SignupView`/`OAuthCallbackView` migrados — verde `#42b883` do scaffold removido, botões `--primary`, inputs/cards com `--input-bg`/`--card-bg`, `var(--color-*)` legados eliminados. Headers de tabela das 3 listas (Clientes/Orçamentos/Pedidos) em `--primary` com texto branco; CTA "+ Novo Orçamento" em laranja. **Retoques finais ✅**: `ClientesView` teve os restos de cor do scaffold convertidos (`#2c3e50`/`#7f8c8d`/`#f5f5f5`/`#eee`/`#fecaca`/`#b91c1c`/`#ff4d4d` → tokens) — corrige legibilidade no dark. **Scaffold morto removido**: `HelloWorld`, `TheWelcome`, `WelcomeItem`, `icons/*`, `AboutView` + rota `/about`, `stores/counter.ts`.
- Listagem: o enum `status` **não pode** ir no `output` de `db.query` paginado (`orca_por_cliente_busca` — erro `xdo.orca.cod_orca`). O status vem do endpoint auxiliar `orcamento_status_lista` (db.query simples) e é mesclado por `id` no frontend.
- Referência de tabela base em `db.query` com join deve ser **maiúscula** (`$db.Orca.cod_orca`, `sort = {Orca.created_at: "desc"}`); minúscula (`$db.orca.cod_orca`, `{orca.created_at: ...}`) quebra com `xdo.orca.*`. `orca_por_cliente_id` (sort) e `orca_id_user` (where `$db.orca.cod_orca` + sort) ainda usam minúsculo (legado, não usados pelo frontend novo) — corrigir ao migrar.
