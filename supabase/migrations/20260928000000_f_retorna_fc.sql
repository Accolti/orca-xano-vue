-- f_retorna_fc — fator de corte (modo lista + modo passo).
--
-- PENDÊNCIA (anotada para resolver depois):
--   O usuário já criou manualmente uma versão de `public.f_retorna_fc` no projeto
--   antigo (EUA) com APENAS o modo "lista" (assinatura: p_comp, p_larg, p_fc).
--   Esta migration é a versão COMPLETA, equivalente ao Xano `f_retorna_fc`,
--   incluindo o modo "passo" (arredonda UMA dimensão, a de menor área) — correção
--   feita em 2026-09 (Conectado / fator de corte 0.5, produto 86).
--
--   Ao aplicar no banco novo, remover a versão antiga de 3 parâmetros se ela
--   existir (DROP abaixo), para não deixar duas assinaturas sobrecarregadas.

DROP FUNCTION IF EXISTS public.f_retorna_fc(numeric, numeric, numeric[]) CASCADE;

CREATE OR REPLACE FUNCTION public.f_retorna_fc(
  p_comp numeric,
  p_larg numeric,
  p_fc numeric[],
  p_modo_corte text DEFAULT 'lista',
  p_passo numeric DEFAULT 0
)
RETURNS TABLE (new_comp numeric, new_larg numeric)
LANGUAGE plpgsql
AS $$
DECLARE
  v_fc_max NUMERIC;
  v_larg_maior NUMERIC;
  v_comp_maior NUMERIC;
  v_c_up NUMERIC;
  v_l_up NUMERIC;
BEGIN
  -- MODO PASSO: arredonda SEMPRE para cima, mas em UMA única dimensão
  -- (a de MENOR área final — melhor p/ cliente).
  IF p_modo_corte = 'passo' AND COALESCE(p_passo, 0) > 0 THEN
    v_c_up := CASE WHEN p_comp > 0 THEN ceil(p_comp / p_passo) * p_passo ELSE 0 END;
    v_l_up := CASE WHEN p_larg > 0 THEN ceil(p_larg / p_passo) * p_passo ELSE 0 END;
    IF v_c_up * p_larg <= p_comp * v_l_up THEN
      RETURN QUERY SELECT v_c_up, p_larg;
    ELSE
      RETURN QUERY SELECT p_comp, v_l_up;
    END IF;
    RETURN;
  END IF;

  -- MODO LISTA (comportamento original)
  IF p_fc IS NULL OR array_length(p_fc, 1) IS NULL THEN
    RETURN QUERY SELECT p_comp, p_larg;
    RETURN;
  END IF;

  v_fc_max := p_fc[array_length(p_fc, 1)];

  SELECT MIN(v) INTO v_larg_maior FROM UNNEST(p_fc) AS v WHERE v >= p_larg;
  SELECT MIN(v) INTO v_comp_maior FROM UNNEST(p_fc) AS v WHERE v >= p_comp;

  v_larg_maior := COALESCE(v_larg_maior, 0);
  v_comp_maior := COALESCE(v_comp_maior, 0);

  IF p_comp > v_fc_max AND p_larg > v_fc_max THEN
    RETURN QUERY SELECT p_comp, p_larg;
    RETURN;
  END IF;

  IF v_comp_maior > 0 AND v_larg_maior > 0 THEN
    IF v_comp_maior * p_larg > v_larg_maior * p_comp THEN
      RETURN QUERY SELECT p_comp, v_larg_maior;
    ELSE
      RETURN QUERY SELECT v_comp_maior, p_larg;
    END IF;
    RETURN;
  END IF;

  IF v_comp_maior = 0 THEN
    RETURN QUERY SELECT p_comp, v_larg_maior;
  ELSE
    RETURN QUERY SELECT v_comp_maior, p_larg;
  END IF;
END;
$$;
