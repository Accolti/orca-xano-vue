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
