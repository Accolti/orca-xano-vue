-- =============================================================
-- RLS: pagamento_baixa — versão escalar + SECURITY DEFINER
-- =============================================================
--
-- A 90100_rls_definer redefiniu pagamento_baixa como SECURITY DEFINER,
-- mas com o bug `v_master record` + `v_master := null` (acessar campo de
-- record nulo lança "record v_master is not assigned yet").
--
-- Aqui: dropa TODAS as funções `pagamento_baixa` de `public` e recria a
-- única correta com VARIÁVEIS ESCALARES + SECURITY DEFINER + validação
-- de identidade via auth_user_id().
--
-- Aplicar DEPOIS das migrations RLS (90000–90300) — esta é a 90700.
-- =============================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS sig
    FROM pg_proc
    WHERE proname = 'pagamento_baixa'
      AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %s', r.sig);
  END LOOP;
END $$;

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
  v_dono_id bigint;
  v_dono_role text;
  v_dono_pai_id bigint;
  v_dono_perc numeric;
  v_master_id bigint;
  v_master_role text;
  v_master_pai_id bigint;
  v_empresa_id bigint;
  v_empresa_role text;
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
      select id, role, vendedor_pai_id, percentual_comissao
        into v_dono_id, v_dono_role, v_dono_pai_id, v_dono_perc
      from usuarios where id = v_orca.user_id;

      if v_dono_role = 'vendedor' and coalesce(v_dono_pai_id, 0) > 0 then
        select id, role, vendedor_pai_id
          into v_master_id, v_master_role, v_master_pai_id
        from usuarios where id = v_dono_pai_id;
      end if;

      if v_master_id is not null and v_master_role = 'vendedor_master' and coalesce(v_master_pai_id, 0) > 0 then
        select id, role into v_empresa_id, v_empresa_role from usuarios where id = v_master_pai_id;
      elsif v_dono_role = 'vendedor_master' and coalesce(v_dono_pai_id, 0) > 0 then
        select id, role into v_empresa_id, v_empresa_role from usuarios where id = v_dono_pai_id;
      end if;

      if v_empresa_id is not null then
        select coalesce(jsonb_agg(to_jsonb(f) order by f.faixa_min asc), '[]'::jsonb)
        into v_faixas
        from faixa_comissao f
        where f.user_id = v_empresa_id and f.ativo is true;
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

        -- A.2: ponta + override do Master
        if v_master_id is not null and v_master_role = 'vendedor_master'
           and v_empresa_id is not null and (v_empresa_role = 'admin' or v_empresa_role = 'admin_geral')
           and v_total_faixa > 0 then
          v_pct_ponta := coalesce(v_dono_perc, 0);
          if v_pct_ponta > v_total_faixa then
            v_pct_ponta := v_total_faixa;
          end if;
          v_override := greatest(0, v_total_faixa - v_pct_ponta);

          if v_pct_ponta > 0 and v_base > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_dono_id and tipo = 'vendedor';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_dono_id, v_orca.id, v_pct_ponta, v_base, v_base, 'vendedor', round(v_base * v_pct_ponta / 100, 2), 'calculada');
            end if;
          end if;

          if v_override > 0 and v_base > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_master_id and tipo = 'override';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_master_id, v_orca.id, v_override, v_base, v_base, 'override', round(v_base * v_override / 100, 2), 'calculada');
            end if;
          end if;
        elsif v_dono_role = 'vendedor_master'
           and v_empresa_id is not null and (v_empresa_role = 'admin' or v_empresa_role = 'admin_geral')
           and v_total_faixa > 0 then
          -- Master vendendo: ele leva o total da faixa
          if v_total_faixa > 0 and v_base > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_dono_id and tipo = 'override';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_dono_id, v_orca.id, v_total_faixa, v_base, v_base, 'override', round(v_base * v_total_faixa / 100, 2), 'calculada');
            end if;
          end if;
        else
          -- Fallback Fase A: % fixo do vendedor sobre o lucro real
          v_pct_ponta := coalesce(v_dono_perc, 0);
          if v_pct_ponta > 0 and v_lucro_real > 0 then
            select count(*) into v_ja_existe from comissao
            where orca_id = v_orca.id and user_id = v_dono_id and tipo = 'vendedor';
            if v_ja_existe = 0 then
              insert into comissao (created_at, user_id, orca_id, percentual, lucro_real_base, base_valor, tipo, valor, status)
              values (now(), v_dono_id, v_orca.id, v_pct_ponta, v_lucro_real, v_lucro_real, 'vendedor', round(v_lucro_real * v_pct_ponta / 100, 2), 'calculada');
            end if;
          end if;
        end if;
      end if;
    end if;
  end if;

  return (select to_jsonb(b) from boleto b where b.id = p_boleto_id);
end;
$$;
