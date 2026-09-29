-- =============================================================
-- Fase 3 — Auth: vínculo usuarios ↔ auth.users + RPC auth_me()
-- =============================================================

-- Vínculo da identidade Supabase Auth com a tabela de negócio usuarios.
alter table public.usuarios add column if not exists auth_id uuid;
create unique index if not exists usuarios_auth_id_key on public.usuarios (auth_id);

-- Quando um auth.users é criado (convite/signup), liga (ou cria) a linha em usuarios.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update usuarios
  set auth_id = new.id
  where lower(email) = lower(new.email) and auth_id is null;

  if not found then
    insert into usuarios (
      created_at, name, name_first, name_last, email, frt_b2b, margem,
      dias_vencimento_orcamento, razao, fantasia, cnpj, ie, cpf, is_pj,
      role, ativo, auth_id, logo, google_oauth
    ) values (
      now(),
      coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), new.email),
      coalesce(nullif(new.raw_user_meta_data ->> 'name_first', ''), ''),
      coalesce(nullif(new.raw_user_meta_data ->> 'name_last', ''), ''),
      new.email,
      0,
      0,
      0,
      '',
      '',
      '',
      '',
      '',
      true,
      'vendedor',
      true,
      new.id,
      '',
      jsonb_build_object('id', '', 'name', '', 'email', new.email)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Retorna o usuário logado (resolvido por auth.uid()), no formato do antigo /auth/me.
create or replace function public.auth_me()
returns jsonb language plpgsql stable as $$
declare
  v_id bigint;
  v_u usuarios%rowtype;
  v_telefones jsonb;
  v_endereco jsonb;
  v_ativo_efetivo boolean;
begin
  select id into v_id from usuarios where auth_id = auth.uid();
  if v_id is null then
    return null;
  end if;

  select * into v_u from usuarios where id = v_id;

  select coalesce(jsonb_agg(
    jsonb_build_object('id', t.id, 'telefone', t.telefone, 'tipo_telefone', t.tipo_telefone)
    order by t.id
  ), '[]'::jsonb)
  into v_telefones
  from telefone_user t
  where t.user_id = v_id;

  select to_jsonb(e) into v_endereco
  from endereco_user e where e.user_id = v_id order by e.id limit 1;

  v_ativo_efetivo := f_ativo_efetivo(v_id);

  return to_jsonb(v_u)
    - 'password'
    - 'auth_id'
    - 'google_oauth'
    || jsonb_build_object(
      'frtB2B', v_u.frt_b2b,
      'DiasVencimentoOrcamento', v_u.dias_vencimento_orcamento,
      'isPJ', v_u.is_pj,
      'ativo_efetivo', v_ativo_efetivo,
      '_telefones', v_telefones,
      '_endereco_user', v_endereco
    );
end;
$$;
