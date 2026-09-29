-- =============================================================
-- Fase 3 — perfil_efetivo com chaves camelCase (paridade com o Xano)
-- =============================================================
create or replace function public.perfil_efetivo(p_user_id bigint)
returns jsonb language sql stable as $$
  select to_jsonb(u)
    || jsonb_build_object(
      'frtB2B', u.frt_b2b,
      'DiasVencimentoOrcamento', u.dias_vencimento_orcamento,
      'isPJ', u.is_pj
    )
  from usuarios u where u.id = f_empresa_id(p_user_id)
$$;
