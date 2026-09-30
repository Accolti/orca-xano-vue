-- =============================================================
-- Fase 3 — Segurança: converte os RPCs de "endpoint" para SECURITY DEFINER
-- e adiciona validação de identidade (auth.uid()) em cada um.
-- =============================================================
--
-- Regra: p_user_id (ou p_payload->>'user_id') é SEMPRE o chamador. Cada função
-- valida auth_user_id() contra esse valor (anti-spoof). Helpers internos
-- (f_empresa_id, f_ativo_efetivo, etc.) continuam SECURITY INVOKER (rodam como
-- postgres quando chamados dentro de um definer; bloqueados pelo RLS se chamados
-- diretamente).

-- Helper: dono da orca OU admin_geral (escrita de dados da fábrica/duplicar).
create or replace function public.f_dono_ou_admin(p_user_id bigint, p_orca_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from orca o
    where o.id = p_orca_id
      and (
        o.user_id = p_user_id
        or exists (select 1 from usuarios u where u.id = p_user_id and u.role = 'admin_geral')
      )
  )
$$;

-- =============================================================
-- Auth
-- =============================================================

create or replace function public.auth_me()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_id bigint;
  v_u usuarios%rowtype;
  v_telefones jsonb;
  v_endereco jsonb;
  v_ativo_efetivo boolean;
begin
  select id into v_id from usuarios where auth_id = auth.uid();
  if v_id is null then
    return null;
  end if;

  select * into v_u from usuarios where id = v_id;

  select coalesce(jsonb_agg(
    jsonb_build_object('id', t.id, 'telefone', t.telefone, 'tipo_telefone', t.tipo_telefone)
    order by t.id
  ), '[]'::jsonb)
  into v_telefones
  from telefone_user t
  where t.user_id = v_id;

  select to_jsonb(e) into v_endereco
  from endereco_user e where e.user_id = v_id order by e.id limit 1;

  v_ativo_efetivo := f_ativo_efetivo(v_id);

  return to_jsonb(v_u)
    - 'password'
    - 'auth_id'
    - 'google_oauth'
    || jsonb_build_object(
      'frtB2B', v_u.frt_b2b,
      'DiasVencimentoOrcamento', v_u.dias_vencimento_orcamento,
      'isPJ', v_u.is_pj,
      'ativo_efetivo', v_ativo_efetivo,
      '_telefones', v_telefones,
      '_endereco_user', v_endereco
    );
end;
$$;

create or replace function public.perfil_efetivo(p_user_id bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select to_jsonb(u)
      || jsonb_build_object(
        'frtB2B', u.frt_b2b,
        'DiasVencimentoOrcamento', u.dias_vencimento_orcamento,
        'isPJ', u.is_pj
      )
    from usuarios u where u.id = f_empresa_id(p_user_id)
  );
end;
$$;

-- =============================================================
-- Catálogo / Taxas
-- =============================================================

create or replace function public.rpc_configuracoes()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select jsonb_build_object(
      'configuracoes-mae',
      coalesce(
        (
          select jsonb_agg(jsonb_build_object(
            'versao_materiais', versao_materiais,
            'versao_produtos', versao_produtos,
            'versao_taxas_banco', versao_taxas_banco,
            'taxas_atualizado_em', to_epoch_ms(taxas_atualizado_em)
          ) order by id)
          from configuracoes
        ),
        '[]'::jsonb
      )
    )
  );
end;
$$;

create or replace function public.rpc_taxas_banco(p_user_id bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    with empresa as (select f_empresa_id(p_user_id) as id)
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', t.id,
      'provedor_id', t.provedor_id,
      'parcelas', t.parcelas,
      'cc_taxa', t.cc_taxa,
      'provedor', p.nome,
      'canal', t.canal,
      'origem', t.origem,
      'user_id', t.user_id,
      'ativo', true
    ) order by t.parcelas), '[]'::jsonb)
    from taxa_banco t
    join provedor p on p.id = t.provedor_id
    cross join empresa e
    where t.ativo is true
      and (t.user_id = e.id or t.user_id is null or t.user_id = 0)
  );
end;
$$;

create or replace function public.rpc_produtos_para_selecao()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    with suc as (
      select
        m.id as material_id,
        (select count(*) from linha l where l.material_id = m.id) as linha_n,
        (select count(*) from tipo t where t.material_id = m.id) as tipo_n,
        (select count(*) from nivel n where n.material_id = m.id) as nivel_n,
        (select count(*) from borda b where b.material_id = m.id and b.ativo is true) as borda_n,
        (select count(distinct v.id)
           from produto p
           join detalhe d on d.id = p.detalhe_id
           join variacao v on v.detalhe_id = d.id
          where p.material_id = m.id and p.ativo is true) as variacao_n
      from material m
    ),
    materiais as (
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'nome', m.nome,
        'Ordenacao', m.ordenacao,
        'created_at', to_epoch_ms(m.created_at),
        'ativo', coalesce(m.ativo, true),
        'descricao', m.descricao,
        'ncm', m.ncm,
        'imp', m.imp,
        'ipi', m.ipi,
        'peso', m.peso,
        'st', m.st,
        'nac', m.nac,
        'Observacao', m.observacao,
        'organizacao_id', m.organizacao_id,
        'updated_at', to_epoch_ms(m.updated_at),
        'material_filho_id', m.material_id,
        'material_id', m.id,
        'garantia', m.garantia,
        'suc', jsonb_build_object(
          'Linha', coalesce(s.linha_n, 0),
          'Tipo', coalesce(s.tipo_n, 0),
          'Nivel', coalesce(s.nivel_n, 0),
          'Borda', coalesce(s.borda_n, 0),
          'Variacao', coalesce(s.variacao_n, 0)
        )
      ) order by m.ordenacao, m.nome)
      from material m
      left join suc s on s.material_id = m.id
      where m.ativo is true
    ),
    linhas as (
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'nome', l.nome,
        'created_at', to_epoch_ms(l.created_at),
        'material_id', l.material_id,
        '_material', case when m.nome is null then null else jsonb_build_object('nome', m.nome) end
      ) order by l.id)
      from linha l
      left join material m on m.id = l.material_id
    ),
    tipos as (
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'nome', t.nome,
        'material_id', t.material_id,
        'created_at', to_epoch_ms(t.created_at),
        '_material', case when m.nome is null then null else jsonb_build_object('nome', m.nome) end
      ) order by t.id)
      from tipo t
      left join material m on m.id = t.material_id
    ),
    niveis as (
      select jsonb_agg(jsonb_build_object(
        'id', n.id,
        'nome', n.nome,
        'Descricao', n.descricao,
        'material_id', n.material_id,
        'linha_id', n.linha_id,
        'tipo_id', n.tipo_id,
        'created_at', to_epoch_ms(n.created_at),
        '_material', case when m.nome is null then null else jsonb_build_object('nome', m.nome) end,
        '_linha', case when l.nome is null then null else jsonb_build_object('nome', l.nome) end,
        '_tipo', case when t.nome is null then null else jsonb_build_object('nome', t.nome) end
      ) order by n.id)
      from nivel n
      left join material m on m.id = n.material_id
      left join linha l on l.id = n.linha_id
      left join tipo t on t.id = n.tipo_id
    ),
    bordas as (
      select jsonb_agg(jsonb_build_object(
        'id', b.id,
        'nome', b.nome,
        'Obs', b.obs,
        'material_id', b.material_id,
        'valor', b.valor,
        'Unidade', b.unidade,
        'created_at', to_epoch_ms(b.created_at),
        'ativo', coalesce(b.ativo, true),
        '_material', case when m.nome is null then null else jsonb_build_object('nome', m.nome) end
      ) order by b.id)
      from borda b
      left join material m on m.id = b.material_id
      where b.ativo is true
    )
    select jsonb_build_object(
      'lista_para_selecao', jsonb_build_object(
        'Material', coalesce((select * from materiais), '[]'::jsonb),
        'Linha', coalesce((select * from linhas), '[]'::jsonb),
        'Tipo', coalesce((select * from tipos), '[]'::jsonb),
        'Nivel', coalesce((select * from niveis), '[]'::jsonb),
        'Borda', coalesce((select * from bordas), '[]'::jsonb)
      )
    )
  );
end;
$$;

create or replace function public.rpc_produtos_all()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select coalesce(jsonb_agg(prod order by prod->>'produto_id'), '[]'::jsonb)
    from (
      select jsonb_build_object(
        'material_id', p.material_id,
        'classificacao_id', p.classificacao_id,
        'linha_id', p.linha_id,
        'tipo_id', p.tipo_id,
        'nivel_id', p.nivel_id,
        'valor', p.valor,
        'ativo', coalesce(p.ativo, true),
        'com_medida_exata', coalesce(p.com_medida_exata, false),
        'porcentagem_acrescimo', p.porcentagem_acrescimo,
        'Unidade', p.unidade,
        'Base_de_Calculo', p.base_de_calculo,
        'tipo_composto', p.tipo_composto,
        'detalhe_id', p.detalhe_id,
        'fator_de_corte_id', p.fator_de_corte_id,
        'classificacao', c.nome,
        'descricao', concat_ws(' ', m.nome, l.nome, t.nome, n.nome),
        'produto_id', p.id,
        'material_nome', m.nome,
        'linha_nome', l.nome,
        'tipo_nome', t.nome,
        'nivel_nome', n.nome,
        'base_calculo', p.base_de_calculo,
        'und_produto', p.unidade,
        '_variacao', coalesce(vars.vars, '[]'::jsonb)
      ) as prod
      from produto p
      join material m on m.id = p.material_id and m.ativo is true
      left join classificacao c on c.id = p.classificacao_id
      left join linha l on l.id = p.linha_id
      left join tipo t on t.id = p.tipo_id
      left join nivel n on n.id = p.nivel_id
      left join lateral (
        select jsonb_agg(jsonb_build_object(
          'id', v.id,
          'created_at', to_epoch_ms(v.created_at),
          'detalhe_id', v.detalhe_id,
          'tipo_variacao_id', v.tipo_variacao_id,
          'comp', v.comp,
          'larg', v.larg,
          'modelo_id', v.modelo_id,
          'LxC', v.lxc,
          'qtd_kit', v.qtd_kit,
          'valor_custo', v.valor_custo,
          'cor_id', v.cor_id,
          'fator_de_corte', v.fator_de_corte_id,
          'ordem', v.ordem,
          'modelo', mo.descricao,
          'variacao', tv.descricao,
          'cor', co.descricao,
          'descricao', concat_ws(' ', d.descricao, tv.descricao, v.lxc, co.descricao)
        ) order by v.ordem, v.id) as vars
        from variacao v
        join detalhe d on d.id = v.detalhe_id
        left join modelo mo on mo.id = v.modelo_id
        left join tipo_variacao tv on tv.id = v.tipo_variacao_id
        left join cor co on co.id = v.cor_id
        where v.detalhe_id = p.detalhe_id
      ) vars on true
      where p.ativo is true
    ) sub
  );
