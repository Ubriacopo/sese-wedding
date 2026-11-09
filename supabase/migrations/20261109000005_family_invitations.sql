-- Preserve member responses, then consolidate invitation credentials per family.
alter table public.responses add column guest_id bigint references public.guests(id);
update public.responses r set guest_id = i.guest_id from public.invitations i where i.id = r.invitation_id;
alter table public.responses alter column guest_id set not null;
alter table public.responses drop column invitation_id;
alter table public.responses add primary key (guest_id);
alter table public.guests add column headcount_slot integer check (headcount_slot > 0);
alter table public.guests add unique (family_id, headcount_slot);
alter table public.families add column maximum_guests integer check (maximum_guests between 1 and 100);
create table public.family_responses (
  family_id bigint primary key references public.families(id),
  confirmed_count integer check (confirmed_count between 0 and 100),
  notes text not null default '' check (char_length(notes) <= 1000),
  responded_at timestamptz not null default now()
);
insert into public.family_responses (family_id, notes, responded_at)
select distinct on (g.family_id) g.family_id, r.notes, r.responded_at
from public.responses r join public.guests g on g.id = r.guest_id order by g.family_id, r.responded_at desc;
alter table public.family_responses enable row level security;
revoke all on public.family_responses from public, anon, authenticated;
alter table public.invitations add column family_id bigint references public.families(id);
update public.invitations i set family_id = g.family_id from public.guests g where g.id = i.guest_id;
-- Keep one existing live link when possible. Other old member links cease to authorize access.
delete from public.invitations where id not in (
  select distinct on (family_id) id from public.invitations order by family_id, (revoked_at is not null), id
);
alter table public.invitations alter column family_id set not null;
alter table public.invitations add unique (family_id);
alter table public.invitations drop column guest_id, drop column guest_name,
  drop column response_name, drop column attending, drop column notes, drop column responded_at;
insert into public.invitations (family_id) select id from public.families f
where not exists (select 1 from public.invitations i where i.family_id = f.id);
create function private.create_family_invitation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin insert into public.invitations (family_id) values (new.id); return new; end $$;
revoke all on function private.create_family_invitation() from public, anon, authenticated;
create trigger create_family_invitation after insert on public.families
for each row execute function private.create_family_invitation();

create or replace function public.get_invitation(invitation_token uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select jsonb_build_object('family_name', f.family_name, 'by_headcount', f.maximum_guests is not null,
    'allow_plus_one', f.allow_plus_one, 'plus_one_name', f.plus_one_name,
    'confirmed_count', fr.confirmed_count, 'notes', fr.notes, 'responded_at', fr.responded_at,
    'members', case when f.maximum_guests is not null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('guest_id', g.id, 'guest_name', g.guest_name, 'attending', r.attending) order by g.id)
      from public.guests g left join public.responses r on r.guest_id = g.id where g.family_id = f.id
    ), '[]'::jsonb) end)
  from public.invitations i join public.families f on f.id = i.family_id
  left join public.family_responses fr on fr.family_id = f.id
  where i.token = invitation_token and i.revoked_at is null;
$$;

create function public.submit_family_response(invitation_token uuid, guest_notes text,
  member_responses jsonb default '[]'::jsonb, confirmed_count integer default null,
  companion_name text default null) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected record; member record; supplied jsonb; expected_count integer;
  companion text := nullif(btrim(companion_name), ''); any_attending boolean := false;
begin
  select f.id, f.maximum_guests, f.allow_plus_one into selected from public.invitations i
    join public.families f on f.id = i.family_id
    where i.token = invitation_token and i.revoked_at is null for update of f, i;
  if not found then return false; end if;
  if guest_notes is null or char_length(guest_notes) > 1000 or jsonb_typeof(member_responses) is distinct from 'array' then
    raise exception 'Risposta non valida' using errcode = '22023'; end if;
  if companion is not null and (not selected.allow_plus_one or char_length(companion) > 160) then
    raise exception 'Accompagnatore non consentito' using errcode = '22023'; end if;
  if selected.maximum_guests is not null then
    if confirmed_count is null or confirmed_count < 0 or confirmed_count > selected.maximum_guests
      or jsonb_array_length(member_responses) <> 0 then
      raise exception 'Numero non valido. Contatta gli sposi se hai bisogno di aiuto.' using errcode = '22023'; end if;
    any_attending := confirmed_count > 0;
    insert into public.responses (guest_id, response_name, attending, notes, responded_at)
    select g.id, g.guest_name, g.headcount_slot <= confirmed_count, btrim(guest_notes), now()
      from public.guests g where g.family_id = selected.id
    on conflict (guest_id) do update set attending = excluded.attending, notes = excluded.notes, responded_at = excluded.responded_at;
  else
    select count(*) into expected_count from public.guests where family_id = selected.id;
    if confirmed_count is not null or jsonb_array_length(member_responses) <> expected_count or
      (select count(distinct x->>'guest_id') from jsonb_array_elements(member_responses) x) <> expected_count then
      raise exception 'Rispondi per tutti i membri della famiglia' using errcode = '22023'; end if;
    for member in select id, guest_name from public.guests where family_id = selected.id order by id loop
      select x into supplied from jsonb_array_elements(member_responses) x where x->>'guest_id' = member.id::text;
      if supplied is null or jsonb_typeof(supplied->'attending') is distinct from 'boolean' then
        raise exception 'Risposta non valida' using errcode = '22023'; end if;
      any_attending := any_attending or (supplied->>'attending')::boolean;
      insert into public.responses (guest_id, response_name, attending, notes, responded_at)
      values (member.id, member.guest_name, (supplied->>'attending')::boolean, btrim(guest_notes), now())
      on conflict (guest_id) do update set attending = excluded.attending, notes = excluded.notes, responded_at = excluded.responded_at;
    end loop;
  end if;
  if companion is not null and not any_attending then raise exception 'Accompagnatore senza invitati presenti' using errcode = '22023'; end if;
  insert into public.family_responses (family_id, confirmed_count, notes, responded_at)
    values (selected.id, confirmed_count, btrim(guest_notes), now())
    on conflict (family_id) do update set confirmed_count = excluded.confirmed_count, notes = excluded.notes, responded_at = excluded.responded_at;
  update public.families set plus_one_name = companion where id = selected.id;
  return true;
