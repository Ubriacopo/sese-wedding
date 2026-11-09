-- Replace the invitation type model with one optional companion per family/group.
alter table public.families add column allow_plus_one boolean not null default false;
alter table public.families add column plus_one_name text
  check (plus_one_name is null or char_length(btrim(plus_one_name)) between 1 and 160);
update public.families set allow_plus_one = invitation_type = 'plus_one';
update public.families f set plus_one_name = r.plus_one_name
from public.guests g join public.invitations i on i.guest_id = g.id
join public.responses r on r.invitation_id = i.id
where g.family_id = f.id and r.plus_one_name is not null;
alter table public.families add constraint family_companion_requires_permission check (allow_plus_one or plus_one_name is null);

create or replace function public.get_invitation(invitation_token uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select jsonb_build_object('guest_name', g.guest_name, 'response_name', r.response_name,
    'attending', r.attending, 'notes', r.notes, 'responded_at', r.responded_at,
    'allow_plus_one', f.allow_plus_one, 'family_name', f.family_name,
    'plus_one_name', f.plus_one_name,
    'members', (
      select jsonb_agg(jsonb_build_object('guest_id', mg.id, 'guest_name', mg.guest_name,
        'attending', mr.attending) order by mg.id)
      from public.guests mg join public.invitations mi on mi.guest_id = mg.id
      left join public.responses mr on mr.invitation_id = mi.id
      where mg.family_id = f.id and mi.revoked_at is null
    ))
  from public.invitations i join public.guests g on g.id = i.guest_id
  join public.families f on f.id = g.family_id
  left join public.responses r on r.invitation_id = i.id
  where i.token = invitation_token and i.revoked_at is null;
$$;

create or replace function public.submit_party_response(invitation_token uuid, guest_response_name text,
  guest_attending boolean, guest_notes text, companion_name text default null,
  member_responses jsonb default '[]'::jsonb) returns boolean
language plpgsql security definer set search_path = '' as $$
declare selected record; member record; supplied jsonb; companion text := nullif(btrim(companion_name), ''); expected_count integer; any_attending boolean := false;
begin
  select i.id, g.family_id, f.allow_plus_one into selected
  from public.invitations i join public.guests g on g.id = i.guest_id
  join public.families f on f.id = g.family_id
  where i.token = invitation_token and i.revoked_at is null for update of f;
  if not found then return false; end if;
  if companion is not null and (not selected.allow_plus_one or char_length(companion) > 160) then
    raise exception 'Accompagnatore non consentito' using errcode = '22023';
  end if;
  if jsonb_typeof(member_responses) is distinct from 'array' then
    raise exception 'Risposte non valide' using errcode = '22023';
  end if;
  select count(*) into expected_count from public.guests g join public.invitations i on i.guest_id = g.id
      where g.family_id = selected.family_id and i.revoked_at is null;
  if expected_count > 1 then
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
      any_attending := any_attending or (supplied->>'attending')::boolean;
      perform public.submit_invitation_response(member.token, member.guest_name, (supplied->>'attending')::boolean, guest_notes);
    end loop;
  else
    if jsonb_array_length(member_responses) <> 0 then raise exception 'Membri non consentiti' using errcode = '22023'; end if;
    perform public.submit_invitation_response(invitation_token, guest_response_name, guest_attending, guest_notes);
    any_attending := guest_attending;
  end if;
  if companion is not null and any_attending is distinct from true then
    raise exception 'Accompagnatore senza invitati presenti' using errcode = '22023';
  end if;
  update public.families set plus_one_name = companion where id = selected.family_id;
  return true;
end $$;
revoke all on function public.submit_party_response(uuid, text, boolean, text, text, jsonb) from public;
grant execute on function public.submit_party_response(uuid, text, boolean, text, text, jsonb) to anon, authenticated;

create or replace function public.dashboard_invitations(admin_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'family_id', f.id, 'family_name', f.family_name, 'guest_id', g.id, 'guest_name', g.guest_name,
    'allow_plus_one', f.allow_plus_one, 'plus_one_name', f.plus_one_name,
    'token', i.token, 'revoked_at', i.revoked_at, 'response_name', r.response_name,
    'attending', r.attending, 'notes', r.notes, 'responded_at', r.responded_at)
    order by f.family_name, g.guest_name, g.id)
    from public.families f join public.guests g on g.family_id = f.id
    join public.invitations i on i.guest_id = g.id
    left join public.responses r on r.invitation_id = i.id), '[]'::jsonb);
end $$;

create function public.dashboard_set_family_plus_one(admin_password text, selected_family_id bigint, allowed boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if allowed is null then raise exception 'Valore non valido' using errcode = '22023'; end if;
  update public.families set allow_plus_one = allowed,
    plus_one_name = case when allowed then plus_one_name else null end where id = selected_family_id;
  if not found then raise exception 'Famiglia non trovata' using errcode = '22023'; end if;
  return true;
end $$;
revoke all on function public.dashboard_set_family_plus_one(text, bigint, boolean) from public;
grant execute on function public.dashboard_set_family_plus_one(text, bigint, boolean) to anon, authenticated;
grant execute on function public.dashboard_add_guest(text, text, text, bigint) to anon, authenticated;

drop function public.dashboard_create_invitation(text, text, text, text[]);
drop function public.dashboard_set_plus_one(text, bigint, boolean);
drop trigger clear_declined_companion on public.responses;
drop function private.clear_declined_companion();
alter table public.responses drop column plus_one_name;
alter table public.families drop column invitation_type;
