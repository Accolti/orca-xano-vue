-- =============================================================
-- Perfil do usuário (Meus Dados / Onboarding) — migração Xano → Supabase
-- =============================================================
--
-- Substitui os endpoints Xano usados por PerfilModal/OnboardingView:
--   - POST /user/{id}        → user_salvar (atualiza o próprio perfil)
--   - GET  /regime           → regime_lista
--   - GET  /organizacao      → organizacao_lista
--
-- Todas são SECURITY DEFINER (as tabelas têm RLS ativo). As listas são
-- dados de referência (sem checagem de identidade); user_salvar valida
-- auth_user_id() = p_user_id (anti-spoof) + f_ativo_efetivo.
-- =============================================================

-- Atualiza o perfil do próprio usuário (payload camelCase, como o front envia).
-- Campos ausentes/nulos mantêm o valor atual (paridade com o `first_notempty` do Xano).
create or replace function public.user_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  update usuarios set
    name                     = coalesce(nullif(p_payload->>'name', ''), name),
    name_first               = coalesce(nullif(p_payload->>'name_first', ''), name_first),
    name_last                = coalesce(nullif(p_payload->>'name_last', ''), name_last),
    email                    = coalesce(nullif(p_payload->>'email', ''), email),
    razao                    = coalesce(nullif(p_payload->>'razao', ''), razao),
    fantasia                 = coalesce(nullif(p_payload->>'fantasia', ''), fantasia),
    cnpj                     = coalesce(nullif(p_payload->>'cnpj', ''), cnpj),
    ie                       = coalesce(nullif(p_payload->>'ie', ''), ie),
    cpf                      = coalesce(nullif(p_payload->>'cpf', ''), cpf),
    is_pj                    = coalesce((p_payload->>'isPJ')::boolean, is_pj),
    uf                       = coalesce(nullif(p_payload->>'uf', ''), uf),
    regime_id                = coalesce((p_payload->>'regime_id')::bigint, regime_id),
    organizacao_id           = coalesce((p_payload->>'organizacao_id')::bigint, organizacao_id),
    frt_b2b                  = coalesce((p_payload->>'frtB2B')::numeric, frt_b2b),
    margem                   = coalesce((p_payload->>'margem')::numeric, margem),
    desconto_livre_perc      = coalesce((p_payload->>'desconto_livre_perc')::numeric, desconto_livre_perc),
    desconto_max_perc        = coalesce((p_payload->>'desconto_max_perc')::numeric, desconto_max_perc),
    dias_vencimento_orcamento = coalesce((p_payload->>'DiasVencimentoOrcamento')::bigint, dias_vencimento_orcamento)
  where id = p_user_id;

  return jsonb_build_object('ok', true);
end;
$$;

-- Lista de regimes tributários (referência).
create or replace function public.regime_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]'::jsonb)
  from regime r;
$$;

-- Lista de organizações fornecedoras (referência).
create or replace function public.organizacao_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(o) order by o.id), '[]'::jsonb)
  from organizacao o;
$$;
