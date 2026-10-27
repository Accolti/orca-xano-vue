-- Corrige produto_salvar: produto SEM variações gravava detalhe_id = 0 (violava FK produto_detalhe_id_fkey).
-- Agora detalhe_id é nullable (NULL quando não há variações).

create or replace function public.produto_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_produto_id bigint := nullif(p_payload->>'produto_id', '')::bigint;
  v_detalhe_atual bigint := null;
  v_detalhe_id bigint := null;
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
    select detalhe_id into v_detalhe_atual from produto where id = v_produto_id;
  end if;

  -- 1. Cria um Detalhe quando o produto tem variações e ainda não possui um.
  if v_tem_variacoes and v_detalhe_atual is null then
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
    if v_detalhe_atual is not null then
      delete from variacao where detalhe_id = v_detalhe_atual;
    end if;
  end if;

  return jsonb_build_object('produto_id', v_salvo);
end;
$$;
