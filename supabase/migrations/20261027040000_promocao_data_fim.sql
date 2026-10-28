-- Expor a data fim da promoção no retorno de promocoes_ativas, para que o motor
-- persista `detalhes_calculo.promo.data_fim` no item e o PDF/WhatsApp usem essa
-- data como limite da validade da proposta (quando houver item em promoção).

create or replace function public.promocoes_ativas(
  p_produto_id bigint default null,
  p_variacao_id bigint default null,
  p_borda_id bigint default null
)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'promocao_id', pr.id,
    'produto_id', pi.produto_id,
    'variacao_id', pi.variacao_id,
    'borda_id', pi.borda_id,
    'tipo', pi.tipo,
    'valor', pi.valor,
    'data_fim', pr.data_fim
  )), '[]'::jsonb)
  from promocao pr
  join promocao_item pi on pi.promocao_id = pr.id
  where pr.ativo = true
    and current_date >= pr.data_inicio
    and current_date <= pr.data_fim
    and (
      (p_produto_id is not null and pi.produto_id = p_produto_id)
      or (p_variacao_id is not null and pi.variacao_id = p_variacao_id)
      or (p_borda_id is not null and pi.borda_id = p_borda_id)
    );
$$;
