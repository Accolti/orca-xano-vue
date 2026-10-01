-- =============================================================
-- Dev tools (catálogo) — migração Xano → Supabase
-- =============================================================
--
-- Substitui os endpoints Xano das dev tools (DevMateriais/DevProdutos/
-- DevFatores/DevConfiguracoes) por RPCs security definer.
--
-- Leituras: sem checagem de identidade (dados de referência já expostos).
-- Escritas: auth_user_id() + f_eh_admin (só admin/admin_geral/legado sem pai)
--           + f_ativo_efetivo.
-- =============================================================

-- Admin efetivo: role admin/admin_geral, ou legado (sem role e sem pai).
create or replace function public.f_eh_admin(p_user_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from usuarios u
    where u.id = p_user_id
      and (
        u.role in ('admin', 'admin_geral')
        or (coalesce(u.role, '') = '' and coalesce(u.vendedor_pai_id, 0) = 0)
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Leituras (listas)
-- ---------------------------------------------------------------------------

create or replace function public.rpc_materiais_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'nome', m.nome,
    'Ordenacao', m.ordenacao,
    'created_at', m.created_at,
    'ativo', m.ativo,
    'descricao', m.descricao,
    'garantia', m.garantia,
    'ncm', m.ncm,
    'imp', m.imp,
    'ipi', m.ipi,
    'peso', m.peso,
    'regra_fiscal_id', m.regra_fiscal_id,
    'st', m.st,
    'mva_padrao', m.mva_padrao,
    'aliq_st_interna', m.aliq_st_interna,
    'nac', m.nac,
    'Observacao', m.observacao,
    'importado', m.importado,
    'organizacao_id', m.organizacao_id,
    'updated_at', m.updated_at,
    'material_pai_id', m.material_id
  ) order by m.id), '[]'::jsonb)
  from material m;
$$;

create or replace function public.rpc_produtos_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(prod order by prod->>'produto_id'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', p.id,
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
      '_variacao', coalesce(vars.vars, '[]'::jsonb)
    ) as prod
    from produto p
    join material m on m.id = p.material_id
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
        'fator_de_corte_id', v.fator_de_corte_id,
        'ordem', v.ordem,
        'ativo', coalesce(v.ativo, true),
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
  ) sub
$$;

create or replace function public.rpc_fatores_corte_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'fatores', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.id)
      from fator_de_corte f
    ), '[]'::jsonb),
    'associacoes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', tf.id,
        'fator_de_corte_id', tf.fator_de_corte_id,
        'material_id', tf.material_id,
        'linha_id', tf.linha_id,
        'borda_id', tf.borda_id,
        'created_at', tf.created_at,
        'material_nome', m.nome,
        'linha_nome', l.nome,
        'borda_nome', b.nome
      ) order by tf.id)
      from tipo_fator tf
      join material m on m.id = tf.material_id
      left join linha l on l.id = tf.linha_id
      left join borda b on b.id = tf.borda_id
    ), '[]'::jsonb)
  );
$$;

create or replace function public.rpc_configuracoes_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb)
  from configuracoes c;
$$;

create or replace function public.rpc_classificacao_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'nome', c.nome) order by c.id), '[]'::jsonb)
  from classificacao c;
$$;

create or replace function public.rpc_tipo_variacao_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'Descricao', t.descricao) order by t.id), '[]'::jsonb)
  from tipo_variacao t;
$$;

create or replace function public.rpc_cor_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'Descricao', c.descricao) order by c.id), '[]'::jsonb)
  from cor c;
$$;

create or replace function public.rpc_modelo_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', mo.id, 'Descricao', mo.descricao, 'material_id', mo.material_id) order by mo.id), '[]'::jsonb)
  from modelo mo;
$$;

create or replace function public.rpc_fatordecorte_lista()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(f) order by f.id), '[]'::jsonb)
  from fator_de_corte f;
$$;

-- ---------------------------------------------------------------------------
-- Escritas (CRUD)
-- ---------------------------------------------------------------------------

