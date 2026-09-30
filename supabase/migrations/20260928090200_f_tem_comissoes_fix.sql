-- =============================================================
-- Fase 3 — Ajuste: f_tem_comissoes resolve o plano diretamente
-- (sem depender de perfil_efetivo, que agora exige autenticação).
-- Evita quebra no Edge Function equipe-criar (service role, sem JWT).
-- =============================================================
create or replace function public.f_tem_comissoes(p_user_id bigint)
returns boolean language sql stable as $$
  select coalesce((
    select u.plano = 'plus' from usuarios u where u.id = f_empresa_id(p_user_id)
  ), false)
$$;