end;
$$;

create or replace function public.rpc_produtos_suc_filtrado(
  p_material_id bigint default 0,
  p_linha_id bigint default 0,
  p_tipo_id bigint default 0
)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select jsonb_build_object(
      'Material_1',
      coalesce(
        (
          select jsonb_agg(jsonb_build_object(
            'Material_id', x.material_id,
            'Linha', x.linha_n,
            'Tipo', x.tipo_n,
            'Nivel', x.nivel_n,
            'Borda', x.borda_n,
            'Variacao', x.variacao_n
          ))
          from (
            select
              p.material_id,
              count(distinct l.id) as linha_n,
              count(distinct t.id) as tipo_n,
              count(distinct n.id) as nivel_n,
              count(distinct b.id) as borda_n,
              count(distinct v.id) as variacao_n
            from produto p
            left join linha l on l.id = p.linha_id
            left join tipo t on t.id = p.tipo_id
            left join nivel n on n.id = p.nivel_id
            left join borda b on b.material_id = p.material_id and b.ativo is true
            left join detalhe d on d.id = p.detalhe_id
            left join variacao v on v.detalhe_id = d.id
            where p.ativo is true
              and (p_material_id is null or p_material_id = 0 or p.material_id = p_material_id)
              and (p_linha_id is null or p_linha_id = 0 or p.linha_id = p_linha_id)
              and (p_tipo_id is null or p_tipo_id = 0 or p.tipo_id = p_tipo_id)
            group by p.material_id
          ) x
        ),
        '[]'::jsonb
      )
    )
  );
end;
$$;

-- =============================================================
-- Cliente
-- =============================================================

create or replace function public.cliente_user_busca(
  p_user_id bigint,
  p_busca text default null,
  p_pagina int default 1
)
returns jsonb language plpgsql security definer set search_path = public as $$
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
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

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

