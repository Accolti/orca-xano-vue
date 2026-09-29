-- =============================================================
-- Fase 4 — Cliente (busca, detalhe, salvar/upsert, excluir)
-- =============================================================

-- Lista de clientes do usuário, com busca (texto sem acento + CNPJ/CPF numérico) e paginação.
create or replace function public.cliente_user_busca(
  p_user_id bigint,
  p_busca text default null,
  p_pagina int default 1
)
returns jsonb language plpgsql as $$
declare
  v_busca text := nullif(trim(coalesce(p_busca, '')), '');
  v_busca_norm text := nullif(unaccent(lower(v_busca)), '');
  v_busca_num text := nullif(regexp_replace(v_busca, '[^0-9]', '', 'g'), '');
  v_limite int := 15;
  v_pagina int := greatest(coalesce(p_pagina, 1), 1);
  v_offset int := (v_pagina - 1) * v_limite;
  v_total int;
  v_cliente jsonb;
begin
  create temp table _cli on commit drop as
  select * from cliente
  where user_id = p_user_id
    and (
      v_busca_norm is null
      or unaccent(lower(coalesce(razao_social, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(nome_fantasia, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(contato, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(email, ''))) like '%' || v_busca_norm || '%'
      or (
        v_busca_num is not null and v_busca_num <> ''
        and (
          regexp_replace(coalesce(cnpj, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
          or regexp_replace(coalesce(cpf, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
        )
      )
    );

  select count(*) into v_total from _cli;

  select coalesce(jsonb_agg(
    to_jsonb(t) || jsonb_build_object('e-mail', t.email)
    order by t.created_at desc, t.id desc
  ), '[]'::jsonb)
  into v_cliente
  from (select * from _cli order by created_at desc, id desc limit v_limite offset v_offset) t;

  return jsonb_build_object(
    'cliente', v_cliente,
    'total', v_total,
    'pagina', v_pagina,
    'limite', v_limite
  );
end;
$$;

-- Detalhe de um cliente (com endereço e telefones).
create or replace function public.cliente_por_id(p_user_id bigint, p_cliente_id bigint)
returns jsonb language plpgsql as $$
declare
  v_cliente jsonb;
  v_endereco jsonb;
  v_telefones jsonb;
begin
  select to_jsonb(c) || jsonb_build_object('e-mail', c.email)
  into v_cliente
  from cliente c where c.id = p_cliente_id and c.user_id = p_user_id;

  if v_cliente is null then
    raise exception 'Cliente não encontrado.' using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.id), '[]'::jsonb)
  into v_endereco
  from endereco_cliente e where e.cliente_id = p_cliente_id;

  select coalesce(jsonb_agg(
    to_jsonb(t) || jsonb_build_object('descricao', tp.descricao)
    order by t.id
  ), '[]'::jsonb)
  into v_telefones
  from telefone_cliente t
  left join tipo_telefone tp on tp.id = t.tipo_telefone_id
  where t.cliente_id = p_cliente_id;

  return v_cliente
    || jsonb_build_object('_endereco_cliente', v_endereco, '_telefone_cliente_of_cliente', v_telefones);
end;
$$;

-- Exclui um cliente (se não tiver orçamentos) em cascata.
create or replace function public.cliente_deletar(p_user_id bigint, p_cliente_id bigint)
returns jsonb language plpgsql as $$
declare
  v_owner record;
  v_qtd int;
begin
  select id into v_owner from cliente where id = p_cliente_id and user_id = p_user_id;
  if not found then
    raise exception 'Cliente não encontrado.' using errcode = 'P0001';
  end if;

  select count(*) into v_qtd from orca where cliente_id = p_cliente_id;
  if v_qtd > 0 then
    raise exception 'Este cliente não pode ser excluído pois já tem orçamentos.' using errcode = 'P0001';
  end if;

  delete from endereco_cliente where cliente_id = p_cliente_id;
  delete from telefone_cliente where cliente_id = p_cliente_id;
  delete from cliente where id = p_cliente_id;

  return jsonb_build_object('ok', true);
end;
$$;

-- Cria ou atualiza cliente (endereço + telefones). Upsert por cliente_id.
create or replace function public.cliente_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql as $$
declare
  v_cliente_id bigint := coalesce((p_payload->>'cliente_id')::bigint, 0);
  v_endereco_id bigint := coalesce((p_payload->>'endereco_cliente_id')::bigint, 0);
  v_tipo_pessoa text := p_payload->>'tipo_pessoa';
  v_cpf text := p_payload->>'cpf';
  v_cnpj text := p_payload->>'cnpj';
  v_nome_cpf text := p_payload->>'nome_cpf';
  v_existe record;
  v_phone jsonb;
  v_tel_id bigint;
  v_telefone text;
  v_tipo bigint;
begin
  if coalesce(nullif(p_payload->>'razao_social', ''), nullif(p_payload->>'nome_cpf', '')) is null then
    raise exception 'Informe a Razão Social (ou o Nome, para CPF).' using errcode = 'P0001';
  end if;
  if coalesce(nullif(p_payload->>'contato', ''), '') = '' then
    raise exception 'Informe o Contato.' using errcode = 'P0001';
  end if;
  if coalesce(jsonb_array_length(p_payload->'objphone'), 0) = 0 then
    raise exception 'Informe ao menos um telefone.' using errcode = 'P0001';
  end if;

  -- documento cruzado: um tipo presente limpa o outro (igual ao PATCH do Xano)
  if v_tipo_pessoa = 'CNPJ' or (v_cnpj is not null and v_cnpj <> '') then
    v_cpf := '';
    v_nome_cpf := '';
  elsif v_tipo_pessoa = 'CPF' or (v_cpf is not null and v_cpf <> '') then
    v_cnpj := '';
  end if;

  if v_cliente_id > 0 then
    select id into v_existe from cliente where id = v_cliente_id and user_id = p_user_id;
    if not found then
      raise exception 'Cliente não encontrado.' using errcode = 'P0001';
    end if;

    update cliente set
      tipo_pessoa = v_tipo_pessoa,
      razao_social = p_payload->>'razao_social',
      nome_fantasia = p_payload->>'nome_fantasia',
      contato = p_payload->>'contato',
      cpf = v_cpf,
      cnpj = v_cnpj,
      nome_cpf = v_nome_cpf,
      inscricao_estadual = p_payload->>'inscricao_estadual',
      email = nullif(p_payload->>'e-mail', ''),
      contribui_icms = coalesce((p_payload->>'contribui_icms')::boolean, false),
      isento = coalesce((p_payload->>'isento')::boolean, false),
      observacao = p_payload->>'observacao',
      beneficio_fiscal_id = nullif(nullif(p_payload->>'beneficio_fiscal_id', ''), '0')::bigint,
      mercado_id = nullif(nullif(p_payload->>'mercado_id', ''), '0')::bigint,
      ramo_id = nullif(nullif(p_payload->>'ramo_id', ''), '0')::bigint,
      regime_id = nullif(nullif(p_payload->>'regime_id', ''), '0')::bigint
    where id = v_cliente_id;
  else
    insert into cliente (
      created_at, tipo_pessoa, razao_social, nome_fantasia, contato, cpf, nome_cpf, cnpj,
      inscricao_estadual, email, contribui_icms, isento, observacao, user_id,
      beneficio_fiscal_id, mercado_id, ramo_id, regime_id
    ) values (
      now(), v_tipo_pessoa, p_payload->>'razao_social', p_payload->>'nome_fantasia', p_payload->>'contato',
      v_cpf, v_nome_cpf, v_cnpj, p_payload->>'inscricao_estadual', nullif(p_payload->>'e-mail', ''),
      coalesce((p_payload->>'contribui_icms')::boolean, false), coalesce((p_payload->>'isento')::boolean, false),
      p_payload->>'observacao', p_user_id,
      nullif(nullif(p_payload->>'beneficio_fiscal_id', ''), '0')::bigint,
      nullif(nullif(p_payload->>'mercado_id', ''), '0')::bigint,
      nullif(nullif(p_payload->>'ramo_id', ''), '0')::bigint,
      nullif(nullif(p_payload->>'regime_id', ''), '0')::bigint
    ) returning id into v_cliente_id;
  end if;

  -- endereço
  if v_endereco_id > 0 then
    update endereco_cliente set
      cliente_id = v_cliente_id,
      endereco = p_payload->>'endereco',
      numero = p_payload->>'numero',
      complemento = p_payload->>'complemento',
      cep = p_payload->>'cep',
      bairro = p_payload->>'bairro',
      cidade = p_payload->>'cidade',
      estado = p_payload->>'estado'
    where id = v_endereco_id;
  elsif coalesce(p_payload->>'endereco', '') <> '' or coalesce(p_payload->>'cep', '') <> '' then
    insert into endereco_cliente (
      created_at, cliente_id, tipo, endereco, numero, complemento, cep, bairro, cidade, estado
    ) values (
      now(), v_cliente_id, 'Comercial', p_payload->>'endereco', p_payload->>'numero', p_payload->>'complemento',
      p_payload->>'cep', p_payload->>'bairro', p_payload->>'cidade', p_payload->>'estado'
    );
  end if;

  -- telefones
  for v_phone in select value from jsonb_array_elements(p_payload->'objphone') loop
    v_tel_id := coalesce((v_phone->>'telefone_id')::bigint, 0);
    v_telefone := v_phone->>'telefone';
    v_tipo := nullif(nullif(v_phone->>'tipo', ''), '0')::bigint;

    if v_tel_id <= 0 then
      insert into telefone_cliente (created_at, cliente_id, tipo_telefone_id, telefone)
      values (now(), v_cliente_id, v_tipo, v_telefone);
    elsif v_telefone is null and v_tipo is null then
      delete from telefone_cliente where id = v_tel_id;
    else
      update telefone_cliente set telefone = v_telefone, tipo_telefone_id = v_tipo where id = v_tel_id;
    end if;
  end loop;

  return jsonb_build_object(
    'cliente',
    (select to_jsonb(c) || jsonb_build_object('e-mail', c.email) from cliente c where c.id = v_cliente_id)
  );
end;
$$;
