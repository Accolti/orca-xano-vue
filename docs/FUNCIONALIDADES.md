# Funcionalidades — Estado Atual do Sistema

Documento vivo com o **comportamento vigente** do sistema (orçamentos/pedidos, precificação, Kapazi, tema, etc.). Referências a arquivos/linhas apontam o local do código. Para histórico/migração, ver [`LEGADO.md`](../LEGADO.md); para o roteiro de ideias, [`ROADMAP.md`](../ROADMAP.md).

> **Convenção**: mudou um comportamento? Atualize a seção correspondente aqui (e a lição em `AGENTS.md`), não no LEGADO.

---

## Orçamento & negociação

- Tabela `Orca` ganhou `mao_de_obra` (soma apenas no Total Geral `vnd_B2B_B2C_tot`, não altera lucro/margem), `observacao` (texto livre, impresso no final do PDF) e `condicoes_pagamento` (texto salvo de Pix/Boleto/etc., exibido no PDF/WhatsApp).
- `Orcamento_Recalcular_Totais` e `orcamento_recalcular` aceitam/persistem os três; `OrcamentoItem_Inserir`/`post_orca` gravam a observação na criação.
- Campo "Condições de Pagamento" na área "Ajustar Orçamento" (junto das Observações) — prefill com o valor salvo ou calculado (`calcularCondicoesPagamento`), salvo no Aplicar via `recalcularTotais({ condicoesPagamento })`.
- **Edição antes do envio**: na tela finalizada e na área Ajustar, "Condições de Pagamento" é textarea editável (ref `condicoesPagamento`) com botões **"Gerar Condições"** (calcula Pix 2x + Boleto; pergunta antes de sobrescrever conteúdo existente) e **"Salvar Condições"** (persiste via `recalcularTotais`). O campo inicia em branco ou com o valor salvo (sem prefill). Ao clicar **WhatsApp**/**Gerar PDF**: campo vazio → calcula e salva; campo alterado vs salvo → pergunta se salva antes de enviar; caso contrário usa o salvo. Precedência: **override editado → salvo na ORCA → calculado (fallback)** — nunca sobrescreve conteúdo salvo.
- Campo "Observações do Orçamento" no card "Ajustar Orçamento" (abaixo do botão Aplicar); botão Aplicar na cor primária.
- Margem (alvo) na parte oculta (só com o olho 👁); "Diferença Total c/ B2C" (preview simulado − total atual) no preview da negociação (oculto).
- **Coerência da tela de Valores**: seção "Valores" mostra **apenas "Valor Venda Total"** (o que o cliente paga, com frete B2B embutido) — sem linhas redundantes (Unit/Unit B2B/Tot B2B exibiam o mesmo valor). **Detalhamento Financeiro** na **ordem do cálculo** (Cst Mat Prima → Cst Borda → IPI → Cst Nota → ST → DIFAL → Crédito ICMS → Cst Fiscal → Frete B2B → Cst Entrada → Margem → Margem Real → Alíq Inter/Interna → % DIFAL → Metros Lineares se ML → Custo Unit/Total → Venda Unit/Total (c/ Frete B2B) → Lucro Unit/Total) com campos de valor 0 **sempre visíveis** (R$ 0,00) para conferência. `vlr_vnd_unit`/`vlr_vnd_unit_b2b` continuam iguais (mesmo preço com frete embutido) — decisão: **não separar** Unit/B2B no cálculo.

### Recálculo dinâmico (resumo tela verde)

O orçamento é **dinâmico**: toda mudança (inserir/remover item, margem, frete B2C, desconto) dispara `Orcamento_Recalcular_Totais` que refaz o **frete B2B sobre o somatório dos custos**, rateia proporcionalmente, aplica markup (efetivo), desconto e frete B2C, e atualiza itens + cabeçalho ORCA. O mínimo do frete B2B vem de **`User.frtB2B`** (`f_calcula_frete` lê `$User1.frtB2B`); o parâmetro morto `seu_frete_minimo: 52` foi removido do `Orcamento_Recalcular_Totais`.

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

### Simulação de margens (front JS)

`src/utils/simulacao.ts` — `gerarSimulacaoFront(custo, qtd)` gera a lista (faixa padrão **50–100 passo 10**, rótulos **`c5..c10`** = margem ÷ 10) sem depender do backend (o orquestrador novo não gera `simulacao`; a modal antes nunca abria). `handleSimular` e o botão "Simulação" no Ajustar Orçamento abrem a `SimulacaoModal`; escolher uma linha aplica a margem no resumo (`simularPorMargem`). A modal tem **olho 👁** (`btn-eye`) para mostrar/ocultar custo e lucro (oculto por padrão) e clique na linha mostra condições de pagamento.

## PDF & WhatsApp

- **Auditoria / desconto**: o backend `Orcamento_Recalcular_Totais` grava no `item` o **`vlr_vnd_unit_bruto`** (preço cheio antes do desconto = custo_entrada × (1 + markup_alvo/100)) e na `Orca` os campos **`venda_bruta_tot`**, **`markup_efetivo`** e **`markup_alvo`**. O PDF/WhatsApp leem o `vlr_vnd_unit_bruto` pronto da linha (fallback: recalcula com custo × markup alvo) e mostram o preço cheio na tabela + Desconto em linha separada — só há divergência margem efetiva vs alvo quando há desconto.
- PDF: nome `{codOrca}_{contato}-{fantasia/razao}_{dd-MM-yyyy HH-mm-ss}_.pdf`, logo `src/assets/logo.png` (embutido via `?inline`), cabeçalho duplo (logo+emissora | card ORÇAMENTO Nº), dados do cliente em quadro cinza, tabela de itens zebrada (medidas zeradas → "Tamanho Padrão"), resumo financeiro à direita, condições comerciais em 2 colunas (pagamento + prazos, sem emoji, com `columnGap: 24`), observações em tópicos numerados e rodapé com contatos + endereço (`_endereco_user`) + "Página X de Y".
- **PDF Pedido de Venda**: `gerarPdfPedidoVenda` + `nomeArquivoPedidoVenda` em `src/services/pdf.ts` (A4 retrato: cabeçalho logo+dados, CLIENTE/INFORMAÇÕES GERAIS em 2 colunas, Condições e Entrega, tabela de itens com DESCONTO/FRETE/TOTAL — linha TOTAL sem `colSpan` para evitar "a cell is undefined"; botões em PedidosView e OrcamentosView quando `isVinculado`; ação em `useOrcamentosListActions` com alias `gerarPdfPedidoVendaDoc`).
- PDF/WhatsApp — totais: **Subtotal = Σ (bruto × qtd) da tabela**; **Total Geral = Subtotal − Desconto + Frete B2C + Mão de Obra**. Medidas sanitizadas sem `$` (`valorNumericoLimpo`). Endereço do rodapé no padrão "Rua, nº X - Bairro - Cidade/UF - CEP: XXXXX-XXX".
- WhatsApp: botão na tela finalizada e na listagem; mensagem montada no frontend (`montarTextoWhatsApp`) com emojis (📋📌↳💳📝📎), negrito nativo `*...*`, condições de pagamento (campo salvo ou fallback), "Frete: R$ X"/"Frete: Grátis" (sem B2C), linhas de Desconto/Frete/Mão de Obra só quando > 0 (Frete sempre presente); telefone do cliente com `tipo_telefone_id == 1` (addon `Telefone_Cliente_of_Cliente` no `orca_detalhes`).
- WhatsApp **copiar + colar** (`copiarEabrirWhatsApp` em `pdf.ts`): o `wa.me?text=` perde emojis de 4 bytes (📋📌💳📝📎 → ``) em alguns clientes (o ↳, 3 bytes, renderiza). Solução: **Web Share API SÓ em mobile** (`ehDispositivoMovel()` + `navigator.share`, texto nativo); **desktop**: copia a mensagem (`navigator.clipboard` com fallback `execCommand('copy')`) e abre `wa.me/<numero>` **sem** texto — o `navigator.share` no desktop abriria a caixa do SO sem WhatsApp; toast temporário avisa "cole na conversa (Ctrl+V)". Fallback: se não copiar, abre com o texto na URL. Retorno: `'shared' | 'copied' | 'failed'`.
- WhatsApp itens: `descricao.trim()` (o `concat` do backend deixa espaços finais que quebram o negrito `*...*` do WhatsApp a partir do item 4); item em 2 linhas (📌 nome / • métricas) com **linha em branco entre itens**.

## Fluxo de status

- Enum completo **RASCUNHO → ENVIADO → AGUARDANDO_RETORNO → APROVADO → AGUARDANDO_FATURAMENTO → FATURADO → ENTREGUE** (+ RECUSADO/CANCELADO como alternativas). Endpoints: `orcamento_status` (POST, muda status + grava auditoria) e `orcamento_status_lista` (GET, para mesclar na listagem). Badges na finalizada + listagem.
- **Reversão**: AGUARDANDO_RETORNO/ENVIADO → RASCUNHO; APROVADO/RECUSADO/CANCELADO → AGUARDANDO_RETORNO; ENTREGUE/RECUSADO/CANCELADO são terminais.
- **Modal de confirmação** (Teleport) antes de cada mudança; RECUSADO/CANCELADO pedem **motivo** (opcional), que vai para `motivo_recusa` da Orca e para o log.
- **Auditoria de status (`Orca_Status_Log`)**: tabela append-only com `orca_id`, `status` (destino), `status_anterior`, `user_id` (quem), `motivo`, `created_at`. Escrita por `orcamento_status` e `orcamento_converter_pedido`. Endpoint **`orcamento_status_historico`** (GET) retorna por `orca_id` (mais recente primeiro); a tela finalizada mostra timeline ("Histórico de Status"). Servirá para relatórios de funil/apontamentos.
- Layout da tela finalizada: badge de status fixo em cabeçalho dedicado (`.status-top`); subseção "Ações de Status" (`.status-section`) com os botões de transição (Enviar/Aprovar/Converter em Pedido/Faturar/Entregar/Recusar/Cancelar/reversões); timeline "Histórico de Status"; barra de ferramentas no rodapé (`.resumo-toolbar`) com Novo Orçamento / Faturar para cliente / WhatsApp / Gerar PDF. Condições de Pagamento + Observações são **read-only** na finalizada — a edição (com Gerar/Salvar Condições) fica só na área "Ajustar Orçamento", e `handleFinalizar` persiste tudo via `persistirCondicoesPagamento`.

## Pedido (fusão Pedido → Orca)

- A tabela `Pedido`/`item_ped` foi **substituída** por marcar a própria Orca (`eh_pedido = true` + status `AGUARDANDO_FATURAMENTO`). Novo endpoint **`orcamento_converter_pedido`** (POST): exige `status == APROVADO` e `eh_pedido != true`, grava `eh_pedido` + status + auditoria.
- **IMPORTANTE (Xano)**: `precondition` no Xano lança o erro quando a condição é `FALSE` — por isso `precondition (!$Orca_0.eh_pedido)` é o correto (sem o `!` o endpoint recusava SEMPRE, "já convertido").
- **Trava de edição no backend**: `orca_change`, `orcamento_recalcular`, `OrcamentoItem_Inserir` e `orcamento_item_deletar` recusam (`badrequest`) quando `eh_pedido == true`; `orcamento_status` **também bloqueia** mudança de status de pedido convertido (`precondition (!$Orca_0.eh_pedido)`). No frontend, `isVinculado` aceita `true`/`'true'`/`1`/`'1'` (defensivo) e a tela finalizada mostra badge "Somente Leitura"; botão "Converter em Pedido" aparece só em APROVADO, e "Faturar"/"Entregar" quando `eh_pedido`. `post_orca`/`orca_change`/`orca_id_POST`/`f_DuplicaOrcamento` não escrevem mais `pedido_id`; coluna `pedido_id` da Orca ainda existe (legado) — remover após migração.
- **Trava de edição — guard de nulo (fix)**: a trava não pode acessar `$X.eh_pedido` quando a Orca é `null` (1º item de orçamento novo em `OrcamentoItem_Inserir` gerava 500 `Unable to locate var`). Padrão: `var $pedidoBloqueado {false}` + `conditional if ($X != null) { var.update $pedidoBloqueado { ($X.eh_pedido == true) } }` + `precondition ($pedidoBloqueado != true)`. Aplicado nos 4 endpoints. Em `OrcamentoItem_Inserir` o `Orca_0` é resolvido por **precedência**: `orca_id` (2º+ item / edição) > `cod_orca` (1º item, cria) — `cod_orca` não é indexado; o frontend envia `orca_id` via `orcaIdAtual` sempre que o orçamento já existe.
- **Trava de recálculo**: `Orcamento_Recalcular_Totais` agora bloqueia (`badrequest`) quando `eh_pedido == true` (padrão `pedidoBloqueado` null-safe) — pedido convertido **não pode ser recalculado**, nem pela UI nem manualmente. Decisão: histórico antigo fica como está (não corrigir DIFAL/margem dos 83).
- **Listagem de Pedidos (`/pedidos`)**: página dedicada `PedidosView.vue` (não reusa a lista de orçamentos). Busca com **`so_pedidos: true`** no `orca_por_cliente_busca` (filtro backend `$db.Orca.eh_pedido == true`) + status mesclado via `orcamento_status_lista` + **filtro client-side por status** (AGUARDANDO_FATURAMENTO/FATURADO/ENTREGUE/RECUSADO/CANCELADO — APROVADO é pré-pedido, não aparece). Colunas: Código, Cliente, Contato, CNPJ/CPF, Total Venda, Total c/ B2C, Data Envio, Status, Ações (Ver/PDF/WhatsApp). "Ver" abre a mesma tela `/orcamentos/:codOrca` (Somente Leitura). Output do `orca_por_cliente_busca` ganhou `data_envio`/`data_aprovacao`/`total_itens`/`mao_de_obra`.
- **Separação Orçamentos × Pedidos**: `orca_por_cliente_busca` ganhou **`somente_orcamentos`** (filtro `eh_pedido != true`); a lista de Orçamentos passa `somente_orcamentos: true` e **removeu o selo "Vinculado"** (desktop + mobile) — toda linha é acionável (Editar/PDF/WhatsApp/Excluir). Pedidos saem da lista de orçamentos e ficam só em `/pedidos`.
- **Pedido abre read-only (finalizada)**: no `onMounted` da `OrcamentosView`, se `isVinculado` (eh_pedido) → `mostrarResumo = true` — o pedido abre direto na tela finalizada (3 campos + itens sem lápis/lixeira + seção Kapazi + histórico). Orçamento comum abre na tela de edição.
- **Voltar com origem**: `editarOrcamento(row, origem)` navega com `?origem=pedidos` (PedidosView) ou `?origem=orcamentos` (OrcamentosListView); `voltarLista()` lê `route.query.origem` → `'pedidos'` → `/pedidos`, senão → `/orcamentos`.
- **Resumo da tela finalizada**: **Custo Kapazi** (Σ `vlr_cst_nota_unit × qtd`, com fallback `vlr_custo` para dados antigos), **Mão de Obra** e **Margem Real** (2 casas, `margemRealResumo`).
- **Filtro de status na listagem**: Orçamentos e Pedidos têm `STATUS_*_FILTRO` com select no `.filtros-row` (media query mobile) — filtro client-side sobre `resultadosVisiveis`.
- **Botões**: `.btn-sm`/`.btn-lg` ajustam **apenas tamanho** (padding/fonte) — não sobrescrevem cor/fundo das variantes `.btn-primary/.btn-secondary/.btn-outline/.btn-danger-outline/.btn-whatsapp` (bug antigo: ordem de declaração fazia `.btn-sm` "branco" sobrepor o primário).

## Perfil do usuário

- O bonequinho no `GlobalHeader` abre `PerfilModal.vue` — edita nome/sobrenome, empresa (razao/fantasia/cnpj/ie/cpf/isPJ), UF (obrigatória), regime, frete B2B, margem e dias de validade.
- **Email é read-only** (se `google_oauth`, mostra "Conectado via Google"). Regime é select dinâmico via `GET /regime` (fallback `regimeMap`); **trocar regime pede confirmação** ("orçamentos anteriores mantêm o cálculo fiscal; só vale para novos"). Salva via `POST /user/{user_id}` → `fetchMe()`.
- Backend: `user_id_POST` ganhou **`uf`** (precondition obrigatória) e trocou `first_notempty`→`first_notnull` nos numéricos (`frtB2B`, `margem`) para **0 persistir**.
- **2ª fase**: telefone/endereço do usuário, logo, troca de email com verificação.

## Medida exata (acréscimo de fábrica)

- `Produto` ganhou `com_medida_exata` (bool) e `porcentagem_acrescimo` (% — a fábrica define, ex.: Cleankap e Vinil Vulcanizado = 10%).
- **Quem decide é o vendedor, por orçamento**: na tela, ao selecionar produto com a flag, aparece um **checkbox "Medida exata — acréscimo de X%"** (só M2/ML; Kit/Und não têm). Se marcado, o `orcamento_calcular` recebe `com_medida_exata=true` e o orquestrador repassa a `f_valor_custo_m2`/`f_valor_custo_ml`, que aplicam `custo_fabrica = (materia_prima + borda) × (1 + %/100)` **antes do IPI e do fiscal**. A flag do Produto só habilita a pergunta + define o % (não aplica sozinha).
- Tabela `item` ganhou `com_medida_exata` + `porcentagem_acrescimo` (persistidos via `post_item`/`OrcamentoItem_Inserir`/`Atualizar`; expostos em `orca_detalhes`/`Orcamento_Recalcular_Totais`). Frontend: `ProdutoCatalogo`/`OrcamentoNovoResult`/`OrcamentoInsertPayload` com os campos; ref `medidaExata` no store (default false, limpa em `limparFormItem`, restaurada no `editarItem`). O recálculo **não reaplica** o acréscimo (o `vlr_cst_nota_unit` gravado já o inclui).
- **Contrato de saída unificado**: TODAS as funções de custo (M2, ML, UND, KIT) retornam `com_medida_exata` + `acrescimo_medida_exata` no mesmo formato (UND/KIT: `false`/`0`), porque o orquestrador lê `$mod1.<campo>` para qualquer base. Fix do bug UND/KIT em `f_valor_custo_und`/`f_valor_custo_kit` (lição em AGENTS.md).

## Frete B2B

- `f_Orcamento_Orquestrador` rateia o frete proporcionalmente ao custo_nota do item (`frete_rateado_tot = frete_b2b × custo_nota_tot / total`), alinhando o preview do `orcamento_calcular` com o recálculo pós-inserção (`Orcamento_Recalcular_Totais`). Exposição do `vlr_frete_b2b_unit` (rateado) no response; `montarPayloadItem`/payload inline priorizam `it.vlr_frete_b2b_unit`.
- Guard de nulo: orçamento existente sem itens (1º item em `orca_id` vazio) → `SumarizaItensOrcamento` retorna null → `custo_nota_total_para_frete` inicializa em 0.
- Mínimo do frete B2B = `User.frtB2B` (lido por `f_calcula_frete` via `$User1.frtB2B`); faixas Kapazi: ≥ R$ 1.000 → R$ 0; ≥ R$ 300 → 10%; < R$ 300 → mínimo.

## Kapazi (fábrica)

### Dados para fábrica (`ControlePedido`)

- Tabela `ControlePedido` com FK **`orca_id`** (mantém `pedido_id` legado) + campos do fluxo da fábrica: `data_envio_fabrica`, `num_pedido_fabrica`, `data_aprovacao_layout`, `num_pedido_venda`, `num_nf`, `forma_pagamento_fabrica` (boleto/acerto CC/Pix), `cod_rastreio` (+ reusa `transportadoraB2B/B2C`, `dataPrevisao`, `dataChegada`, `freteB2BReal/B2CReal`).
- Endpoints: **`controle_pedido_por_orca`** GET e **`controle_pedido_salvar`** POST (upsert por `orca_id` — fora da trava de edição, então pedido pode editar esses campos). `orcamento_converter_pedido` **exige `num_pedido_fabrica` preenchido** (badrequest) antes de virar pedido.
- Tela finalizada/APROVADO tem a seção **"Dados para Kapazi (Fábrica)"**.

### Fluxo de status (Kapazi)

RASCUNHO → AGUARDANDO_RETORNO → APROVADO (cliente aprova) → vendedor envia à fábrica e registra `num_pedido_fabrica`/datas (manual) → **Converter em Pedido** = AGUARDANDO_FATURAMENTO → Kapazi emite NF+boletos, vendedor registra (`num_nf`, acerto) e clica **Faturar** = FATURADO → recebe e **Entregar** (com `cod_rastreio`) = ENTREGUE. SAC = tabela própria futura (não engessar); automação Kapazi futura.

### Desconto Kapazi (`ControlePedido.desconto_kapazi_perc`)

- Desconto concedido pela fábrica sobre o custo, em % (base = Σ `vlr_cst_nota_unit × qtd`). Só **aumenta o lucro**, não altera a venda.
- `controle_pedido_salvar` grava; na finalizada o resumo mostra linhas **derivadas** (não persistidas) quando `desconto_kapazi_perc > 0`: **Custo Kapazi efetivo** (`custoKapaziTotal − desconto`), **Lucro Real (c/ desconto)** (`luc_tot + desconto`) e **Margem Real (c/ desconto)** (`(luc_tot + desconto)/vnd_tot × 100`, 2 casas).
- **Onde/quando aparece na UI**: o input "Desconto Kapazi (%)" fica no card **"Dados para Kapazi (Fábrica)"** da **tela finalizada (resumo)** de `OrcamentosView.vue`, condicionado a `v-if="isVinculado || statusAtual === 'APROVADO'"` (`OrcamentosView.vue:2328`) — ou seja, **só** quando o orçamento virou pedido (`eh_pedido`) **ou** está com status `APROVADO`. Em RASCUNHO/ENVIADO/AGUARDANDO_RETORNO não existe; não aparece na listagem. O campo fica no grid do card (junto de Nº Pedido da Fábrica, Nº NF, Acerto) e é persistido pelo botão "Salvar Dados da Fábrica" (`controle_pedido_salvar`, fora da trava de edição). Efeito visual quando `perc > 0`: o resumo exibe as linhas **derivadas** "Custo Kapazi efetivo", "Lucro Real (c/ desconto)" e "Margem Real (c/ desconto)" (`OrcamentosView.vue:2086-2099`).
- **Decisão de arquitetura (Opção A)**: desconto fica como **metadado**; o **relatório** (futuro) deve calcular `lucro_real = luc_tot + (custoKapazi × perc/100)` — **não** assar no banco nem recalcular os 83.

## Tema claro/escuro + identidade Azul/Laranja

- Tokens semânticos em `main.css` (`:root` claro + `:root[data-theme='dark']` sem preto/branco puros: dark usa `#0f172a`/`#1e293b`/texto `#f8fafc`/`#94a3b8`). Azul `--primary` (#1e40af claro / #3b82f6 escuro), laranja `--accent` (#f97316 / #fb923c) só em CTA.
- `index.html` tem script anti-flash (lê `localStorage('orca_theme')`, fallback `prefers-color-scheme`); `stores/ui.ts` tem `tema`/`alternarTema`; botão sol/lua no `GlobalHeader`; header/sidebar navy (`--header-bg`/`--sidebar-bg`).
- `section-title` é barra lateral gradiente azul→laranja; `card-totais` usa `--primary-soft`; badges de status usam tokens soft (`--success-soft` etc.).
- Componentes migrados: `ClienteModal`, `PerfilModal`, `SimulacaoModal`, `ClientesView`, `LoginView`, `SignupView`, `OAuthCallbackView` (CTA laranja nos botões primários de ação). Headers de tabela das 3 listas (Clientes/Orçamentos/Pedidos) em `--primary` com texto branco; CTA "+ Novo Orçamento" em laranja.

## Docs de referência

- `docs/exemplo-precificacao.md` + `docs/exemplo-precificacao.pdf` — exemplo completo de precificação (medida exata + frete B2B Kapazi com faixas 52/10%/grátis, rateio proporcional, comparativo COM vs SEM medida exata, efeito ao excluir item).

## Dev Tools (cadastro de Produto + Variação)

Ferramentas **apenas em desenvolvimento** (guard `import.meta.env.DEV`). Acesso por **URL direta** (`/dev/produtos`, `/dev/fatores`; não aparecem no menu/sidebar; em produção o guard redireciona para Home).

- **`DevProdutosView.vue`** (`/dev/produtos`) — lista todos os produtos (ativos e inativos) com busca/filtro; form com Material (do catálogo) → Classificação/Linha/Tipo/Nível dependentes, Unidade, Base_de_Calculo, custo `valor`, `com_medida_exata`+`porcentagem_acrescimo`, **Fator de Corte fixo** (prioridade 1 no M2), `ativo`; seção editável de **Variações** (tipo_variacao, cor, modelo, LxC, comp, larg, qtd_kit, valor_custo, fator_de_corte_id, ordem, ativo) com adicionar/remover linha. Dropdowns de apoio via GET `/classificacao`, `/cor`, `/modelo`, `/tipo_variacao`, `/fatordecorte`.
- **`produto_cadastrar` POST** (auth User) — **transação única**: cria/atualiza `Detalhe` quando há variações (senão `detalhe_id = 0`), grava/atualiza o `Produto` (incl. `fator_de_corte_id`), sincroniza `Variacao` (cria sem id, edita com id, **apaga as que não vieram no payload** / as órfãs do detalhe anterior). **Herança de custo**: variação sem `valor_custo` herda `Produto.valor`; UND/KIT/ML exigem custo base `valor > 0` (badrequest). Retorna `{ produto_id, produto }`.
- **`produtos_dev_lista` GET** (auth User) — lista **todos** os produtos (sem filtro `ativo`) com descrição + `_variacao` + `fator_de_corte_id` (isolado do `fTodos_Produtos`, que filtra `ativo`).
- **Exclusão = flag `ativo`** (preserva histórico de orçamentos). Após salvar, o front **limpa `orca_catalogo_produtos_cache`** do localStorage para o app rebaixar produtos frescos sem depender de bump manual de `versao_produtos`.

## Dev Tools (Fator de Corte)

- **`DevFatoresView.vue`** (`/dev/fatores`) — CRUD de **`Fator_de_Corte`** (nome, `modo_corte` lista/passo, `valor[]` ou `comp_corte`, `larg_base`, `tam_total`, obs) e de **`Tipo_Fator`** (associação material+linha+borda → fator, o fallback do M2).
- **`fatores_corte_dev` GET** — lista fatores + associações `Tipo_Fator` com nomes (material/linha/borda).
- **`fator_corte_cadastrar` POST** — cria/edita um fator (modo lista/passo).
- **`fator_corte_excluir` DELETE** — **bloqueia** se o fator estiver em uso (referenciado em `Tipo_Fator` ou `Produto.fator_de_corte_id`) — não quebra o cálculo.
- **`tipo_fator_cadastrar` POST** — cria/edita (`excluir=false`) ou remove (`excluir=true`) uma associação `Tipo_Fator`.

### Fator de Corte — `modo_corte` (lista | passo)

O fator de corte é definido pelo fornecedor (Kapazi) e varia por produto/linha/borda. Para M2 há **dois modos**:

- **`lista`** (padrão): usa `Fator_de_Corte.valor[]` (múltiplos fixos, ex.: Vinil). Arredonda ao **menor múltiplo >= dimensão** e **mantém a dimensão original** se passar do maior valor da lista (`f_retorna_fc`).
- **`passo`**: usa `comp_corte` como **passo** (ex.: 0.5m). Arredonda **sempre** para cima ao múltiplo (`Math.ceil(dim / passo) * passo` — ex.: 1.23 → 1.50), sem a regra do máximo. Usado quando o fornecedor fraciona em medidas fixas (ex.: múltiplo de 0,5m).

**Resolução do M2 (Opção X)** — `f_valor_custo_m2`/`f_retorna_fc`:
1. **`Produto.fator_de_corte_id`** (fator fixo no produto — prioridade 1, ex.: M2 passo 0,5)
2. **`Tipo_Fator`** (material+linha+borda → fator) — fallback
3. sem fator → dimensões originais

ML/UND/KIT continuam usando o `fator_de_corte_id` da **Variação** (via `f_fator_corte_variacao`). No front do orçamento, o usuário entra com Largura × Comprimento e vê **Largura FC / Comprimento FC / Área Faturada** (readonly) — para passo, já saem múltiplos do passo.

## Produto composto (`Base_de_Calculo = COMPOSTO`)

Conceito genérico de **produto composto de outros itens** (diferente de **KIT**, que é venda em caixa — ex.: Waterkap 6 peças). O produto `COMPOSTO` tem uma **regra de composição** (`Produto.tipo_composto`, ex.: `"playkap"`) e os **componentes** como `Variacao` do produto (via `detalhe_id`).

**No front**: para `COMPOSTO`, a listbox "Variação" fica oculta (os componentes são internos ao cálculo) e o formulário depende do `tipo_composto`.

### PLAYKAP (`tipo_composto = "playkap"`) — piso modular
Vendido por M²; composto de **Placas** (30×30cm), **Rampas** (macho/fêmea) e **Cantoneiras**. Modelado como **1 item**; composição em `item.detalhes_calculo` (JSON), sem poluir a `Descricao` ("PLAYKAP").

**Configuração na base**
- `Produto.Base_de_Calculo = COMPOSTO`, `Produto.tipo_composto = "playkap"`.
- `Tipo_Variacao`: **Placa** (7), **Rampa** (8), **Cantoneira** (9).
- Variações do produto (mesmo `detalhe_id`): Placa (custo 11,50 / 0,30×0,30 / `qtd_kit` = compra mínima), Rampa (4,99 / 0,30), Cantoneira (5,49) — cada uma com `tipo_variacao_id`.
- Avulsos: **produtos separados** `Base_de_Calculo=UND` (Placa/Rampa/Cantoneira) para venda por unidade — fluxo UND normal.

**Cálculo (`f_valor_custo_playkap`)** — mesmo contrato `$mod1` + `detalhes_calculo`:
- `placas = max(ceil(comp/0.30) × ceil(larg/0.30), compra_minima)` — compra mínima = `qtd_kit` da variação Placa (fallback 11).
- **Rampa por lado** (`rampa_larg1/comp1/larg2/comp2`): aresta de comprimento = `placasComp` rampas; aresta de largura = `placasLarg` rampas. Divisão **macho/fêmea automática** (`ceil`/`floor`).
- `cantoneiras = min(4, qtd_cantos)`.
- `valores.custo_nota_tot` = Σ componente × custo; markup/`Precificar` no fluxo normal.
- `detalhes_calculo.playkap`: placas, rampas (total/macho/fêmea), cantoneiras, **lados** (4 booleans), área, compra mínima, custos.

**Integração**
- **`orcamento_calcular`** aceita `rampa_larg1/comp1/larg2/comp2` + `qtd_cantos`.
- **Front** (`OrcamentosView`): quando `COMPOSTO` + `tipo_composto='playkap'`, mostra Peça (Área ou Larg×Comp) + **4 checkboxes de rampa** + Cantoneiras (0-4).
- **`item.detalhes_calculo`** gravado via `post_item`/`OrcamentoItem_Inserir`/`Atualizar`, exposto em `orca_detalhes`/`Orcamento_Recalcular_Totais`. Também serve para detalhes do **ML** no futuro.
