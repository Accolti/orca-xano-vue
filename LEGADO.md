# LEGADO — Funções e Endpoints Órfãos

Inventário do que **não faz parte do sistema atual** de precificação/orçamento.

> **Status:** `NENHUM` = sem uso no frontend atual; `EM USO` = ainda referenciado; `PARA EXCLUIR` = candidato a exclusão após validação; `EXCLUÍDA` = já removida do workspace.
> **Funcionalidades vigentes** (orçamento, status, pedido, Kapazi, perfil, tema, medida exata, PDF/WhatsApp): ver [`docs/FUNCIONALIDADES.md`](./docs/FUNCIONALIDADES.md).
> **Regra:** só excluir depois que WhatsApp/PDF/Pedido forem validados com `Orcamento_Detalhes_v2`.

## Funções (Xano)

| Função | Status | Substituída por |
|---|---|---|
| `Orcamento_Detalhes_Function` | PARA EXCLUIR (quebrada: chama `fcalcularPrazo` 214058 inexistente) | `Orcamento_Detalhes_v2` |
| `Orcamento_Detalhes_Function_0_old` | PARA EXCLUIR | `Orcamento_Detalhes_v2` |
| `Orcamento_Orquestrador` (antiga, sem prefixo `f_`) | **EXCLUÍDA (2026-09)** | `f_Orcamento_Orquestrador` |
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

## Migração legado

- **Fusão Pedido → Orca**: a tabela `Pedido`/`item_ped` foi **substituída** por marcar a própria Orca (`eh_pedido = true` + status `AGUARDANDO_FATURAMENTO`). Detalhes do fluxo vigente em `docs/FUNCIONALIDADES.md`.
- **Migração `MigrarPedidosParaOrca`** (one-off): para cada `Pedido`, acha a Orca por `cod_orca`, grava `eh_pedido=true` + mapeia status (AGUARDANDO_FATURAMENTO/FATURADO/ENTREGUE/CANCELADO) + auditoria.
- **Referência de tabela base em `db.query` com join deve ser maiúscula** (`$db.Orca.cod_orca`, `sort = {Orca.created_at: "desc"}`); minúscula quebra com `xdo.orca.*`. `orca_por_cliente_id` (sort) e `orca_id_user` (where `$db.orca.cod_orca` + sort) ainda usam minúsculo (legado, não usados pelo frontend atual) — corrigir ao migrar.

## Próximos passos

1. **Rodar `MigrarPedidosParaOrca` no dashboard** (marca as 83 Orcas vinculadas como `eh_pedido`) e depois **dropar** `Pedido`/`item_ped`/`controle_pedido` + funções/endpoints legados (`pedido_func`, `item_ped_func`, `PedidoItem_Inserir`, `pedido/*`, `controlepedido/*`, addons `boleto_of_pedido`) e a coluna `orca.pedido_id`.
2. Excluir os itens `PARA EXCLUIR` no dashboard.
