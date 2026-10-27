-- Índices de performance (FKs e colunas de filtro que o Postgres NÃO indexa sozinho).
-- Idempotente (create index if not exists) — cobre também os índices que podem ter
-- sido criados manualmente no dashboard (ex.: item.orca_id, aliquotas_icms.uf,
-- variacao.detalhe_id), deixando-os versionados nas migrations.

-- Listagem/dashboard/relatório de orçamentos por usuário
create index if not exists orca_user_id_idx on public.orca (user_id);
create index if not exists orca_created_at_idx on public.orca (created_at);

-- Boletos (financeiro): por usuário, por orçamento e por vencimento
create index if not exists boleto_user_id_idx on public.boleto (user_id);
create index if not exists boleto_orca_id_idx on public.boleto (orca_id);
create index if not exists boleto_vencimento_idx on public.boleto (vencimento);

-- Clientes por usuário
create index if not exists cliente_user_id_idx on public.cliente (user_id);

-- Itens do orçamento (recálculo + relatório + soma para frete)
create index if not exists item_orca_id_idx on public.item (orca_id);

-- Controle de pedido (Kapazi) por usuário e por orçamento
create index if not exists controle_pedido_user_id_idx on public.controle_pedido (user_id);
create index if not exists controle_pedido_orca_id_idx on public.controle_pedido (orca_id);

-- Logs usados no relatório (funil e desconto Kapazi)
create index if not exists orca_status_log_orca_id_idx on public.orca_status_log (orca_id);
create index if not exists desconto_kapazi_log_orca_id_idx on public.desconto_kapazi_log (orca_id);

-- Catálogo/precificação
create index if not exists variacao_detalhe_id_idx on public.variacao (detalhe_id);
create index if not exists aliquotas_icms_uf_idx on public.aliquotas_icms (uf);
