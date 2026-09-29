-- =============================================================
-- Fase 2B — DEFAULT now() nas colunas created_at (robustez)
-- =============================================================
do $$
declare
  r record;
begin
  for r in
    select table_name, column_name
    from information_schema.columns
    where table_schema = 'public'
      and column_name = 'created_at'
      and data_type = 'timestamp with time zone'
  loop
    execute format('alter table public.%I alter column created_at set default now()', r.table_name);
  end loop;
end $$;
