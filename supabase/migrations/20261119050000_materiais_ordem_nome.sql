-- =============================================================
-- Ordena os materiais da seleção por nome (depois ordenacao), e o
-- front passa a preservar a ordem do backend (sem re-sort local).
-- =============================================================

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
      ) order by m.nome, m.ordenacao)
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
