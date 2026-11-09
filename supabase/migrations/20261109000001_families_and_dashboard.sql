-- Apply after 20261109000000_invitations.sql. Existing invitations and replies are retained.
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.families (
  id bigint generated always as identity primary key,
  family_name text not null check (char_length(btrim(family_name)) between 1 and 160),
  created_at timestamptz not null default now()
);
create table public.guests (
  id bigint generated always as identity primary key,
  family_id bigint not null references public.families(id),
  guest_name text not null check (char_length(btrim(guest_name)) between 1 and 160),
  created_at timestamptz not null default now()
);
alter table public.invitations add column guest_id bigint unique references public.guests(id);
create table public.responses (
  invitation_id bigint primary key references public.invitations(id),
  response_name text not null check (char_length(btrim(response_name)) between 1 and 160),
  attending boolean not null,
  notes text not null default '' check (char_length(notes) <= 1000),
  responded_at timestamptz not null default now()
);

-- Legacy invitations have no family information, so give each one its own family.
do $$
declare item record; new_family bigint; new_guest bigint;
begin
  for item in select * from public.invitations loop
    insert into public.families (family_name) values (item.guest_name) returning id into new_family;
    insert into public.guests (family_id, guest_name) values (new_family, item.guest_name) returning id into new_guest;
    update public.invitations set guest_id = new_guest where id = item.id;
    if item.attending is not null and item.response_name is not null then
      insert into public.responses (invitation_id, response_name, attending, notes, responded_at)
      values (item.id, item.response_name, item.attending, coalesce(item.notes, ''), coalesce(item.responded_at, now()));
    end if;
  end loop;
end $$;
alter table public.invitations alter column guest_id set not null;

alter table public.families enable row level security;
alter table public.guests enable row level security;
alter table public.responses enable row level security;
revoke all on public.families, public.guests, public.responses from public, anon, authenticated;

create table private.dashboard_settings (id boolean primary key default true check (id), password_hash text not null);
insert into private.dashboard_settings (id, password_hash) values (true, extensions.crypt('admin', extensions.gen_salt('bf')));
revoke all on private.dashboard_settings from public, anon, authenticated;

create function private.dashboard_authorized(password text) returns boolean
language sql security definer set search_path = '' as $$
  select coalesce(password is not null and password_hash = extensions.crypt(password, password_hash), false)
  from private.dashboard_settings where id;
$$;
revoke all on function private.dashboard_authorized(text) from public, anon, authenticated;

create or replace function public.get_invitation(invitation_token uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select jsonb_build_object('guest_name', g.guest_name, 'response_name', r.response_name,
    'attending', r.attending, 'notes', r.notes, 'responded_at', r.responded_at)
  from public.invitations i join public.guests g on g.id = i.guest_id
  left join public.responses r on r.invitation_id = i.id
  where i.token = invitation_token and i.revoked_at is null;
$$;
create or replace function public.submit_invitation_response(invitation_token uuid, guest_response_name text, guest_attending boolean, guest_notes text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected_invitation bigint;
begin
  if guest_response_name is null or char_length(btrim(guest_response_name)) not between 1 and 160
     or guest_attending is null or guest_notes is null or char_length(guest_notes) > 1000 then
    raise exception 'Invalid response' using errcode = '22023';
  end if;
  select id into selected_invitation from public.invitations where token = invitation_token and revoked_at is null for update;
  if selected_invitation is null then return false; end if;
  insert into public.responses (invitation_id, response_name, attending, notes, responded_at)
  values (selected_invitation, btrim(guest_response_name), guest_attending, btrim(guest_notes), now())
  on conflict (invitation_id) do update set response_name = excluded.response_name,
    attending = excluded.attending, notes = excluded.notes, responded_at = excluded.responded_at;
  return true;
end $$;

create function public.dashboard_invitations(admin_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'family_id', f.id, 'family_name', f.family_name, 'guest_id', g.id, 'guest_name', g.guest_name,
    'token', i.token, 'revoked_at', i.revoked_at, 'response_name', r.response_name,
    'attending', r.attending, 'notes', r.notes, 'responded_at', r.responded_at)
    order by f.family_name, g.guest_name, g.id)
    from public.families f join public.guests g on g.family_id = f.id
    join public.invitations i on i.guest_id = g.id
    left join public.responses r on r.invitation_id = i.id), '[]'::jsonb);
end $$;

create function public.dashboard_add_guest(admin_password text, family_name text, guest_name text, existing_family_id bigint default null) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected_family bigint; selected_guest bigint;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if guest_name is null or char_length(btrim(guest_name)) not between 1 and 160 then raise exception 'Nome non valido' using errcode = '22023'; end if;
  if existing_family_id is not null then
    select id into selected_family from public.families where id = existing_family_id;
    if selected_family is null then raise exception 'Famiglia non trovata' using errcode = '22023'; end if;
  else
    if family_name is null or char_length(btrim(family_name)) not between 1 and 160 then raise exception 'Famiglia non valida' using errcode = '22023'; end if;
    insert into public.families (family_name) values (btrim(family_name)) returning id into selected_family;
  end if;
  insert into public.guests (family_id, guest_name) values (selected_family, btrim(guest_name)) returning id into selected_guest;
  insert into public.invitations (guest_name, guest_id) values (btrim(guest_name), selected_guest);
  return true;
end $$;
revoke all on function public.dashboard_invitations(text) from public;
revoke all on function public.dashboard_add_guest(text, text, text, bigint) from public;
grant execute on function public.dashboard_invitations(text), public.dashboard_add_guest(text, text, text, bigint) to anon, authenticated;

create function public.dashboard_change_password(admin_password text, new_password text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if new_password is null or char_length(new_password) < 12 or char_length(new_password) > 72 then
    raise exception 'Password non valida' using errcode = '22023';
  end if;
  update private.dashboard_settings set password_hash = extensions.crypt(new_password, extensions.gen_salt('bf')) where id;
  return true;
end $$;
revoke all on function public.dashboard_change_password(text, text) from public;
grant execute on function public.dashboard_change_password(text, text) to anon, authenticated;
