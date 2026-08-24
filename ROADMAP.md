# Roadmap / Ideias — Orca Xano Vue

Status geral: ideias registradas; implementação por fases (decidir prioridade depois).

## 🗂 Frente 1 — Documentos em pastas compartilhadas (Google Drive)

Status: PRÓXIMA a implementar (fase simples primeiro; migrar para API depois)

### Fase 1A — Link de pastas compartilhadas (simples)

- [ ] Nova tabela (ex.: `Pasta_Compartilhada` por `Organizacao`) com links do Google Drive
- [ ] Duas pastas de prima: **Orçamentos (PDF)** e **Pedidos de Venda**
- [ ] Página para o usuário cadastrar os links/credenciais + **manual para os vendedores**
- [ ] Botão "Abrir pasta" no app (Orçamentos e Pedidos)

### Fase 1B — Upload automático via Google Drive API

- [ ] Migrar para API (service account / OAuth)
- [ ] Upload automático do PDF na pasta correta ao converter em pedido

### PDF de Pedido de Venda

- [ ] Novo template `gerarPdfPedidoVenda` (distinto do "Orçamento de Venda" atual)
- [ ] Incluir todas as opções negociadas (condições de pagamento, frete, desconto, validade) + valor final
- [ ] **Pedido de Venda aparece na Lista de Pedidos** (além do orçamento)

## 💳 Frente 2 — Parametrização de Condições de Pagamento

Status: registrada (implementação futura)

- [ ] Tela admin: lista central de métodos (Pix/Dinheiro, Boleto, Cartão, Faturamento Direto) com toggles ON/OFF
- [ ] Regras por método: desconto incentivo Pix, parcela mínima boleto, máx. parcelas sem juros cartão + repasse taxa, prazos fixos por perfil + valor mínimo faturamento direto
- [ ] Trava do Custo de Fábrica: Max Parcelas = floor(V_venda ÷ P_fabrica), P_fabrica = C_fabrica ÷ N_fabrica
- [ ] Trava no front (dropdown de parcelas limitado + aviso)
- [ ] Simulador em tempo real no painel de config ("Liberado em até 4x no boleto")

## 👥 Frente 3 — Multi-vendedor, planos, comissão e permissões

Status: registrada (implementação futura)

- [ ] `role` no User (admin / vendedor_master / vendedor) + `vendedor_pai_id` + `percentual_comissao`
- [ ] Visibilidade por permissão: vendedor NÃO vê custo da empresa (ocultar cst/markup/margem real); só quem tem "chave" vê
- [ ] Limite de desconto por vendedor
- [ ] Planos/assinaturas (vendedor compra plano; sub-vendedores com comissão)

## 📊 Frente 4 — Relatórios e controle financeiro

Status: registrada (implementação futura) — origem: `LEGADO.md`/contexto do projeto

- [ ] **Relatório de funil/apontamentos** usando o `Orca_Status_Log` (histórico de transições RASCUNHO → … → ENTREGUE, tempos por etapa, taxas de conversão)
- [ ] **Relatório financeiro com lucro real** (Opção A decidida): `lucro_real = luc_tot + (custoKapazi × desconto_kapazi_perc/100)` — não assar no banco, calcular no relatório. A fonte do histórico é o `Desconto_Kapazi_Log` (abaixo).
- [ ] **Log de descontos Kapazi**: tabela append-only `Desconto_Kapazi_Log` (padrão `Orca_Status_Log`) — registra **toda mudança** de `ControlePedido.desconto_kapazi_perc`, consumida **só pelos relatórios** (o resumo da finalizada continua mostrando o valor atual). Gravada pelo `controle_pedido_salvar` quando o % muda; o campo `desconto_kapazi_perc` segue sendo o "valor vivo". Schema sugerido:

  ```xano
  table Desconto_Kapazi_Log {
    auth = false

    schema {
      int id
      timestamp created_at?=now { visibility = "private" }

      int orca_id? { table = "Orca" }

      // Desconto anterior e novo (em %)
      decimal desconto_anterior?
      decimal desconto_novo?

      // Valor do desconto em R$ na data do log (base = Σ vlr_cst_nota_unit × qtd)
      decimal valor_desconto_rs?

      // Quem gravou
      int user_id? { table = "User" }

      // Motivo/observação opcional (ex.: negociação com a fábrica)
      text motivo? filters=trim
    }

    index = [
      {type: "primary", field: [{name: "id"}]}
      {
        type : "btree"
        field: [{name: "orca_id", op: "asc"}, {name: "created_at", op: "desc"}]
      }
      {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    ]
  }
  ```
- [ ] **Boletos**: base já existe no backend (`Boleto`, `f_boleto_pago`, `f_boleto_a_vencer`, `f_boleto_vencido`, `f_sum_pedidos_boletos`) — construir telas de controle (em aberto / a vencer / vencidos / recebidos) e fluxo de baixa
- [ ] **Controle de Pedidos**: painel consolidado do fluxo Kapazi (enviado → nº fábrica → aprovação layout → NF → boletos → entregue) com status e prazos
- [ ] **SAC (pós-venda)**: tabela própria de atendimento/reclamações por pedido (não engessar no fluxo atual)

## 🧹 Frente 5 — Perfil do usuário (2ª fase) e limpeza do legado

Status: registrada (implementação futura)

- [ ] **Perfil 2ª fase**: telefone/endereço do usuário, logo, troca de e-mail com verificação (a 1ª fase já existe — `PerfilModal.vue`)
- [ ] **Automação Kapazi** (futura): integração para receber/registrar status e dados da fábrica automaticamente
- [ ] **Limpeza do legado**: rodar `MigrarPedidosParaOrca`, depois excluir as funções/endpoints `PARA EXCLUIR` do `LEGADO.md`, dropar tabelas `Pedido`/`item_ped`/`controle_pedido` e a coluna `orca.pedido_id`