end $$;
revoke all on function public.submit_family_response(uuid, text, jsonb, integer, text) from public;
grant execute on function public.submit_family_response(uuid, text, jsonb, integer, text) to anon, authenticated;
drop function public.submit_party_response(uuid, text, boolean, text, text, jsonb);
drop function public.submit_invitation_response(uuid, text, boolean, text);

create function public.dashboard_create_family(admin_password text, family_name text, member_names text[] default '{}',
  maximum_guests integer default null, bonus_one boolean default false) returns bigint
language plpgsql security definer set search_path = '' as $$
declare new_family bigint; member_name text; slot integer;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if family_name is null or char_length(btrim(family_name)) not between 1 and 160 or bonus_one is null
    or member_names is null or (maximum_guests is null and cardinality(member_names) not between 1 and 100)
    or (maximum_guests is not null and (maximum_guests not between 1 and 100 or cardinality(member_names) <> 0)) then
    raise exception 'Famiglia non valida' using errcode = '22023'; end if;
  insert into public.families (family_name, maximum_guests, allow_plus_one)
    values (btrim(family_name), maximum_guests, bonus_one) returning id into new_family;
  if maximum_guests is not null then
    for slot in 1..maximum_guests loop
      insert into public.guests (family_id, guest_name, headcount_slot) values (new_family, 'Ospite ' || slot, slot);
    end loop;
  else
    foreach member_name in array member_names loop
      insert into public.guests (family_id, guest_name) values (new_family, btrim(member_name));
    end loop;
  end if;
  return new_family;
end $$;
revoke all on function public.dashboard_create_family(text, text, text[], integer, boolean) from public;
grant execute on function public.dashboard_create_family(text, text, text[], integer, boolean) to anon, authenticated;

create or replace function public.dashboard_add_guest(admin_password text, family_name text, guest_name text, existing_family_id bigint default null) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected_family bigint;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if existing_family_id is null then
    perform public.dashboard_create_family(admin_password, family_name, array[guest_name]);
  else
    select id into selected_family from public.families where id = existing_family_id and maximum_guests is null for update;
    if not found then raise exception 'Famiglia nominativa non trovata' using errcode = '22023'; end if;
    insert into public.guests (family_id, guest_name) values (selected_family, btrim(guest_name));
  end if;
  return true;
end $$;

create function public.dashboard_family_invitations(admin_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'family_id', f.id, 'family_name', f.family_name, 'maximum_guests', f.maximum_guests,
    'allow_plus_one', f.allow_plus_one, 'plus_one_name', f.plus_one_name,
    'token', i.token, 'revoked_at', i.revoked_at,
    'confirmed_count', fr.confirmed_count, 'notes', fr.notes, 'responded_at', fr.responded_at,
    'members', coalesce((select jsonb_agg(jsonb_build_object('guest_id', g.id, 'guest_name', g.guest_name,
      'attending', r.attending) order by g.id) from public.guests g
      left join public.responses r on r.guest_id = g.id where g.family_id = f.id), '[]'::jsonb)
    ) order by f.family_name, f.id) from public.families f join public.invitations i on i.family_id = f.id
    left join public.family_responses fr on fr.family_id = f.id), '[]'::jsonb);
end $$;
revoke all on function public.dashboard_family_invitations(text) from public;
grant execute on function public.dashboard_family_invitations(text) to anon, authenticated;
drop function public.dashboard_invitations(text);

create or replace function public.dashboard_seating_plan(admin_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  return jsonb_build_object(
    'tables', coalesce((select jsonb_agg(to_jsonb(t) order by t.id) from public.seating_tables t), '[]'::jsonb),
    'people', coalesce((select jsonb_agg(to_jsonb(p) order by p.family_name, p.name, p.key) from (
      select 'guest:' || g.id as key, case when f.maximum_guests is null then g.guest_name else f.family_name || ' · ' || g.guest_name end as name, f.family_name, r.attending,
        false as companion, a.table_id, a.seat_number
      from public.guests g join public.families f on f.id = g.family_id
      left join public.responses r on r.guest_id = g.id
      left join public.seating_assignments a on a.guest_id = g.id
      union all
      select 'companion:' || f.id, f.plus_one_name, f.family_name,
        case when exists (select 1 from public.guests g join public.responses r on r.guest_id = g.id where g.family_id = f.id and r.attending) then true
        when exists (select 1 from public.guests g left join public.responses r on r.guest_id = g.id where g.family_id = f.id and r.attending is null) then null
        else false end,
        true, a.table_id, a.seat_number
      from public.families f left join public.seating_assignments a on a.companion_family_id = f.id
      where f.allow_plus_one and f.plus_one_name is not null
    ) p), '[]'::jsonb)
  );
end $$;

