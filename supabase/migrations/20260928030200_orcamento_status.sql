-- =============================================================
-- Fase 2C — Status/transições, aprovação de desconto, excluir e duplicar
-- =============================================================

-- Ativo efetivo: sobe a cadeia vendedor_pai_id; false se o próprio OU um ancestral está inativo.
create or replace function public.f_ativo_efetivo(p_user_id bigint)
returns boolean language plpgsql stable as $$
declare
  v_id bigint := p_user_id;
  v_u record;
  v_guard int := 0;
begin
  loop
    exit when v_id is null or v_id <= 0 or v_guard > 10;
    select ativo, vendedor_pai_id into v_u from usuarios where id = v_id;
    if not found then
      return true;
    end if;
    if v_u.ativo is false then
      return false;
    end if;
    v_id := v_u.vendedor_pai_id;
    v_guard := v_guard + 1;
  end loop;
  return true;
end;
$$;

-- Histórico de status (auditoria), do mais recente ao mais antigo.
create or replace function public.orcamento_status_historico(p_user_id bigint, p_orca_id bigint)
returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(to_jsonb(l) order by l.created_at desc, l.id desc), '[]'::jsonb)
  from orca_status_log l where l.orca_id = p_orca_id
$$;

-- Atualiza o status do orçamento (com política de desconto + bloqueio de pedido) e audita.
create or replace function public.orcamento_status(
  p_user_id bigint,
  p_orca_id bigint,
  p_status text,
  p_motivo text default null
)
returns jsonb language plpgsql as $$
declare
  v_orca orca%rowtype;
  v_caller record;
  v_eh_filho boolean;
  v_desc_pendente boolean := false;
  v_data_envio timestamptz;
  v_data_aprovacao timestamptz;
  v_motivo_recusa text;
begin
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

-- Converte um orçamento APROVADO em pedido (exige num_pedido_fabrica no ControlePedido).
create or replace function public.orcamento_converter_pedido(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql as $$
declare
  v_orca orca%rowtype;
  v_num_pedido text;
begin
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

-- Aprova/recusa o desconto acima do limite (permissão: ancestral direto/master ou admin_geral).
create or replace function public.orcamento_aprovar_desconto(
  p_user_id bigint,
  p_orca_id bigint,
  p_aprovado boolean default true
)
returns jsonb language plpgsql as $$
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

-- Fila de orçamentos de filhos com desconto pendente de aprovação.
create or replace function public.orcamentos_pendentes_aprovacao(p_user_id bigint)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_linhas jsonb;
begin
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

-- Exclui um orçamento (dono, enquanto não for pedido) em cascata.
create or replace function public.orcamento_deletar(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql as $$
declare
  v_orca record;
begin
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

-- Duplica um orçamento (Orca + itens) com nova numeração.
create or replace function public.orcamento_duplicar(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql as $$
declare
  v_orca orca%rowtype;
  v_new_cod text;
  v_new_id bigint;
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
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
