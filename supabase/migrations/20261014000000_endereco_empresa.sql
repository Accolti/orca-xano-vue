-- =============================================================
-- Endereço da empresa (endereco_user) — cadastro no "Meus Dados" e Onboarding
-- =============================================================
--
-- O rodapé do PDF do orçamento já lê user._endereco_user (tabela endereco_user).
-- Antes não havia onde cadastrá-lo: nem a UI nem o user_salvar escreviam nele.
--
-- 1) user_salvar: passa a fazer upsert do endereço (por endereco_user_id, senão insert).
-- 2) perfil_efetivo: passa a expor _endereco_user da empresa (topo da cadeia),
--    para que o PDF mostre o endereço da empresa mesmo quando emitido por um filho.
-- =============================================================

create or replace function public.user_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_endereco_user_id bigint := coalesce((p_payload->>'endereco_user_id')::bigint, 0);
  v_tem_endereco boolean;
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

  -- Endereço da empresa: atualiza o existente (por id) ou insere quando há dados.
  v_tem_endereco := coalesce(nullif(p_payload->>'endereco', ''), '') <> ''
                 or coalesce(nullif(p_payload->>'cep', ''), '') <> ''
                 or coalesce(nullif(p_payload->>'cidade', ''), '') <> ''
                 or coalesce(nullif(p_payload->>'estado', ''), '') <> '';

  if v_endereco_user_id > 0 then
    update endereco_user set
      endereco    = p_payload->>'endereco',
      numero      = p_payload->>'numero',
      complemento = p_payload->>'complemento',
      cep         = p_payload->>'cep',
      bairro      = p_payload->>'bairro',
      cidade      = p_payload->>'cidade',
      estado      = p_payload->>'estado'
    where id = v_endereco_user_id and user_id = p_user_id;
  elsif v_tem_endereco then
    insert into endereco_user (
      created_at, user_id, endereco, numero, complemento, cep, bairro, cidade, estado
    ) values (
      now(), p_user_id, p_payload->>'endereco', p_payload->>'numero', p_payload->>'complemento',
      p_payload->>'cep', p_payload->>'bairro', p_payload->>'cidade', p_payload->>'estado'
    );
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

-- Exibe o endereço da empresa (topo da cadeia) também no perfil efetivo,
-- para que o PDF mostre o endereço da empresa independente de quem emite.
create or replace function public.perfil_efetivo(p_user_id bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_empresa_id bigint;
  v_endereco jsonb;
begin
  if auth_user_id() is null then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select f_empresa_id(p_user_id) into v_empresa_id;

  select to_jsonb(e) into v_endereco
  from endereco_user e where e.user_id = v_empresa_id order by e.id limit 1;

  return (
    select to_jsonb(u)
      || jsonb_build_object(
        'frtB2B', u.frt_b2b,
        'DiasVencimentoOrcamento', u.dias_vencimento_orcamento,
        'isPJ', u.is_pj,
        '_endereco_user', v_endereco
      )
    from usuarios u where u.id = v_empresa_id
  );
end;
$$;