create or replace function public.material_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'material_id', '')::bigint;
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  if v_id is not null then
    update material set
      nome = p_payload->>'nome',
      ordenacao = nullif(p_payload->>'Ordenacao', '')::numeric,
      material_id = nullif(p_payload->>'material_pai_id', '')::bigint,
      ativo = coalesce((p_payload->>'ativo')::boolean, true),
      descricao = nullif(p_payload->>'descricao', ''),
      garantia = nullif(p_payload->>'garantia', '')::bigint,
      ncm = nullif(p_payload->>'ncm', ''),
      imp = nullif(p_payload->>'imp', '')::numeric,
      ipi = nullif(p_payload->>'ipi', '')::numeric,
      peso = nullif(p_payload->>'peso', '')::numeric,
      regra_fiscal_id = nullif(p_payload->>'regra_fiscal_id', '')::bigint,
      st = (p_payload->>'st')::boolean,
      mva_padrao = nullif(p_payload->>'mva_padrao', '')::numeric,
      aliq_st_interna = nullif(p_payload->>'aliq_st_interna', '')::numeric,
      nac = (p_payload->>'nac')::boolean,
      observacao = nullif(p_payload->>'Observacao', ''),
      importado = (p_payload->>'importado')::boolean,
      organizacao_id = nullif(p_payload->>'organizacao_id', '')::bigint,
      updated_at = now()
    where id = v_id
    returning id into v_salvo;
  else
    insert into material (
      nome, ordenacao, material_id, ativo, descricao, garantia, ncm, imp, ipi, peso,
      regra_fiscal_id, st, mva_padrao, aliq_st_interna, nac, observacao, importado,
      organizacao_id, created_at
    ) values (
      p_payload->>'nome',
      nullif(p_payload->>'Ordenacao', '')::numeric,
      nullif(p_payload->>'material_pai_id', '')::bigint,
      coalesce((p_payload->>'ativo')::boolean, true),
      nullif(p_payload->>'descricao', ''),
      nullif(p_payload->>'garantia', '')::bigint,
      nullif(p_payload->>'ncm', ''),
      nullif(p_payload->>'imp', '')::numeric,
      nullif(p_payload->>'ipi', '')::numeric,
      nullif(p_payload->>'peso', '')::numeric,
      nullif(p_payload->>'regra_fiscal_id', '')::bigint,
      (p_payload->>'st')::boolean,
      nullif(p_payload->>'mva_padrao', '')::numeric,
      nullif(p_payload->>'aliq_st_interna', '')::numeric,
      (p_payload->>'nac')::boolean,
      nullif(p_payload->>'Observacao', ''),
      (p_payload->>'importado')::boolean,
      nullif(p_payload->>'organizacao_id', '')::bigint,
      now()
    )
    returning id into v_salvo;
  end if;

  return jsonb_build_object('material_id', v_salvo);
end;
$$;

create or replace function public.fator_corte_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'fator_de_corte_id', '')::bigint;
  v_valor double precision[];
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select coalesce(array_agg(x::double precision), '{}'::double precision[])
  into v_valor
  from jsonb_array_elements(coalesce(p_payload->'valor', '[]'::jsonb)) x;

  if v_id is not null then
    update fator_de_corte set
      nome = nullif(p_payload->>'nome', ''),
      valor = v_valor,
      larg_base = nullif(p_payload->>'larg_base', '')::double precision,
      comp_corte = nullif(p_payload->>'comp_corte', '')::double precision,
      tam_total = nullif(p_payload->>'tam_total', '')::numeric,
      modo_corte = coalesce(nullif(p_payload->>'modo_corte', ''), 'lista'),
      obs = nullif(p_payload->>'obs', '')
    where id = v_id
    returning id into v_salvo;
  else
    insert into fator_de_corte (nome, valor, larg_base, comp_corte, tam_total, modo_corte, obs, created_at)
    values (
      nullif(p_payload->>'nome', ''),
      v_valor,
      nullif(p_payload->>'larg_base', '')::double precision,
      nullif(p_payload->>'comp_corte', '')::double precision,
      nullif(p_payload->>'tam_total', '')::numeric,
      coalesce(nullif(p_payload->>'modo_corte', ''), 'lista'),
      nullif(p_payload->>'obs', ''),
      now()
    )
    returning id into v_salvo;
  end if;

  return jsonb_build_object('fator_de_corte_id', v_salvo);
end;
$$;

create or replace function public.fator_corte_excluir(p_user_id bigint, p_fator_de_corte_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_tf int;
  v_prod int;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;

  select count(*) into v_tf from tipo_fator where fator_de_corte_id = p_fator_de_corte_id;
  select count(*) into v_prod from produto where fator_de_corte_id = p_fator_de_corte_id;
  if v_tf > 0 or v_prod > 0 then
    raise exception 'Fator de corte em uso (associação Tipo_Fator ou produto fixo). Não é possível excluir.' using errcode = 'P0001';
  end if;

  delete from fator_de_corte where id = p_fator_de_corte_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.tipo_fator_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'tipo_fator_id', '')::bigint;
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'excluir')::boolean, false) and v_id is not null then
    delete from tipo_fator where id = v_id;
    return jsonb_build_object('tipo_fator_id', v_id);
  end if;

  if v_id is not null then
    update tipo_fator set
      material_id = nullif(p_payload->>'material_id', '')::bigint,
      linha_id = nullif(p_payload->>'linha_id', '')::bigint,
      borda_id = nullif(p_payload->>'borda_id', '')::bigint,
      fator_de_corte_id = nullif(p_payload->>'fator_de_corte_id', '')::bigint
    where id = v_id
    returning id into v_salvo;
  else
    insert into tipo_fator (material_id, linha_id, borda_id, fator_de_corte_id, created_at)
    values (
      nullif(p_payload->>'material_id', '')::bigint,
      nullif(p_payload->>'linha_id', '')::bigint,
      nullif(p_payload->>'borda_id', '')::bigint,
      nullif(p_payload->>'fator_de_corte_id', '')::bigint,
      now()
    )
    returning id into v_salvo;
  end if;

  return jsonb_build_object('tipo_fator_id', v_salvo);
