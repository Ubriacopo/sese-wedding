-- Families share a response link; singles can optionally be granted one companion.
alter table public.families add column invitation_type text not null default 'single'
  check (invitation_type in ('single', 'family', 'plus_one'));
update public.families f set invitation_type = 'family'
where (select count(*) from public.guests g where g.family_id = f.id) > 1;
alter table public.responses add column plus_one_name text
  check (plus_one_name is null or char_length(btrim(plus_one_name)) between 1 and 160);

create or replace function public.get_invitation(invitation_token uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select jsonb_build_object('guest_name', g.guest_name, 'response_name', r.response_name,
    'attending', r.attending, 'notes', r.notes, 'responded_at', r.responded_at,
    'invitation_type', f.invitation_type, 'family_name', f.family_name,
    'plus_one_name', r.plus_one_name,
    'members', case when f.invitation_type = 'family' then (
      select jsonb_agg(jsonb_build_object('guest_id', mg.id, 'guest_name', mg.guest_name,
        'attending', mr.attending) order by mg.id)
      from public.guests mg join public.invitations mi on mi.guest_id = mg.id
      left join public.responses mr on mr.invitation_id = mi.id
      where mg.family_id = f.id and mi.revoked_at is null
    ) else '[]'::jsonb end)
  from public.invitations i join public.guests g on g.id = i.guest_id
  join public.families f on f.id = g.family_id
  left join public.responses r on r.invitation_id = i.id
  where i.token = invitation_token and i.revoked_at is null;
$$;

create function public.submit_party_response(invitation_token uuid, guest_response_name text,
  guest_attending boolean, guest_notes text, companion_name text default null,
  member_responses jsonb default '[]'::jsonb) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected record; member record; supplied jsonb; companion text := nullif(btrim(companion_name), ''); expected_count integer;
begin
  select i.id, g.family_id, f.invitation_type into selected
  from public.invitations i join public.guests g on g.id = i.guest_id
  join public.families f on f.id = g.family_id
  where i.token = invitation_token and i.revoked_at is null for update of i, f;
  if not found then return false; end if;
  if companion is not null and (selected.invitation_type <> 'plus_one' or guest_attending is distinct from true
      or char_length(companion) > 160) then
    raise exception 'Accompagnatore non consentito' using errcode = '22023';
  end if;
  if jsonb_typeof(member_responses) is distinct from 'array' then
    raise exception 'Risposte non valide' using errcode = '22023';
  end if;
  if selected.invitation_type = 'family' then
    select count(*) into expected_count from public.guests g join public.invitations i on i.guest_id = g.id
      where g.family_id = selected.family_id and i.revoked_at is null;
    if jsonb_array_length(member_responses) <> expected_count or
      (select count(distinct x->>'guest_id') from jsonb_array_elements(member_responses) x) <> expected_count then
      raise exception 'Rispondi per tutti i membri' using errcode = '22023';
    end if;
    for member in select g.id, g.guest_name, i.token from public.guests g
      join public.invitations i on i.guest_id = g.id
      where g.family_id = selected.family_id and i.revoked_at is null order by g.id
    loop
      select x into supplied from jsonb_array_elements(member_responses) x where x->>'guest_id' = member.id::text;
      if supplied is null or jsonb_typeof(supplied->'attending') is distinct from 'boolean' then
        raise exception 'Risposta non valida' using errcode = '22023';
      end if;
      perform public.submit_invitation_response(member.token, member.guest_name, (supplied->>'attending')::boolean, guest_notes);
    end loop;
  else
    if jsonb_array_length(member_responses) <> 0 then raise exception 'Membri non consentiti' using errcode = '22023'; end if;
    perform public.submit_invitation_response(invitation_token, guest_response_name, guest_attending, guest_notes);
    update public.responses set plus_one_name = companion where invitation_id = selected.id;
  end if;
  return true;
end $$;
revoke all on function public.submit_party_response(uuid, text, boolean, text, text, jsonb) from public;
grant execute on function public.submit_party_response(uuid, text, boolean, text, text, jsonb) to anon, authenticated;

create function public.dashboard_create_invitation(admin_password text, invitation_type text,
  family_name text, guest_names text[]) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected_family bigint; selected_guest bigint; member_name text;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if invitation_type is null or invitation_type not in ('single', 'family', 'plus_one')
    or coalesce(cardinality(guest_names), 0) < 1 or cardinality(guest_names) > 50
    or (invitation_type <> 'family' and cardinality(guest_names) <> 1)
    or (invitation_type = 'family' and cardinality(guest_names) < 2) then
    raise exception 'Invito non valido' using errcode = '22023';
  end if;
  insert into public.families (family_name, invitation_type)
    values (case when invitation_type = 'family' then btrim(family_name) else btrim(guest_names[1]) end, invitation_type)
    returning id into selected_family;
  foreach member_name in array guest_names loop
    insert into public.guests (family_id, guest_name) values (selected_family, btrim(member_name)) returning id into selected_guest;
    insert into public.invitations (guest_name, guest_id) values (btrim(member_name), selected_guest);
  end loop;
  return true;
end $$;
revoke all on function public.dashboard_create_invitation(text, text, text, text[]) from public;
grant execute on function public.dashboard_create_invitation(text, text, text, text[]) to anon, authenticated;

create function public.dashboard_set_plus_one(admin_password text, selected_guest_id bigint, allowed boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected_family bigint;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  select f.id into selected_family from public.families f join public.guests g on g.family_id = f.id
    where g.id = selected_guest_id and f.invitation_type <> 'family' for update of f;
  if not found or allowed is null then raise exception 'Invito non valido' using errcode = '22023'; end if;
  update public.families set invitation_type = case when allowed then 'plus_one' else 'single' end where id = selected_family;
  if not allowed then
    update public.responses r set plus_one_name = null from public.invitations i
      where r.invitation_id = i.id and i.guest_id = selected_guest_id;
  end if;
  return true;
end $$;
revoke all on function public.dashboard_set_plus_one(text, bigint, boolean) from public;
grant execute on function public.dashboard_set_plus_one(text, bigint, boolean) to anon, authenticated;

create or replace function public.dashboard_invitations(admin_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'family_id', f.id, 'family_name', f.family_name, 'guest_id', g.id, 'guest_name', g.guest_name,
    'invitation_type', f.invitation_type, 'plus_one_name', r.plus_one_name,
    'token', i.token, 'revoked_at', i.revoked_at, 'response_name', r.response_name,
    'attending', r.attending, 'notes', r.notes, 'responded_at', r.responded_at)
    order by f.family_name, g.guest_name, g.id)
    from public.families f join public.guests g on g.family_id = f.id
    join public.invitations i on i.guest_id = g.id
    left join public.responses r on r.invitation_id = i.id), '[]'::jsonb);
end $$;

-- Retire the old creation API so new members cannot bypass invitation types.
revoke execute on function public.dashboard_add_guest(text, text, text, bigint) from anon, authenticated;

-- Older open tabs may still submit through the original RSVP API.
create function private.clear_declined_companion() returns trigger
language plpgsql set search_path = '' as $$
begin
  if not new.attending then new.plus_one_name := null; end if;
  return new;
end $$;
revoke all on function private.clear_declined_companion() from public, anon, authenticated;
create trigger clear_declined_companion before insert or update on public.responses
for each row execute function private.clear_declined_companion();
