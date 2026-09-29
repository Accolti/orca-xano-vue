-- =============================================================
-- Fase 1 (continuação) — taxas de banco: f_empresa_id + rpc_taxas_banco
-- =============================================================

-- Resolve o id da EMPRESA (topo da cadeia vendedor_pai_id) de um usuário.
-- admin/admin_geral -> próprio id; vendedor/master -> sobe até o admin.
create or replace function public.f_empresa_id(p_user_id bigint)
returns bigint language sql stable as $$
  select
    case
      when u.role in ('vendedor', 'vendedor_master') then
        case
          when p.role = 'vendedor_master' and p.vendedor_pai_id is not null and p.vendedor_pai_id > 0
            then p.vendedor_pai_id
          else coalesce(p.id, u.id)
        end
      else u.id
    end
  from usuarios u
  left join usuarios p on p.id = u.vendedor_pai_id
  where u.id = p_user_id
$$;

-- Taxas efetivas do usuário (empresa + global), com provedor.
create or replace function public.rpc_taxas_banco(p_user_id bigint)
returns jsonb language sql stable as $$
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
$$;
