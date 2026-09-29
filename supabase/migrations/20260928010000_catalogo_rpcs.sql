-- =============================================================
-- Fase 1 — Catálogo (carga de produtos): RPCs que reproduzem os endpoints Xano
-- =============================================================

-- Helper: timestamptz -> epoch ms (o front, migrado do Xano, espera epoch ms)
create or replace function public.to_epoch_ms(ts timestamptz)
returns bigint language sql immutable as $$
  select (extract(epoch from ts) * 1000)::bigint
$$;

-- ---------------------------------------------------------------------------
-- configuracoes -> { "configuracoes-mae": [ { versao_*, taxas_atualizado_em } ] }
-- ---------------------------------------------------------------------------
create or replace function public.rpc_configuracoes()
returns jsonb language sql stable as $$
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
$$;

-- ---------------------------------------------------------------------------
-- produtos_para_selecao -> { lista_para_selecao: { Material, Linha, Tipo, Nivel, Borda } }
-- ---------------------------------------------------------------------------
create or replace function public.rpc_produtos_para_selecao()
returns jsonb language sql stable as $$
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
$$;

-- ---------------------------------------------------------------------------
-- produtos_all -> array de produtos (ativo) com _variacao[]
-- ---------------------------------------------------------------------------
create or replace function public.rpc_produtos_all()
returns jsonb language sql stable as $$
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
$$;

-- ---------------------------------------------------------------------------
-- produtos_suc_filtrado -> { Material_1: [ { Material_id, Linha, Tipo, Nivel, Borda, Variacao } ] }
-- ---------------------------------------------------------------------------
create or replace function public.rpc_produtos_suc_filtrado(
  p_material_id bigint default 0,
  p_linha_id bigint default 0,
  p_tipo_id bigint default 0
)
returns jsonb language sql stable as $$
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
$$;
