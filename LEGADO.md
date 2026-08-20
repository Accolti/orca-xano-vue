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
- Listagem: o enum `status` **não pode** ir no `output` de `db.query` paginado (`orca_por_cliente_busca` — erro `xdo.orca.cod_orca`). O status vem do endpoint auxiliar `orcamento_status_lista` (db.query simples) e é mesclado por `id` no frontend.
- Referência de tabela base em `db.query` com join deve ser **maiúscula** (`$db.Orca.cod_orca`, `sort = {Orca.created_at: "desc"}`); minúscula (`$db.orca.cod_orca`, `{orca.created_at: ...}`) quebra com `xdo.orca.*`. `orca_por_cliente_id` (sort) e `orca_id_user` (where `$db.orca.cod_orca` + sort) ainda usam minúsculo (legado, não usados pelo frontend novo) — corrigir ao migrar.
