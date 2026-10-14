-- =============================================================
-- Endereço da empresa — grava tipo_endereco/preferencial corretamente
-- =============================================================
--
-- A coluna real da tabela endereco_user é `tipo_endereco` (com underscore),
-- não `tipoendereco` como o schema do Xano sugeria. A migration anterior
-- gravava o endereço mas deixava tipo_endereco/preferencial como null.
--
-- 1) user_salvar: passa a gravar `tipo_endereco = 'Comercial'` e
--    `preferencial = true` (paridade com os registros antigos).
-- 2) Backfill: corrige as linhas já criadas sem esses valores.
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
      tipo_endereco = 'Comercial',
      endereco      = p_payload->>'endereco',
      numero        = p_payload->>'numero',
      complemento   = p_payload->>'complemento',
      cep           = p_payload->>'cep',
      bairro        = p_payload->>'bairro',
      cidade        = p_payload->>'cidade',
      estado        = p_payload->>'estado',
      preferencial  = true
    where id = v_endereco_user_id and user_id = p_user_id;
  elsif v_tem_endereco then
    insert into endereco_user (
      created_at, user_id, tipo_endereco, endereco, numero, complemento, cep, bairro, cidade, estado, preferencial
    ) values (
      now(), p_user_id, 'Comercial', p_payload->>'endereco', p_payload->>'numero', p_payload->>'complemento',
      p_payload->>'cep', p_payload->>'bairro', p_payload->>'cidade', p_payload->>'estado', true
    );
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

-- Backfill das linhas criadas pela versão anterior (sem tipo_endereco/preferencial).
update endereco_user set tipo_endereco = 'Comercial' where tipo_endereco is null;
update endereco_user set preferencial = true where preferencial is null;