end;
$$;

create or replace function public.configuracoes_versao(
  p_user_id bigint,
  p_configuracoes_id bigint,
  p_campo text,
  p_delta bigint default 1
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_atual bigint;
  v_novo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;

  if p_campo = 'versao_materiais' then
    select coalesce(versao_materiais, 0) into v_atual from configuracoes where id = p_configuracoes_id;
    v_novo := coalesce(v_atual, 0) + coalesce(p_delta, 0);
    update configuracoes set versao_materiais = v_novo where id = p_configuracoes_id;
  elsif p_campo = 'versao_produtos' then
    select coalesce(versao_produtos, 0) into v_atual from configuracoes where id = p_configuracoes_id;
    v_novo := coalesce(v_atual, 0) + coalesce(p_delta, 0);
    update configuracoes set versao_produtos = v_novo where id = p_configuracoes_id;
  elsif p_campo = 'versao_taxas_banco' then
    select coalesce(versao_taxas_banco, 0) into v_atual from configuracoes where id = p_configuracoes_id;
    v_novo := coalesce(v_atual, 0) + coalesce(p_delta, 0);
    update configuracoes set versao_taxas_banco = v_novo where id = p_configuracoes_id;
  else
    raise exception 'Campo inválido.' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'configuracoes_id', p_configuracoes_id,
    'campo', p_campo,
    'de', v_atual,
    'para', v_novo
  );
end;
$$;

