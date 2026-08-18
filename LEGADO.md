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
| `Item_alterar_margem` | EM USO (via `orca_change`) | revisar ao migrar pedido |
| `post_orca` | EM USO (via `OrcamentoItem_Inserir`) | revisar |
| `post_item` | EM USO (via `OrcamentoItem_Inserir`) | revisar |
| `orca_change` | EM USO (via `PedidoItem_Inserir`) | revisar ao migrar pedido |
| `pedido_func` | EM USO (via `PedidoItem_Inserir`) | revisar ao migrar pedido |

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
2. Validar WhatsApp e Pedido com `Orcamento_Detalhes_v2`
3. ~~Gerar PDF no frontend (pdfmake)~~ → feito (`src/services/pdf.ts`; `/auth/me` expõe `_telefones`; `orca_detalhes` expõe `_enderecos`)
4. Excluir os itens `PARA EXCLUIR` no dashboard

## Notas (`mao_de_obra` / `observacao`)
- Tabela `Orca` ganhou `mao_de_obra` (soma apenas no Total Geral `vnd_B2B_B2C_tot`, não altera lucro/margem) e `observacao` (texto livre, impresso no final do PDF).
- `Orcamento_Recalcular_Totais` e `orcamento_recalcular` aceitam/persistem ambos; `OrcamentoItem_Inserir`/`post_orca` gravam a observação na criação.
- PDF: nome `{codOrca}_{contato}-{fantasia/razao}_{dd-MM-yyyy HH-mm-ss}_.pdf`, descrição do item abaixo do item, seção Observações e toggle "Faturar para cliente".
- WhatsApp: botão na tela finalizada e na listagem; mensagem montada no frontend (`montarTextoWhatsApp`); telefone do cliente com `tipo_telefone_id == 1` (addon `Telefone_Cliente_of_Cliente` no `orca_detalhes`).
- Campo "Observações do Orçamento" movido para o card "Ajustar Orçamento" (abaixo do botão Aplicar); botão Aplicar na cor primária.