create or replace function public.cliente_por_id(p_user_id bigint, p_cliente_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_cliente jsonb;
  v_endereco jsonb;
  v_telefones jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

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

create or replace function public.cliente_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
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
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  if coalesce(nullif(p_payload->>'razao_social', ''), nullif(p_payload->>'nome_cpf', '')) is null then
    raise exception 'Informe a Razão Social (ou o Nome, para CPF).' using errcode = 'P0001';
  end if;
  if coalesce(nullif(p_payload->>'contato', ''), '') = '' then
    raise exception 'Informe o Contato.' using errcode = 'P0001';
  end if;
  if coalesce(jsonb_array_length(p_payload->'objphone'), 0) = 0 then
    raise exception 'Informe ao menos um telefone.' using errcode = 'P0001';
  end if;

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

create or replace function public.cliente_deletar(p_user_id bigint, p_cliente_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner record;
  v_qtd int;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

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

-- =============================================================
-- Orçamento
-- =============================================================

create or replace function public.novo_numero_orcamento(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_nome text;
  v_contador contador%rowtype;
  v_num bigint;
  v_new_orca text;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select name into v_nome from usuarios where id = p_user_id;

  insert into contador (user_id, descricao, inicial, numero)
  values (p_user_id, v_nome, 'ORC', 9999)
  on conflict (user_id) do nothing;

  select * into v_contador from contador where user_id = p_user_id for update;
  v_num := coalesce(v_contador.numero, 9999) + 1;
  v_new_orca := coalesce(v_contador.inicial, 'ORC') || v_num;
  update contador set numero = v_num where id = v_contador.id;

  return jsonb_build_object('newOrca', v_new_orca);
end;
$$;

create or replace function public.orcamento_item_inserir(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_orca_id bigint := coalesce((p_payload->>'orca_id')::bigint, 0);
  v_cod_orca text := nullif(p_payload->>'cod_orca', '');
  v_perfil jsonb := perfil_efetivo(v_user_id);
  v_org_id bigint := coalesce((v_perfil->>'organizacao_id')::bigint, 0);
  v_uf_origem text := 'PR';
  v_orca orca%rowtype;
  v_id_orca bigint := 0;
  v_recalc jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  if v_orca_id > 0 then
    select * into v_orca from orca where id = v_orca_id;
  elsif v_cod_orca is not null then
    select * into v_orca from orca where cod_orca = v_cod_orca and user_id = v_user_id;
  end if;

  if v_orca.id is not null and v_orca.user_id <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  if v_orca.id is not null and v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido. Edição bloqueada.' using errcode = 'P0001';
  end if;

  if v_org_id > 0 then
    select coalesce(uf, 'PR') into v_uf_origem from organizacao where id = v_org_id;
  end if;

  if v_orca.id is null then
    insert into orca (
      created_at, cod_orca, cliente_id, frt_b2b, frt_b2c, validade, user_id, margem, desconto,
      observacao, status, eh_pedido, regime_id, uf_origem, uf_destino, markup_alvo
    ) values (
      now(),
      v_cod_orca,
      nullif(coalesce((p_payload->>'cliente_id')::bigint, 0), 0),
      coalesce((p_payload->>'frtB2B')::numeric, 0),
      coalesce((p_payload->>'frtB2C')::numeric, 0),
      nullif(p_payload->>'validade', '')::date,
      v_user_id,
      coalesce((p_payload->>'margem')::numeric, 0),
      0,
      p_payload->>'observacao',
      'RASCUNHO',
      false,
      nullif(coalesce((v_perfil->>'regime_id')::bigint, 0), 0),
      v_uf_origem,
      coalesce(nullif(v_perfil->>'uf', ''), 'SP'),
      coalesce((p_payload->>'margem')::numeric, 0)
    ) returning id into v_id_orca;
  else
    v_id_orca := v_orca.id;
    update orca set observacao = p_payload->>'observacao', condicoes_pagamento = '' where id = v_id_orca;
  end if;

  insert into item (
    created_at, orca_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, detalhes_calculo
  ) values (
    now(),
    v_id_orca,
    coalesce((p_payload->>'produto_id')::bigint, 0),
    coalesce((p_payload->>'ipi')::numeric, 0),
    coalesce((p_payload->>'imp')::numeric, 0),
    coalesce((p_payload->>'vlr_custo')::numeric, 0),
    p_payload->>'base_calculo',
    p_payload->>'und_produto',
    coalesce((p_payload->>'larg')::numeric, 0),
    coalesce((p_payload->>'comp')::numeric, 0),
    coalesce((p_payload->>'larg_fc')::numeric, 0),
    coalesce((p_payload->>'comp_fc')::numeric, 0),
    nullif(coalesce((p_payload->>'borda_id')::bigint, 0), 0),
    coalesce((p_payload->>'vlr_cst_borda')::numeric, 0),
    p_payload->>'und_borda',
    nullif(coalesce((p_payload->>'tipo_fator_id')::bigint, 0), 0),
    nullif(coalesce((p_payload->>'detalhe_id')::bigint, 0), 0),
    nullif(coalesce((p_payload->>'fator_de_corte_id')::bigint, 0), 0),
    nullif(coalesce((p_payload->>'variacao_id')::bigint, 0), 0),
    coalesce((p_payload->>'margem')::numeric, 0),
    coalesce((p_payload->>'qtd')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_unit_ipi')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_unit_imp')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit_ipi')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit_imp')::numeric, 0),
    coalesce((p_payload->>'vlr_lucro_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit_b2b')::numeric, 0),
    p_payload->>'descricao',
    coalesce((p_payload->>'area_user')::numeric, 0),
    coalesce((p_payload->>'area_calc')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_nota_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_entrada_unit')::numeric, 0),
    coalesce((p_payload->>'valor_difal_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_credito_icms_unit')::numeric, 0),
    coalesce((p_payload->>'aliq_inter')::numeric, 0),
    coalesce((p_payload->>'aliq_interna')::numeric, 0),
    coalesce((p_payload->>'perc_difal')::numeric, 0),
    coalesce((p_payload->>'vlr_frete_b2b_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_st_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_custo_fiscal_unit')::numeric, 0),
    coalesce((p_payload->>'eh_importado')::boolean, false),
    coalesce((p_payload->>'perc_margem_real')::numeric, 0),
    coalesce((p_payload->>'com_medida_exata')::boolean, false),
    coalesce((p_payload->>'porcentagem_acrescimo')::numeric, 0),
    case when jsonb_typeof(p_payload->'fc') = 'array'
      then array(select elem::numeric from jsonb_array_elements_text(p_payload->'fc') as elem)
      else '{}'::numeric[] end,
    p_payload->'detalhes_calculo'
  );

  v_recalc := orcamento_recalcular_totais(v_id_orca, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

create or replace function public.orcamento_item_atualizar(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_item_id bigint := coalesce((p_payload->>'item_id')::bigint, 0);
  v_item item%rowtype;
  v_perfil jsonb := perfil_efetivo(v_user_id);
  v_recalc jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select * into v_item from item where id = v_item_id;
  if not found then
    raise exception 'Item não encontrado.' using errcode = 'P0001';
  end if;

  if (select user_id from orca where id = v_item.orca_id) <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  update item set
    produto_id = coalesce((p_payload->>'produto_id')::bigint, 0),
    ipi = coalesce((p_payload->>'ipi')::numeric, 0),
    imp = coalesce((p_payload->>'imp')::numeric, 0),
    vlr_custo = coalesce((p_payload->>'vlr_custo')::numeric, 0),
    base_calculo = p_payload->>'base_calculo',
    und_produto = p_payload->>'und_produto',
    larg = coalesce((p_payload->>'larg')::numeric, 0),
    comp = coalesce((p_payload->>'comp')::numeric, 0),
    larg_fc = coalesce((p_payload->>'larg_fc')::numeric, 0),
    comp_fc = coalesce((p_payload->>'comp_fc')::numeric, 0),
    borda_id = nullif(coalesce((p_payload->>'borda_id')::bigint, 0), 0),
    vlr_cst_borda = coalesce((p_payload->>'vlr_cst_borda')::numeric, 0),
    und_borda = p_payload->>'und_borda',
    tipo_fator_id = nullif(coalesce((p_payload->>'tipo_fator_id')::bigint, 0), 0),
    fator_de_corte_id = nullif(coalesce((p_payload->>'fator_de_corte_id')::bigint, 0), 0),
    detalhe_id = nullif(coalesce((p_payload->>'detalhe_id')::bigint, 0), 0),
    variacao_id = nullif(coalesce((p_payload->>'variacao_id')::bigint, 0), 0),
    margem = coalesce((p_payload->>'margem')::numeric, 0),
    qtd = coalesce((p_payload->>'qtd')::numeric, 0),
    vlr_cst_unit = coalesce((p_payload->>'vlr_cst_unit')::numeric, 0),
    vlr_cst_unit_ipi = coalesce((p_payload->>'vlr_cst_unit_ipi')::numeric, 0),
    vlr_cst_unit_imp = coalesce((p_payload->>'vlr_cst_unit_imp')::numeric, 0),
    vlr_vnd_unit = coalesce((p_payload->>'vlr_vnd_unit')::numeric, 0),
    vlr_vnd_unit_ipi = coalesce((p_payload->>'vlr_vnd_unit_ipi')::numeric, 0),
    vlr_vnd_unit_imp = coalesce((p_payload->>'vlr_vnd_unit_imp')::numeric, 0),
    vlr_vnd_unit_b2b = coalesce((p_payload->>'vlr_vnd_unit_b2b')::numeric, 0),
    vlr_lucro_unit = coalesce((p_payload->>'vlr_lucro_unit')::numeric, 0),
    descricao = p_payload->>'descricao',
    area_user = coalesce((p_payload->>'area_user')::numeric, 0),
    area_calc = coalesce((p_payload->>'area_calc')::numeric, 0),
    vlr_cst_nota_unit = coalesce((p_payload->>'vlr_cst_nota_unit')::numeric, 0),
    vlr_cst_entrada_unit = coalesce((p_payload->>'vlr_cst_entrada_unit')::numeric, 0),
    valor_difal_unit = coalesce((p_payload->>'valor_difal_unit')::numeric, 0),
    vlr_credito_icms_unit = coalesce((p_payload->>'vlr_credito_icms_unit')::numeric, 0),
    aliq_inter = coalesce((p_payload->>'aliq_inter')::numeric, 0),
    aliq_interna = coalesce((p_payload->>'aliq_interna')::numeric, 0),
    perc_difal = coalesce((p_payload->>'perc_difal')::numeric, 0),
    vlr_frete_b2b_unit = coalesce((p_payload->>'vlr_frete_b2b_unit')::numeric, 0),
    vlr_st_unit = coalesce((p_payload->>'vlr_st_unit')::numeric, 0),
    vlr_custo_fiscal_unit = coalesce((p_payload->>'vlr_custo_fiscal_unit')::numeric, 0),
    eh_importado = coalesce((p_payload->>'eh_importado')::boolean, false),
    perc_margem_real = coalesce((p_payload->>'perc_margem_real')::numeric, 0),
    com_medida_exata = coalesce((p_payload->>'com_medida_exata')::boolean, false),
    porcentagem_acrescimo = coalesce((p_payload->>'porcentagem_acrescimo')::numeric, 0),
    fc = case when jsonb_typeof(p_payload->'fc') = 'array'
      then array(select elem::numeric from jsonb_array_elements_text(p_payload->'fc') as elem)
      else '{}'::numeric[] end,
    detalhes_calculo = p_payload->'detalhes_calculo'
  where id = v_item_id;

  update orca set condicoes_pagamento = '' where id = v_item.orca_id;

  v_recalc := orcamento_recalcular_totais(v_item.orca_id, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

create or replace function public.orcamento_item_deletar(p_item_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_item item%rowtype;
  v_perfil jsonb;
  v_recalc jsonb;
begin
  if auth_user_id() is null or not exists (
    select 1 from item i join orca o on o.id = i.orca_id
    where i.id = p_item_id and o.user_id = auth_user_id()
  ) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select * into v_item from item where id = p_item_id;
  if not found then
    raise exception 'Item não encontrado.' using errcode = 'P0001';
  end if;

  delete from item where id = p_item_id;

  v_perfil := perfil_efetivo((select user_id from orca where id = v_item.orca_id));
  v_recalc := orcamento_recalcular_totais(v_item.orca_id, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

create or replace function public.orcamento_recalcular(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_orca_id bigint := coalesce((p_payload->>'orca_id')::bigint, 0);
  v_new_margem numeric := nullif(p_payload->>'newMargem', '')::numeric;
  v_frt_b2c numeric := coalesce((p_payload->>'frtB2C')::numeric, 0);
  v_desconto numeric := coalesce((p_payload->>'desconto')::numeric, 0);
  v_mao_obra numeric := coalesce((p_payload->>'maoDeObra')::numeric, 0);
  v_observacao text := p_payload->>'observacao';
  v_cond_pgto text := p_payload->>'condicoesPagamento';
  v_cond_params text := p_payload->>'condicoesPagamentoParams';

  v_orca orca%rowtype;
  v_caller record;
  v_root record;
  v_root_id bigint;
  v_pai_id bigint;
  v_eh_filho boolean;
  v_livre numeric := 0;
  v_max_desc numeric := 0;
  v_aprovado boolean := true;
  v_status_desc text := 'aprovado';
  v_acima_max boolean := false;
  v_gross numeric := 0;
  v_desc_val numeric := 0;
  v_perc numeric := 0;
  v_pix_perc numeric := 0;
  v_margem_usar numeric;
  v_recalc jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = v_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_orca.user_id <> v_user_id then
    raise exception 'Acesso negado: apenas o dono pode alterar o orçamento.' using errcode = 'P0001';
  end if;
  if v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido. Edição bloqueada.' using errcode = 'P0001';
  end if;

  select id, role, vendedor_pai_id, desconto_livre_perc, desconto_max_perc
    into v_caller from usuarios where id = v_user_id;

  v_root_id := f_empresa_id(v_user_id);
  select id, desconto_livre_perc, desconto_max_perc, frt_b2b
    into v_root from usuarios where id = v_root_id;

  v_eh_filho := (v_caller.role = 'vendedor' or v_caller.role = 'vendedor_master');

  v_margem_usar := v_new_margem;
  if v_eh_filho then
    v_margem_usar := null;
  end if;

  v_livre := coalesce(nullif(v_caller.desconto_livre_perc, 0), nullif(v_root.desconto_livre_perc, 0), 0);
  v_max_desc := coalesce(nullif(v_caller.desconto_max_perc, 0), nullif(v_root.desconto_max_perc, 0), 0);

  if v_eh_filho then
    v_gross := coalesce(v_orca.venda_bruta_tot, 0);
    if v_gross = 0 then
      v_gross := coalesce(v_orca.vnd_tot, 0) + coalesce(v_orca.desconto, 0);
    end if;
    if v_gross > 0 then
      v_desc_val := v_desconto;
      v_perc := v_desc_val * 100 / v_gross;

      v_pix_perc := 0;
      if v_cond_params is not null and v_cond_params <> '' then
        begin
          v_pix_perc := coalesce((v_cond_params::jsonb->>'descontoPixPercentual')::numeric, 0);
        exception when others then
          v_pix_perc := 0;
        end;
      end if;

      if v_pix_perc > v_perc then
        v_perc := v_pix_perc;
        v_desc_val := v_gross * v_perc / 100;
      end if;

      if v_perc > v_max_desc then
        v_acima_max := true;
      end if;
      if v_perc > v_livre and v_desc_val > 0 then
        v_aprovado := false;
      end if;
    end if;
  end if;

  if not v_aprovado then
    v_status_desc := 'pendente';
  end if;

  if v_eh_filho and not v_aprovado and v_orca.desconto_status is distinct from 'pendente' then
    v_pai_id := coalesce(v_caller.vendedor_pai_id, 0);
    if v_pai_id > 0 then
      insert into notificacao (user_id, tipo, orca_id, lida) values (v_pai_id, 'desconto_pendente', v_orca_id, false);
    end if;
    if v_root_id > 0 and v_root_id <> v_pai_id then
      insert into notificacao (user_id, tipo, orca_id, lida) values (v_root_id, 'desconto_pendente', v_orca_id, false);
    end if;
  end if;

  if v_acima_max then
    raise exception 'Desconto acima do máximo permitido para a equipe.' using errcode = 'P0001';
  end if;

  update orca set
    frt_b2c = v_frt_b2c,
    desconto = v_desconto,
    desconto_aprovado = v_aprovado,
    desconto_status = v_status_desc,
    mao_de_obra = v_mao_obra,
    observacao = v_observacao,
    condicoes_pagamento = v_cond_pgto,
    condicoes_pagamento_params = v_cond_params
  where id = v_orca_id;

  v_recalc := orcamento_recalcular_totais(v_orca_id, v_margem_usar, coalesce(v_root.frt_b2b, 0));
  return v_recalc;
end;
$$;

create or replace function public.orcamento_status(
  p_user_id bigint,
  p_orca_id bigint,
  p_status text,
  p_motivo text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca orca%rowtype;
  v_caller record;
  v_eh_filho boolean;
  v_desc_pendente boolean := false;
  v_data_envio timestamptz;
  v_data_aprovacao timestamptz;
  v_motivo_recusa text;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_orca.user_id <> p_user_id then
    raise exception 'Acesso negado: apenas o dono pode alterar o status.' using errcode = 'P0001';
  end if;

  select id, role into v_caller from usuarios where id = p_user_id;
  v_eh_filho := v_caller.role = 'vendedor' or v_caller.role = 'vendedor_master';

  if v_eh_filho and coalesce(v_orca.desconto, 0) > 0
     and (
       v_orca.desconto_status = 'pendente'
       or v_orca.desconto_status = 'recusado'
       or (v_orca.desconto_status is null and v_orca.desconto_aprovado is false)
     ) then
    v_desc_pendente := true;
  end if;

  if v_desc_pendente and p_status not in ('RASCUNHO', 'CANCELADO', 'RECUSADO') then
    raise exception 'Desconto acima do limite aguarda aprovação do pai.' using errcode = 'P0001';
  end if;

  if v_orca.eh_pedido is true and p_status not in ('FATURADO', 'ENTREGUE', 'CANCELADO') then
    raise exception 'Este orçamento foi convertido em pedido. Só é possível Faturar (FATURADO), Entregar (ENTREGUE) ou Cancelar (CANCELADO).' using errcode = 'P0001';
  end if;

  v_data_envio := v_orca.data_envio;
  v_data_aprovacao := v_orca.data_aprovacao;
  v_motivo_recusa := v_orca.motivo_recusa;

  if p_status in ('AGUARDANDO_RETORNO', 'ENVIADO') then
    v_data_envio := now();
  end if;
  if p_status = 'APROVADO' then
    v_data_aprovacao := now();
  end if;
  if p_status in ('RECUSADO', 'CANCELADO') then
    v_motivo_recusa := coalesce(nullif(p_motivo, ''), v_orca.motivo_recusa);
  end if;

  update orca set
    status = p_status,
    data_envio = v_data_envio,
    data_aprovacao = v_data_aprovacao,
    motivo_recusa = v_motivo_recusa
  where id = p_orca_id;

  insert into orca_status_log (created_at, orca_id, status, status_anterior, user_id, motivo)
  values (now(), p_orca_id, p_status, v_orca.status, p_user_id, nullif(p_motivo, ''));

  return jsonb_build_object('ORCA_1', (f_orca_detalhes(p_orca_id))->'ORCA_1');
end;
$$;

create or replace function public.orcamento_status_historico(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_pode_ver_orca(p_user_id, p_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select coalesce(jsonb_agg(to_jsonb(l) order by l.created_at desc, l.id desc), '[]'::jsonb)
    from orca_status_log l where l.orca_id = p_orca_id
  );
end;
$$;

create or replace function public.orcamento_status_lista(p_user_id bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select coalesce(
      jsonb_agg(jsonb_build_object('id', o.id, 'status', o.status) order by o.id),
      '[]'::jsonb
    )
    from orca o
    where o.user_id = p_user_id
  );
end;
$$;

create or replace function public.orcamento_converter_pedido(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca orca%rowtype;
  v_num_pedido text;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_orca.user_id <> p_user_id then
    raise exception 'Acesso negado: apenas o dono pode converter o orçamento.' using errcode = 'P0001';
  end if;

  if v_orca.eh_pedido is true then
    raise exception 'Este orçamento já foi convertido em pedido.' using errcode = 'P0001';
  end if;
  if v_orca.status <> 'APROVADO' then
    raise exception 'Apenas orçamentos APROVADOS podem ser convertidos em pedido.' using errcode = 'P0001';
  end if;

  select num_pedido_fabrica into v_num_pedido
  from controle_pedido where orca_id = p_orca_id order by id asc limit 1;

  if v_num_pedido is null or v_num_pedido = '' then
    raise exception 'Registre o Nº do Pedido da Fábrica (Kapazi) antes de converter em pedido.' using errcode = 'P0001';
  end if;

  update orca set status = 'AGUARDANDO_FATURAMENTO', eh_pedido = true where id = p_orca_id;

  insert into orca_status_log (created_at, orca_id, status, status_anterior, user_id, motivo)
  values (now(), p_orca_id, 'AGUARDANDO_FATURAMENTO', v_orca.status, p_user_id, 'Convertido em pedido');

  return jsonb_build_object('ORCA_1', (f_orca_detalhes(p_orca_id))->'ORCA_1');
end;
$$;

create or replace function public.orcamento_aprovar_desconto(
  p_user_id bigint,
  p_orca_id bigint,
  p_aprovado boolean default true
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca record;
  v_viewer record;
  v_owner record;
  v_pai record;
  v_permitido boolean := false;
  v_status text;
  v_notif_tipo text;
  v_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select id, user_id into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;

  select id, role, vendedor_pai_id into v_viewer from usuarios where id = p_user_id;
  select id, role, vendedor_pai_id into v_owner from usuarios where id = v_orca.user_id;

  if v_viewer.role = 'admin_geral' then
    v_permitido := true;
  elsif coalesce(v_owner.vendedor_pai_id, 0) > 0 then
    if v_owner.vendedor_pai_id = p_user_id then
      v_permitido := true;
    else
      select role, vendedor_pai_id into v_pai from usuarios where id = v_owner.vendedor_pai_id;
      if v_pai.role = 'vendedor_master' and v_pai.vendedor_pai_id = p_user_id then
        v_permitido := true;
      end if;
    end if;
  end if;

  if not v_permitido then
    raise exception 'Apenas o pai/administrador pode aprovar o desconto.' using errcode = 'P0001';
  end if;

  if p_aprovado then
    v_status := 'aprovado';
    v_notif_tipo := 'desconto_aprovado';
  else
    v_status := 'recusado';
    v_notif_tipo := 'desconto_recusado';
  end if;

  insert into notificacao (created_at, user_id, tipo, orca_id, lida)
  values (now(), v_orca.user_id, v_notif_tipo, p_orca_id, false);

  update orca set desconto_aprovado = p_aprovado, desconto_status = v_status
  where id = p_orca_id returning id into v_id;

  return jsonb_build_object('id', v_id, 'desconto_aprovado', p_aprovado);
end;
$$;

create or replace function public.orcamentos_pendentes_aprovacao(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_linhas jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'user_id', o.user_id,
      'cod_orca', coalesce(nullif(o.cod_orca, ''), '#' || o.id),
      'vendedor', coalesce(nullif(u.name_first, ''), 'Vendedor ' || o.user_id),
      'venda', coalesce(o.vnd_tot, 0),
      'desconto', coalesce(o.desconto, 0),
      'data', coalesce(to_char(o.created_at, 'YYYY-MM-DD'), '')
    )
    order by o.created_at desc
  ), '[]'::jsonb)
  into v_linhas
  from orca o
  left join usuarios u on u.id = o.user_id
  where o.desconto_aprovado is false
    and o.desconto > 0
    and coalesce(o.desconto_status, '') <> 'recusado'
    and (
      v_me.role = 'admin_geral'
      or u.vendedor_pai_id = p_user_id
      or exists (
        select 1 from usuarios pai
        where pai.id = u.vendedor_pai_id
          and pai.role = 'vendedor_master'
          and pai.vendedor_pai_id = p_user_id
      )
    );

  return jsonb_build_object('linhas', v_linhas);
end;
$$;

create or replace function public.orcamento_deletar(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca record;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select id, user_id, eh_pedido into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_orca.user_id <> p_user_id then
    raise exception 'Você não pode excluir esse orçamento.' using errcode = 'P0001';
  end if;
  if v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido não pode ser excluído.' using errcode = 'P0001';
  end if;

  delete from item where orca_id = p_orca_id;
  delete from boleto where orca_id = p_orca_id;
  delete from comissao where orca_id = p_orca_id;
  delete from controle_pedido where orca_id = p_orca_id;
  delete from desconto_kapazi_log where orca_id = p_orca_id;
  delete from gerados where orca_id = p_orca_id;
  delete from notificacao where orca_id = p_orca_id;
  delete from orca_status_log where orca_id = p_orca_id;
  delete from orca where id = p_orca_id;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.orcamento_duplicar(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca orca%rowtype;
  v_new_cod text;
  v_new_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if not f_dono_ou_admin(p_user_id, p_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  v_new_cod := (novo_numero_orcamento(p_user_id))->>'newOrca';

  insert into orca (
    created_at, cod_orca, cliente_id, frt_b2b, frt_b2c, validade, user_id, margem,
    markup_alvo, markup_efetivo, cst_tot, luc_tot, vnd_tot, vnd_b2b_tot, vnd_b2b_b2c_tot,
    venda_bruta_tot, desconto, mao_de_obra, vlr_st_tot, valor_difal_tot, vlr_credito_icms_tot,
    vlr_custo_fiscal_tot, vlr_ipi_tot, total_itens, observacao, condicoes_pagamento,
    condicoes_pagamento_params, regime_id, uf_origem, uf_destino,
    desconto_aprovado, desconto_status
  ) values (
    now(), v_new_cod, v_orca.cliente_id, v_orca.frt_b2b, v_orca.frt_b2c, v_orca.validade,
    p_user_id, v_orca.margem, v_orca.markup_alvo, v_orca.markup_efetivo, v_orca.cst_tot,
    v_orca.luc_tot, v_orca.vnd_tot, v_orca.vnd_b2b_tot, v_orca.vnd_b2b_b2c_tot,
    v_orca.venda_bruta_tot, v_orca.desconto, v_orca.mao_de_obra, v_orca.vlr_st_tot,
    v_orca.valor_difal_tot, v_orca.vlr_credito_icms_tot, v_orca.vlr_custo_fiscal_tot,
    v_orca.vlr_ipi_tot, v_orca.total_itens, v_orca.observacao, v_orca.condicoes_pagamento,
    v_orca.condicoes_pagamento_params, v_orca.regime_id, v_orca.uf_origem, v_orca.uf_destino,
    true, 'aprovado'
  ) returning id into v_new_id;

  insert into item (
    created_at, orca_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, vlr_vnd_unit_bruto, detalhes_calculo
  )
  select now(), v_new_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, vlr_vnd_unit_bruto, detalhes_calculo
  from item where orca_id = p_orca_id;

  return jsonb_build_object('orca', jsonb_build_object('cod_orca', v_new_cod, 'id', v_new_id));
end;
$$;

create or replace function public.orca_detalhes(p_user_id bigint, p_cod_orca text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id into v_orca_id from orca where cod_orca = p_cod_orca and user_id = p_user_id;
  if v_orca_id is null then
    raise exception 'Orçamento não encontrado para o seu usuário.' using errcode = 'P0001';
  end if;
  return f_orca_detalhes(v_orca_id);
end;
$$;

create or replace function public.orca_por_id(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_viewer record;
  v_owner record;
  v_pai record;
  v_permitido boolean := false;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role, vendedor_pai_id into v_viewer from usuarios where id = p_user_id;
  select user_id into v_owner from orca where id = p_orca_id;
  if v_owner.user_id is null then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  select id, role, vendedor_pai_id into v_owner from usuarios where id = v_owner.user_id;

  if v_viewer.role = 'admin_geral' or v_owner.id = p_user_id then
    v_permitido := true;
  elsif coalesce(v_owner.vendedor_pai_id, 0) > 0 then
    if v_owner.vendedor_pai_id = p_user_id then
      v_permitido := true;
    else
      select role, vendedor_pai_id into v_pai from usuarios where id = v_owner.vendedor_pai_id;
      if v_pai.role = 'vendedor_master' and v_pai.vendedor_pai_id = p_user_id then
        v_permitido := true;
      end if;
    end if;
  end if;

  if not v_permitido then
    raise exception 'Você não tem acesso a este orçamento.' using errcode = 'P0001';
  end if;

  return f_orca_detalhes(p_orca_id);
end;
$$;

create or replace function public.orca_por_cliente_busca(
  p_user_id bigint,
  p_busca text default null,
  p_page int default 1,
  p_per_page int default 20,
  p_so_pedidos boolean default false,
  p_somente_orcamentos boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_busca text := nullif(trim(coalesce(p_busca, '')), '');
  v_busca_norm text := nullif(unaccent(lower(v_busca)), '');
  v_busca_num text := nullif(regexp_replace(v_busca, '[^0-9]', '', 'g'), '');
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_per int := greatest(coalesce(p_per_page, 20), 1);
  v_offset int := (v_page - 1) * v_per;
  v_total int;
  v_items jsonb;
  v_items_received int;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  create temp table _lista on commit drop as
  select
    o.id, o.created_at, o.cod_orca, o.cliente_id, o.frt_b2b, o.frt_b2c, o.validade,
    o.user_id, o.margem, o.cst_tot, o.luc_tot, o.vnd_tot, o.vnd_b2b_tot, o.vnd_b2b_b2c_tot,
    o.desconto, o.eh_pedido, o.status, o.data_envio, o.data_aprovacao, o.total_itens, o.mao_de_obra,
    c.nome_fantasia, c.razao_social, c.contato, c.cpf, c.cnpj, c.inscricao_estadual
  from orca o
  left join cliente c on c.id = o.cliente_id
  where o.user_id = p_user_id
    and (
      (p_so_pedidos and o.eh_pedido = true)
      or (p_somente_orcamentos and o.eh_pedido is not true)
      or ((p_so_pedidos is not true) and (p_somente_orcamentos is not true))
    )
    and (
      v_busca_norm is null
      or unaccent(lower(coalesce(o.cod_orca, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(c.nome_fantasia, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(c.razao_social, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(c.contato, ''))) like '%' || v_busca_norm || '%'
      or (
        v_busca_num is not null and v_busca_num <> ''
        and (
          regexp_replace(coalesce(c.cnpj, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
          or regexp_replace(coalesce(c.cpf, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
          or regexp_replace(coalesce(c.inscricao_estadual, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
        )
      )
      or (o.cliente_id is not null and o.cliente_id::text = v_busca)
    );

  select count(*) into v_total from _lista;

  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_items
  from (select * from _lista order by created_at desc, id desc limit v_per offset v_offset) t;

  v_items_received := coalesce(jsonb_array_length(v_items), 0);

  return jsonb_build_object(
    'itemsReceived', v_items_received,
    'curPage', v_page,
    'nextPage', case when v_offset + v_per < v_total then v_page + 1 else null end,
    'prevPage', case when v_page > 1 then v_page - 1 else null end,
    'offset', v_offset,
    'itemsTotal', v_total,
    'pageTotal', case when v_per > 0 then ceil(v_total::numeric / v_per)::int else 0 end,
    'items', v_items
  );
end;
$$;

-- =============================================================
-- Controle de pedido (Kapazi)
-- =============================================================

create or replace function public.controle_pedido_por_orca(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_pode_ver_orca(p_user_id, p_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select to_jsonb(c)
      || jsonb_build_object(
        'transportadoraB2B', c.transportadora_b2b,
        'transportadoraB2C', c.transportadora_b2c,
        'dataPrevisao', c.data_previsao,
        'dataChegada', c.data_chegada,
        'freteB2BReal', c.frete_b2b_real,
        'freteB2CReal', c.frete_b2c_real
      )
    from controle_pedido c
    where c.orca_id = p_orca_id
    order by c.id asc
    limit 1
  );
end;
$$;

create or replace function public.controle_pedido_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca_id bigint := coalesce((p_payload->>'orca_id')::bigint, 0);
  v_old_perc numeric;
  v_new_perc numeric := nullif(p_payload->>'desconto_kapazi_perc', '')::numeric;
  v_controle controle_pedido%rowtype;
  v_id bigint;
  v_base_custo numeric;
  v_frete_efetivo numeric;
  v_valor_log numeric;
  v_orca_frt_b2b numeric;
  v_motivo text := nullif(p_payload->>'desconto_kapazi_motivo', '');
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  if v_orca_id <= 0 then
    raise exception 'orca_id é obrigatório.' using errcode = 'P0001';
  end if;
  if not f_dono_ou_admin(p_user_id, v_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select desconto_kapazi_perc into v_old_perc from controle_pedido where orca_id = v_orca_id order by id asc limit 1;
  select * into v_controle from controle_pedido where orca_id = v_orca_id order by id asc limit 1;

  if v_controle.id is null then
    insert into controle_pedido (
      orca_id, data_envio_fabrica, num_pedido_fabrica, data_aprovacao_layout, num_pedido_venda,
      num_nf, forma_pagamento_fabrica, desconto_kapazi_perc, cod_rastreio,
      transportadora_b2b, transportadora_b2c, data_previsao, data_chegada,
      frete_b2b_real, frete_b2c_real, user_id
    ) values (
      v_orca_id,
      nullif(p_payload->>'data_envio_fabrica', '')::date,
      nullif(p_payload->>'num_pedido_fabrica', ''),
      nullif(p_payload->>'data_aprovacao_layout', '')::date,
      nullif(p_payload->>'num_pedido_venda', ''),
      nullif(p_payload->>'num_nf', ''),
      nullif(p_payload->>'forma_pagamento_fabrica', ''),
      v_new_perc,
      nullif(p_payload->>'cod_rastreio', ''),
      nullif(p_payload->>'transportadoraB2B', ''),
      nullif(p_payload->>'transportadoraB2C', ''),
      nullif(p_payload->>'dataPrevisao', '')::date,
      nullif(p_payload->>'dataChegada', '')::date,
      nullif(p_payload->>'freteB2BReal', '')::numeric,
      nullif(p_payload->>'freteB2CReal', '')::numeric,
      p_user_id
    ) returning id into v_id;
  else
    v_id := v_controle.id;
    update controle_pedido set
      data_envio_fabrica = nullif(p_payload->>'data_envio_fabrica', '')::date,
      num_pedido_fabrica = nullif(p_payload->>'num_pedido_fabrica', ''),
      data_aprovacao_layout = nullif(p_payload->>'data_aprovacao_layout', '')::date,
      num_pedido_venda = nullif(p_payload->>'num_pedido_venda', ''),
      num_nf = nullif(p_payload->>'num_nf', ''),
      forma_pagamento_fabrica = nullif(p_payload->>'forma_pagamento_fabrica', ''),
      desconto_kapazi_perc = v_new_perc,
      cod_rastreio = nullif(p_payload->>'cod_rastreio', ''),
      transportadora_b2b = nullif(p_payload->>'transportadoraB2B', ''),
      transportadora_b2c = nullif(p_payload->>'transportadoraB2C', ''),
      data_previsao = nullif(p_payload->>'dataPrevisao', '')::date,
      data_chegada = nullif(p_payload->>'dataChegada', '')::date,
      frete_b2b_real = nullif(p_payload->>'freteB2BReal', '')::numeric,
      frete_b2c_real = nullif(p_payload->>'freteB2CReal', '')::numeric,
      user_id = p_user_id
    where id = v_controle.id;
  end if;

  if p_payload ? 'compra_numero' then
    update orca set compra_numero = nullif(p_payload->>'compra_numero', '') where id = v_orca_id;
  end if;

  if v_new_perc is not null and (v_old_perc is null or v_new_perc <> v_old_perc) then
    select coalesce(sum(coalesce(i.vlr_cst_nota_unit, 0) * coalesce(i.qtd, 0)), 0)
    into v_base_custo
    from item i where i.orca_id = v_orca_id;

    select coalesce(frt_b2b, 0) into v_orca_frt_b2b from orca where id = v_orca_id;

    if coalesce(nullif(p_payload->>'freteB2BReal', '')::numeric, 0) > 0 then
      v_frete_efetivo := nullif(p_payload->>'freteB2BReal', '')::numeric;
    else
      v_frete_efetivo := coalesce(v_orca_frt_b2b, 0);
    end if;

    v_valor_log := v_base_custo * v_new_perc / 100;

    insert into desconto_kapazi_log (
      orca_id, desconto_anterior, desconto_novo, valor_desconto_rs, frete_efetivo_rs, user_id, motivo, created_at
    ) values (
      v_orca_id, v_old_perc, v_new_perc, v_valor_log, v_frete_efetivo, p_user_id, v_motivo, now()
    );
  end if;

  return (
    select to_jsonb(c)
      || jsonb_build_object(
        'transportadoraB2B', c.transportadora_b2b,
        'transportadoraB2C', c.transportadora_b2c,
        'dataPrevisao', c.data_previsao,
        'dataChegada', c.data_chegada,
        'freteB2BReal', c.frete_b2b_real,
        'freteB2CReal', c.frete_b2c_real
      )
    from controle_pedido c where c.id = v_id
  );
end;
$$;

-- =============================================================
-- Pagamentos / Financeiro
-- =============================================================

create or replace function public.pagamentos(p_user_id bigint, p_orca_id bigint default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return (
    select coalesce(jsonb_agg(
      to_jsonb(b)
        || jsonb_build_object(
          'cod_orca', o.cod_orca,
          'eh_pedido', o.eh_pedido,
          'forma', fp.tipo,
          'cliente_id', o.cliente_id
        )
      order by b.vencimento asc, b.id asc
    ), '[]'::jsonb)
    from boleto b
    join orca o on o.id = b.orca_id
    join forma_pagamento fp on fp.id = b.forma_pagamento_id
    where b.user_id = p_user_id
      and (p_orca_id is null or b.orca_id = p_orca_id)
  );
end;
$$;

create or replace function public.pagamento_salvar(p_user_id bigint, p_orca_id bigint, p_parcelas jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner record;
  v_parcela jsonb;
  v_qtd int := 0;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select id, user_id into v_owner from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_owner.user_id <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  delete from boleto where orca_id = p_orca_id;

  for v_parcela in select value from jsonb_array_elements(coalesce(p_parcelas, '[]'::jsonb)) loop
    insert into boleto (created_at, orca_id, vencimento, valor, forma_pagamento_id, user_id)
    values (
      now(),
      p_orca_id,
      nullif(v_parcela->>'vencimento', '')::date,
      coalesce((v_parcela->>'valor')::numeric, 0),
      coalesce((v_parcela->>'forma_pagamento_id')::bigint, 0),
      p_user_id
    );
    v_qtd := v_qtd + 1;
  end loop;

  return jsonb_build_object('ok', true, 'quantidade', v_qtd);
end;
$$;

create or replace function public.pagamento_excluir(p_user_id bigint, p_boleto_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b boleto%rowtype;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select * into v_b from boleto where id = p_boleto_id;
  if not found then
    raise exception 'Parcela não encontrada.' using errcode = 'P0001';
  end if;
  if v_b.user_id <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  delete from boleto where id = p_boleto_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.pagamento_baixa(
  p_user_id bigint,
  p_boleto_id bigint,
  p_pagamento date default null,
  p_estornar boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b boleto%rowtype;
  v_orca orca%rowtype;
  v_dono record;
  v_master record;
  v_empresa record;
  v_faixas jsonb := null;
  v_parcelas jsonb;
  v_nao_pagas int;
  v_pago_completo boolean;
  v_markup_ef numeric;
  v_total_faixa numeric := 0;
  v_pct_ponta numeric := 0;
  v_override numeric := 0;
  v_base numeric;
  v_custo_kapazi numeric := 0;
  v_controle_perc numeric := 0;
  v_frete_real numeric := 0;
  v_log_perc numeric := null;
  v_perc numeric := 0;
  v_desconto_kapazi numeric;
  v_frete_efetivo numeric;
  v_lucro_real numeric;
  v_ja_existe int;
  v_faixa jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select * into v_b from boleto where id = p_boleto_id;
  if not found then
    raise exception 'Parcela não encontrada.' using errcode = 'P0001';
  end if;
  if v_b.user_id <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  if p_estornar then
    update boleto set pagamento = null where id = p_boleto_id;
  else
    update boleto set pagamento = coalesce(p_pagamento, current_date) where id = p_boleto_id;
  end if;

  if not p_estornar then
    select * into v_orca from orca where id = v_b.orca_id;
    if v_orca.id is not null and v_orca.eh_pedido is true then
      select id, role, vendedor_pai_id, percentual_comissao into v_dono
      from usuarios where id = v_orca.user_id;

      v_master := null;
      v_empresa := null;
      if v_dono.role = 'vendedor' and coalesce(v_dono.vendedor_pai_id, 0) > 0 then
        select id, role, vendedor_pai_id, percentual_comissao into v_master
        from usuarios where id = v_dono.vendedor_pai_id;
      end if;
      if v_master.id is not null and v_master.role = 'vendedor_master' and coalesce(v_master.vendedor_pai_id, 0) > 0 then
        select id, role into v_empresa from usuarios where id = v_master.vendedor_pai_id;
      elsif v_dono.role = 'vendedor_master' and coalesce(v_dono.vendedor_pai_id, 0) > 0 then
        select id, role into v_empresa from usuarios where id = v_dono.vendedor_pai_id;
      end if;

      if v_empresa.id is not null then
        select coalesce(jsonb_agg(to_jsonb(f) order by f.faixa_min asc), '[]'::jsonb)
        into v_faixas
        from faixa_comissao f
        where f.user_id = v_empresa.id and f.ativo is true;
      end if;

      select coalesce(jsonb_agg(to_jsonb(b) order by b.id), '[]'::jsonb)
      into v_parcelas
      from boleto b where b.orca_id = v_orca.id;

      select count(*) into v_nao_pagas
      from jsonb_array_elements(v_parcelas) e
      where (e.value->>'pagamento') is null or (e.value->>'pagamento') = '';

      v_pago_completo := (v_nao_pagas = 0) and (jsonb_array_length(v_parcelas) > 0);

      if v_pago_completo then
        select coalesce(sum(coalesce(i.vlr_cst_nota_unit, 0) * coalesce(i.qtd, 1)), 0)
        into v_custo_kapazi
        from item i where i.orca_id = v_orca.id;

        select desconto_kapazi_perc, frete_b2b_real into v_controle_perc, v_frete_real
        from controle_pedido where orca_id = v_orca.id order by id limit 1;
        v_controle_perc := coalesce(v_controle_perc, 0);
        v_frete_real := coalesce(v_frete_real, 0);

        select desconto_novo into v_log_perc
        from desconto_kapazi_log where orca_id = v_orca.id order by created_at desc, id desc limit 1;

        v_perc := coalesce(v_log_perc, v_controle_perc, 0);
        v_desconto_kapazi := v_custo_kapazi * (v_perc / 100);
        v_frete_efetivo := case
          when v_frete_real > 0 then v_frete_real
          else coalesce(v_orca.frt_b2b, 0)
        end;
        v_lucro_real := coalesce(v_orca.luc_tot, 0) + v_desconto_kapazi + (coalesce(v_orca.frt_b2b, 0) - v_frete_efetivo);

        v_markup_ef := v_orca.markup_efetivo;
        if v_markup_ef is null or v_markup_ef <= 0 then
          v_markup_ef := case
            when coalesce(v_orca.cst_tot, 0) > 0 then ((coalesce(v_orca.vnd_tot, 0) / v_orca.cst_tot) - 1) * 100
            else 0
          end;
        end if;

        v_total_faixa := 0;
        if v_faixas is not null then
          for v_faixa in select value from jsonb_array_elements(v_faixas) loop
            if v_markup_ef >= coalesce((v_faixa->>'faixa_min')::numeric, 0)
               and ((v_faixa->>'faixa_max') is null or (v_faixa->>'faixa_max') = '' or v_markup_ef <= (v_faixa->>'faixa_max')::numeric) then
              v_total_faixa := coalesce((v_faixa->>'comissao_total_perc')::numeric, 0);
              exit;
            end if;
          end loop;
        end if;

        v_base := coalesce(v_orca.vnd_tot, 0);

        if v_master.id is not null and v_master.role = 'vendedor_master'
           and v_empresa.id is not null and (v_empresa.role = 'admin' or v_empresa.role = 'admin_geral')
           and v_total_faixa > 0 then
          v_pct_ponta := coalesce(v_dono.percentual_comissao, 0);
          if v_pct_ponta > v_total_faixa then
            v_pct_ponta := v_total_faixa;
          end if;
          v_override := greatest(0, v_total_faixa - v_pct_ponta);

          if v_pct_ponta > 0 and v_base > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_dono.id and tipo = 'vendedor';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_dono.id, v_orca.id, v_pct_ponta, v_base, v_base, 'vendedor', round(v_base * v_pct_ponta / 100, 2), 'calculada');
            end if;
          end if;

          if v_override > 0 and v_base > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_master.id and tipo = 'override';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_master.id, v_orca.id, v_override, v_base, v_base, 'override', round(v_base * v_override / 100, 2), 'calculada');
            end if;
          end if;
        elsif v_dono.role = 'vendedor_master'
           and v_empresa.id is not null and (v_empresa.role = 'admin' or v_empresa.role = 'admin_geral')
           and v_total_faixa > 0 then
          if v_total_faixa > 0 and v_base > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_dono.id and tipo = 'override';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_dono.id, v_orca.id, v_total_faixa, v_base, v_base, 'override', round(v_base * v_total_faixa / 100, 2), 'calculada');
            end if;
          end if;
        else
          v_pct_ponta := coalesce(v_dono.percentual_comissao, 0);
          if v_pct_ponta > 0 and v_lucro_real > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_dono.id and tipo = 'vendedor';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_dono.id, v_orca.id, v_pct_ponta, v_lucro_real, v_lucro_real, 'vendedor', round(v_lucro_real * v_pct_ponta / 100, 2), 'calculada');
            end if;
          end if;
        end if;
      end if;
    end if;
  end if;

  return (select to_jsonb(b) from boleto b where b.id = p_boleto_id);
end;
$$;

-- =============================================================
-- Equipe + Comissões + Faixas
-- =============================================================

create or replace function public.equipe(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_lista jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  if v_me.role = 'admin_geral' then
    select coalesce(jsonb_agg(
      to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
      || jsonb_build_object('ativo_efetivo', f_ativo_efetivo(u.id))
      order by u.created_at desc
    ), '[]'::jsonb)
    into v_lista
    from usuarios u where u.id <> p_user_id;
  else
    select coalesce(jsonb_agg(
      to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
      || jsonb_build_object('ativo_efetivo', f_ativo_efetivo(u.id))
      order by u.created_at desc
    ), '[]'::jsonb)
    into v_lista
    from usuarios u where u.vendedor_pai_id = p_user_id;
  end if;

  return v_lista;
end;
$$;

create or replace function public.equipe_vincular(
  p_user_id bigint,
  p_email text,
  p_percentual_comissao numeric default null,
  p_role text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_alvo record;
  v_novo_role text := 'vendedor';
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role not in ('admin', 'admin_geral') then
    raise exception 'Apenas administradores podem vincular vendedores.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  select id, email, role, vendedor_pai_id into v_alvo from usuarios where lower(email) = lower(p_email);
  if not found then
    raise exception 'Usuário com esse e-mail não encontrado.' using errcode = 'P0001';
  end if;
  if v_alvo.id = p_user_id then
    raise exception 'Você não pode se vincular a si mesmo.' using errcode = 'P0001';
  end if;
  if v_alvo.role = 'admin_geral' then
    raise exception 'Não é possível vincular o administrador geral.' using errcode = 'P0001';
  end if;
  if coalesce(v_alvo.vendedor_pai_id, 0) > 0 then
    raise exception 'Este usuário já pertence a outra equipe.' using errcode = 'P0001';
  end if;

  if p_role = 'vendedor_master' then
    if v_me.role not in ('admin', 'admin_geral') then
      raise exception 'Apenas administradores podem vincular um Vendedor Master.' using errcode = 'P0001';
    end if;
    v_novo_role := 'vendedor_master';
  end if;

  update usuarios set
    role = v_novo_role,
    vendedor_pai_id = p_user_id,
    percentual_comissao = p_percentual_comissao
  where id = v_alvo.id;

  return (select to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
          from usuarios u where u.id = v_alvo.id);
end;
$$;

create or replace function public.equipe_salvar(
  p_user_id bigint,
  p_target_id bigint,
  p_percentual_comissao numeric,
  p_ativo boolean,
  p_desconto_livre_perc numeric,
  p_desconto_max_perc numeric
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_alvo record;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  select id, vendedor_pai_id into v_alvo from usuarios where id = p_target_id;
  if not found then
    raise exception 'Vendedor não encontrado.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and v_alvo.vendedor_pai_id <> p_user_id then
    raise exception 'Você não pode editar este vendedor.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  update usuarios set
    percentual_comissao = p_percentual_comissao,
    ativo = p_ativo,
    desconto_livre_perc = p_desconto_livre_perc,
    desconto_max_perc = p_desconto_max_perc
  where id = p_target_id;

  return (select to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
          from usuarios u where u.id = p_target_id);
end;
$$;

create or replace function public.equipe_role(p_user_id bigint, p_target_id bigint, p_role text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_alvo record;
  v_novo_pai bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' then
    raise exception 'Apenas o administrador geral altera papéis.' using errcode = 'P0001';
  end if;
  if p_target_id = p_user_id then
    raise exception 'Você não pode alterar o próprio papel.' using errcode = 'P0001';
  end if;
  if p_role not in ('admin', 'vendedor', 'vendedor_master') then
    raise exception 'Papel inválido.' using errcode = 'P0001';
  end if;

  select id, vendedor_pai_id into v_alvo from usuarios where id = p_target_id;
  if not found then
    raise exception 'Usuário não encontrado.' using errcode = 'P0001';
  end if;

  v_novo_pai := v_alvo.vendedor_pai_id;
  if p_role = 'admin' then
    v_novo_pai := null;
  end if;

  update usuarios set role = p_role, vendedor_pai_id = v_novo_pai where id = p_target_id;
  return (select to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
          from usuarios u where u.id = p_target_id);
end;
$$;

create or replace function public.user_plano(p_user_id bigint, p_target_id bigint, p_plano text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' then
    raise exception 'Apenas o administrador geral define planos.' using errcode = 'P0001';
  end if;
  if p_target_id is null then
    raise exception 'Informe o usuário.' using errcode = 'P0001';
  end if;
  if p_plano not in ('basico', 'plus') then
    raise exception 'Plano inválido.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from usuarios where id = p_target_id) then
    raise exception 'Usuário não encontrado.' using errcode = 'P0001';
  end if;

  update usuarios set plano = p_plano where id = p_target_id;
  return jsonb_build_object('id', p_target_id, 'plano', p_plano);
end;
$$;

create or replace function public.comissoes(
  p_user_id bigint,
  p_mes_inicio text default null,
  p_periodo text default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_ini timestamptz := '-infinity';
  v_fim timestamptz := 'infinity';
  v_n int := 0;
  v_base_ano int;
  v_base_mes int;
  v_raw_mes text;
  v_linhas jsonb;
  v_totais jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  v_n := case p_periodo when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 when 'anual' then 12 else 0 end;
  v_raw_mes := coalesce(nullif(trim(coalesce(p_mes_inicio, '')), ''), to_char(current_date, 'YYYY-MM'));
  v_base_ano := split_part(v_raw_mes, '-', 1)::int;
  v_base_mes := split_part(v_raw_mes, '-', 2)::int;
  if v_n > 0 then
    v_ini := make_timestamptz(v_base_ano, v_base_mes, 1, 0, 0, 0, 'UTC');
    v_fim := make_timestamptz(v_base_ano, v_base_mes + v_n, 1, 0, 0, 0, 'UTC');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'user_id', c.user_id,
      'vendedor', coalesce(nullif(uv.name_first, ''), 'Vendedor ' || c.user_id),
      'cod_orca', coalesce(nullif(o.cod_orca, ''), '#' || c.orca_id),
      'orca_id', c.orca_id,
      'percentual', coalesce(c.percentual, 0),
      'base', coalesce(c.base_valor, c.lucro_real_base, 0),
      'tipo', case when c.tipo = 'override' then 'override' else 'vendedor' end,
      'valor', coalesce(c.valor, 0),
      'status', case when c.status = 'paga' then 'paga' else 'calculada' end,
      'data_pagamento', c.data_pagamento,
      'data', to_char(c.created_at, 'YYYY-MM-DD')
    )
    order by c.created_at desc
  ), '[]'::jsonb)
  into v_linhas
  from comissao c
  join orca o on o.id = c.orca_id
  left join usuarios uv on uv.id = c.user_id
  where c.created_at >= v_ini and c.created_at < v_fim
    and (
      v_me.role = 'admin_geral'
      or c.user_id = p_user_id
      or (v_me.role in ('admin', 'vendedor_master') and c.user_id in (select f_descendentes(p_user_id)))
    );

  select jsonb_build_object(
    'calculada', jsonb_build_object(
      'qtd', coalesce(sum(case when (e.value->>'status') = 'calculada' then 1 else 0 end), 0),
      'total', round(coalesce(sum(case when (e.value->>'status') = 'calculada' then (e.value->>'valor')::numeric else 0 end), 0), 2)
    ),
    'paga', jsonb_build_object(
      'qtd', coalesce(sum(case when (e.value->>'status') = 'paga' then 1 else 0 end), 0),
      'total', round(coalesce(sum(case when (e.value->>'status') = 'paga' then (e.value->>'valor')::numeric else 0 end), 0), 2)
    )
  )
  into v_totais
  from jsonb_array_elements(v_linhas) e;

  return jsonb_build_object('linhas', v_linhas, 'totais', v_totais);
end;
$$;

create or replace function public.comissao_pagar(p_user_id bigint, p_comissao_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_comissao record;
  v_dono_id bigint;
  v_cur bigint;
  v_pode boolean;
  v_guard int := 0;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, user_id into v_comissao from comissao where id = p_comissao_id;
  if not found then
    raise exception 'Comissão não encontrada.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  v_dono_id := v_comissao.user_id;
  v_pode := (v_me.role = 'admin_geral');
  if not v_pode and v_me.role in ('admin', 'admin_geral') then
    select coalesce(vendedor_pai_id, 0) into v_cur from usuarios where id = v_dono_id;
    while v_cur > 0 and v_guard < 50 loop
      if v_cur = p_user_id then
        v_pode := true;
        exit;
      end if;
      select coalesce(vendedor_pai_id, 0) into v_cur from usuarios where id = v_cur;
      v_guard := v_guard + 1;
    end loop;
  end if;

  if not v_pode then
    raise exception 'Você não pode pagar esta comissão.' using errcode = 'P0001';
  end if;

  update comissao set status = 'paga', data_pagamento = current_date where id = p_comissao_id;
  return (select to_jsonb(c) from comissao c where c.id = p_comissao_id);
end;
$$;

create or replace function public.faixas_comissao(p_user_id bigint, p_target_user_id bigint default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_target_id bigint;
  v_faixas jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role, vendedor_pai_id, percentual_comissao into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  v_target_id := p_user_id;
  if v_me.role = 'vendedor' and coalesce(v_me.vendedor_pai_id, 0) > 0 then
    v_target_id := f_empresa_id(p_user_id);
  elsif v_me.role = 'vendedor_master' and coalesce(v_me.vendedor_pai_id, 0) > 0 then
    v_target_id := v_me.vendedor_pai_id;
  elsif v_me.role = 'admin_geral' and p_target_user_id is not null then
    v_target_id := p_target_user_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(f) order by f.faixa_min asc), '[]'::jsonb)
  into v_faixas
  from faixa_comissao f where f.user_id = v_target_id;

  return jsonb_build_object(
    'faixas', v_faixas,
    'papel', v_me.role,
    'percentual_comissao', v_me.percentual_comissao,
    'empresa_id', v_target_id
  );
end;
$$;

create or replace function public.faixa_comissao_salvar(
  p_user_id bigint,
  p_id bigint default null,
  p_target_user_id bigint default null,
  p_faixa_min numeric default null,
  p_faixa_max numeric default null,
  p_comissao_total_perc numeric default null,
  p_ordem int default null,
  p_ativo boolean default true
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_dono_id bigint;
  v_existente record;
  v_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role not in ('admin', 'admin_geral') then
    raise exception 'Apenas administradores configuram faixas de comissão.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;
  if coalesce(p_comissao_total_perc, 0) <= 0 then
    raise exception 'Informe a comissão total.' using errcode = 'P0001';
  end if;

  v_dono_id := p_user_id;
  if v_me.role = 'admin_geral' and p_target_user_id is not null then
    v_dono_id := p_target_user_id;
  end if;

  if p_id is not null then
    select id, user_id into v_existente from faixa_comissao where id = p_id;
    if not found then
      raise exception 'Faixa não encontrada.' using errcode = 'P0001';
    end if;
    if v_me.role <> 'admin_geral' and v_existente.user_id <> p_user_id then
      raise exception 'Você não pode editar esta faixa.' using errcode = 'P0001';
    end if;

    update faixa_comissao set
      user_id = v_dono_id,
      faixa_min = coalesce(p_faixa_min, 0),
      faixa_max = p_faixa_max,
      comissao_total_perc = p_comissao_total_perc,
      ordem = p_ordem,
      ativo = p_ativo
    where id = p_id;
    v_id := p_id;
  else
    insert into faixa_comissao (created_at, user_id, faixa_min, faixa_max, comissao_total_perc, ordem, ativo)
    values (now(), v_dono_id, coalesce(p_faixa_min, 0), p_faixa_max, p_comissao_total_perc, p_ordem, p_ativo)
    returning id into v_id;
  end if;

  return (select to_jsonb(f) from faixa_comissao f where f.id = v_id);
end;
$$;

-- =============================================================
-- Notificações
-- =============================================================

create or replace function public.notificacoes(p_user_id bigint, p_limite int default 20)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_notifs jsonb;
  v_nao_lidas int;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb)
  into v_notifs
  from (
    select n.id, n.user_id, n.tipo, n.orca_id, n.lida, n.created_at, o.cod_orca
    from notificacao n
    left join orca o on o.id = n.orca_id
    where n.user_id = p_user_id
    order by n.created_at desc
    limit greatest(coalesce(p_limite, 20), 1)
  ) x;

  select count(*) into v_nao_lidas from notificacao where user_id = p_user_id and lida is not true;

  return jsonb_build_object('notificacoes', v_notifs, 'nao_lidas', v_nao_lidas);
end;
$$;

create or replace function public.notificacoes_marcar_lida(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  update notificacao set lida = true, data_leitura = now()
  where user_id = p_user_id and lida is not true;
  return jsonb_build_object('ok', true);
end;
$$;

-- =============================================================
-- Taxas
-- =============================================================

create or replace function public.taxas_banco_gerenciar(p_user_id bigint, p_target_user_id bigint default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_target_id bigint;
  v_empresa_id bigint;
  v_taxas jsonb;
  v_globais jsonb;
  v_provedores jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam as taxas.' using errcode = 'P0001';
  end if;

  v_target_id := p_user_id;
  if v_me.role = 'admin_geral' and p_target_user_id is not null then
    v_target_id := p_target_user_id;
  end if;
  v_empresa_id := f_empresa_id(v_target_id);

  select coalesce(jsonb_agg(
    to_jsonb(t) || jsonb_build_object('provedor', p.nome)
    order by t.parcelas asc
  ), '[]'::jsonb)
  into v_taxas
  from taxa_banco t
  join provedor p on p.id = t.provedor_id
  where t.user_id = v_empresa_id;

  select coalesce(jsonb_agg(
    to_jsonb(t) || jsonb_build_object('provedor', p.nome)
    order by t.parcelas asc
  ), '[]'::jsonb)
  into v_globais
  from taxa_banco t
  join provedor p on p.id = t.provedor_id
  where t.ativo is true and (t.user_id is null or t.user_id = 0);

  select coalesce(jsonb_agg(to_jsonb(p) order by p.nome asc), '[]'::jsonb)
  into v_provedores
  from provedor p where p.ativo is true;

  return jsonb_build_object(
    'taxas', v_taxas,
    'taxas_globais', v_globais,
    'provedores', v_provedores,
    'empresa_id', v_empresa_id,
    'papel', v_me.role
  );
end;
$$;

create or replace function public.taxa_banco_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_dono_id bigint;
  v_empresa_id bigint;
  v_existente record;
  v_id bigint;
  v_canal text := nullif(p_payload->>'canal', '');
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam as taxas.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'parcelas')::int, 0) <= 0 then
    raise exception 'Informe o número de parcelas.' using errcode = 'P0001';
  end if;
  if p_payload->>'cc_taxa' is null then
    raise exception 'Informe a taxa do cartão.' using errcode = 'P0001';
  end if;
  if v_canal is not null and v_canal not in ('cartao_link', 'cartao_celular', 'cartao_pos') then
    raise exception 'Canal inválido.' using errcode = 'P0001';
  end if;

  v_dono_id := p_user_id;
  if v_me.role = 'admin_geral' and (p_payload->>'user_id') is not null and (p_payload->>'user_id') <> '' then
    v_dono_id := (p_payload->>'user_id')::bigint;
  end if;
  v_empresa_id := f_empresa_id(v_dono_id);

  if p_payload->>'id' is not null then
    v_id := (p_payload->>'id')::bigint;
    select id, user_id into v_existente from taxa_banco where id = v_id;
    if not found then
      raise exception 'Taxa não encontrada.' using errcode = 'P0001';
    end if;
    if v_me.role <> 'admin_geral' and v_existente.user_id <> v_empresa_id then
      raise exception 'Você não pode editar esta taxa.' using errcode = 'P0001';
    end if;

    update taxa_banco set
      user_id = v_empresa_id,
      provedor_id = (p_payload->>'provedor_id')::bigint,
      parcelas = (p_payload->>'parcelas')::int,
      cc_taxa = (p_payload->>'cc_taxa')::numeric,
      canal = v_canal,
      ativo = coalesce((p_payload->>'ativo')::boolean, true),
      origem = 'manual',
      atualizado_em = now()
    where id = v_id;
  else
    insert into taxa_banco (user_id, provedor_id, parcelas, cc_taxa, canal, ativo, origem, atualizado_em, created_at)
    values (
      v_empresa_id,
      (p_payload->>'provedor_id')::bigint,
      (p_payload->>'parcelas')::int,
      (p_payload->>'cc_taxa')::numeric,
      v_canal,
      coalesce((p_payload->>'ativo')::boolean, true),
      'manual',
      now(),
      now()
    ) returning id into v_id;
  end if;

  return (
    select to_jsonb(t) || jsonb_build_object('provedor', p.nome)
    from taxa_banco t join provedor p on p.id = t.provedor_id where t.id = v_id
  );
end;
$$;

create or replace function public.taxa_banco_excluir(p_user_id bigint, p_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_existente record;
  v_empresa_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam as taxas.' using errcode = 'P0001';
  end if;

  select id, user_id into v_existente from taxa_banco where id = p_id;
  if not found then
    raise exception 'Taxa não encontrada.' using errcode = 'P0001';
  end if;

  v_empresa_id := f_empresa_id(p_user_id);
  if v_me.role <> 'admin_geral' and v_existente.user_id <> v_empresa_id then
    raise exception 'Você não pode excluir esta taxa.' using errcode = 'P0001';
  end if;

  delete from taxa_banco where id = p_id;
  return null::jsonb;
end;
$$;

create or replace function public.provedor_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_id bigint;
  v_nome text := nullif(p_payload->>'nome', '');
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam provedores.' using errcode = 'P0001';
  end if;
  if v_nome is null or v_nome = '' then
    raise exception 'Informe o nome do provedor.' using errcode = 'P0001';
  end if;

  if p_payload->>'id' is not null then
    v_id := (p_payload->>'id')::bigint;
    update provedor set
      nome = v_nome,
      url_taxas = nullif(p_payload->>'url_taxas', ''),
      metodo = coalesce(nullif(p_payload->>'metodo', ''), 'manual'),
      canal_default = nullif(p_payload->>'canal_default', ''),
      ativo = coalesce((p_payload->>'ativo')::boolean, true)
    where id = v_id;
  else
    insert into provedor (nome, url_taxas, metodo, canal_default, ativo, created_at)
    values (
      v_nome,
      nullif(p_payload->>'url_taxas', ''),
      coalesce(nullif(p_payload->>'metodo', ''), 'manual'),
      nullif(p_payload->>'canal_default', ''),
      coalesce((p_payload->>'ativo')::boolean, true),
      now()
    ) returning id into v_id;
  end if;

  return (select to_jsonb(p) from provedor p where p.id = v_id);
end;
$$;