create or replace function public.produto_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_produto_id bigint := nullif(p_payload->>'produto_id', '')::bigint;
  v_detalhe_atual bigint := 0;
  v_detalhe_id bigint := 0;
  v_tem_variacoes boolean;
  v_salvo bigint;
  v_valor numeric := coalesce((p_payload->>'valor')::numeric, 0);
  v_base_calculo text := upper(coalesce(p_payload->>'Base_de_Calculo', 'M2'));
  v_ids_payload bigint[] := '{}'::bigint[];
  v_ids_antigos bigint[];
  v_var jsonb;
  v_var_id bigint;
  v_var_valor_custo numeric;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  v_tem_variacoes := (jsonb_array_length(coalesce(p_payload->'variacoes', '[]'::jsonb)) > 0);

  if v_base_calculo in ('UND', 'KIT', 'ML') and coalesce(v_valor, 0) <= 0 then
    raise exception 'Produto sem custo base (valor). Informe o custo do produto — a variação herda quando não informado.' using errcode = 'P0001';
  end if;

  if v_produto_id is not null then
    select coalesce(detalhe_id, 0) into v_detalhe_atual from produto where id = v_produto_id;
  end if;

  -- 1. Cria um Detalhe quando o produto tem variações e ainda não possui um.
  if v_tem_variacoes and v_detalhe_atual = 0 then
    insert into detalhe (descricao, created_at) values ('', now()) returning id into v_detalhe_id;
    v_detalhe_atual := v_detalhe_id;
  else
    v_detalhe_id := v_detalhe_atual;
  end if;

  -- 2. Upsert do produto.
  if v_produto_id is not null then
    update produto set
      material_id = nullif(p_payload->>'material_id', '')::bigint,
      classificacao_id = nullif(p_payload->>'classificacao_id', '')::bigint,
      linha_id = nullif(p_payload->>'linha_id', '')::bigint,
      tipo_id = nullif(p_payload->>'tipo_id', '')::bigint,
      nivel_id = nullif(p_payload->>'nivel_id', '')::bigint,
      valor = v_valor,
      unidade = coalesce(nullif(p_payload->>'Unidade', ''), 'M2'),
      base_de_calculo = v_base_calculo,
      tipo_composto = nullif(p_payload->>'tipo_composto', ''),
      com_medida_exata = coalesce((p_payload->>'com_medida_exata')::boolean, false),
      porcentagem_acrescimo = coalesce((p_payload->>'porcentagem_acrescimo')::numeric, 0),
      detalhe_id = v_detalhe_id,
      fator_de_corte_id = nullif(p_payload->>'fator_de_corte_id', '')::bigint,
      ativo = coalesce((p_payload->>'ativo')::boolean, true)
    where id = v_produto_id
    returning id into v_salvo;
  else
    insert into produto (
      material_id, classificacao_id, linha_id, tipo_id, nivel_id, valor, unidade,
      base_de_calculo, tipo_composto, com_medida_exata, porcentagem_acrescimo,
      detalhe_id, fator_de_corte_id, ativo, created_at
    ) values (
      nullif(p_payload->>'material_id', '')::bigint,
      nullif(p_payload->>'classificacao_id', '')::bigint,
      nullif(p_payload->>'linha_id', '')::bigint,
      nullif(p_payload->>'tipo_id', '')::bigint,
      nullif(p_payload->>'nivel_id', '')::bigint,
      v_valor,
      coalesce(nullif(p_payload->>'Unidade', ''), 'M2'),
      v_base_calculo,
      nullif(p_payload->>'tipo_composto', ''),
      coalesce((p_payload->>'com_medida_exata')::boolean, false),
      coalesce((p_payload->>'porcentagem_acrescimo')::numeric, 0),
      v_detalhe_id,
      nullif(p_payload->>'fator_de_corte_id', '')::bigint,
      coalesce((p_payload->>'ativo')::boolean, true),
      now()
    )
    returning id into v_salvo;
  end if;

  -- 3. Sincroniza variações.
  if v_tem_variacoes then
    select coalesce(array_agg(id), '{}'::bigint[]) into v_ids_antigos
    from variacao where detalhe_id = v_detalhe_id;

    for v_var in select value from jsonb_array_elements(coalesce(p_payload->'variacoes', '[]'::jsonb)) loop
      v_var_id := nullif(v_var->>'id', '')::bigint;
      v_var_valor_custo := coalesce((v_var->>'valor_custo')::numeric, 0);
      if v_var_valor_custo = 0 then
        v_var_valor_custo := v_valor;
      end if;

      if v_var_id is not null then
        v_ids_payload := array_append(v_ids_payload, v_var_id);
        update variacao set
          detalhe_id = v_detalhe_id,
          tipo_variacao_id = nullif(v_var->>'tipo_variacao_id', '')::bigint,
          comp = coalesce((v_var->>'comp')::numeric, 0),
          larg = coalesce((v_var->>'larg')::numeric, 0),
          modelo_id = nullif(v_var->>'modelo_id', '')::bigint,
          lxc = nullif(v_var->>'LxC', ''),
          qtd_kit = coalesce((v_var->>'qtd_kit')::bigint, 0),
          valor_custo = v_var_valor_custo,
          cor_id = nullif(v_var->>'cor_id', '')::bigint,
          fator_de_corte_id = nullif(v_var->>'fator_de_corte_id', '')::bigint,
          ordem = coalesce((v_var->>'ordem')::numeric, 0),
          ativo = coalesce((v_var->>'ativo')::boolean, true)
        where id = v_var_id;
      else
        insert into variacao (
          detalhe_id, tipo_variacao_id, comp, larg, modelo_id, lxc, qtd_kit,
          valor_custo, cor_id, fator_de_corte_id, ordem, ativo, created_at
        ) values (
          v_detalhe_id,
          nullif(v_var->>'tipo_variacao_id', '')::bigint,
          coalesce((v_var->>'comp')::numeric, 0),
          coalesce((v_var->>'larg')::numeric, 0),
          nullif(v_var->>'modelo_id', '')::bigint,
          nullif(v_var->>'LxC', ''),
          coalesce((v_var->>'qtd_kit')::bigint, 0),
          v_var_valor_custo,
          nullif(v_var->>'cor_id', '')::bigint,
          nullif(v_var->>'fator_de_corte_id', '')::bigint,
          coalesce((v_var->>'ordem')::numeric, 0),
          coalesce((v_var->>'ativo')::boolean, true),
          now()
        )
        returning id into v_var_id;
        v_ids_payload := array_append(v_ids_payload, v_var_id);
      end if;
    end loop;

    -- Remove variações antigas que não vieram no payload.
    delete from variacao
    where detalhe_id = v_detalhe_id
      and not (id = any(v_ids_payload));
  else
    -- Sem variações: apaga variações órfãs do detalhe anterior.
    if v_detalhe_atual <> 0 then
      delete from variacao where detalhe_id = v_detalhe_atual;
    end if;
  end if;

  return jsonb_build_object('produto_id', v_salvo);
end;
$$;
