-- =============================================================
-- Fase 1 — desabilita RLS nas tabelas migradas (medida TEMPORÁRIA).
--
-- Motivo: o app ainda usa autenticação PRÓPRIA (não Supabase Auth). Durante a
-- transição Xano → Supabase, o front acessa os dados via anon key + RPCs. Sem
-- Supabase Auth, o RLS (que exige auth.uid()) bloquearia todo o acesso anon.
--
-- Quando migrarmos a autenticação (Fase 3), re-habilitar RLS e criar políticas
-- por usuário/empresa. Por ora, os dados sensíveis só são expostos via RPCs.
-- =============================================================
do $$
declare
  t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I disable row level security', t);
  end loop;
end $$;
