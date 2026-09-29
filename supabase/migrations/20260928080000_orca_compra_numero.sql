-- =============================================================
-- Campo "Compra Nº" (compra_numero) na tabela orca
-- =============================================================
alter table public.orca add column if not exists compra_numero text;

-- Redefine controle_pedido_salvar para também gravar orca.compra_numero
-- (chave opcional; só grava quando presente no payload, evitando zerar o campo).
create or replace function public.controle_pedido_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql as $$
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
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  if v_orca_id <= 0 then
    raise exception 'orca_id é obrigatório.' using errcode = 'P0001';
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
