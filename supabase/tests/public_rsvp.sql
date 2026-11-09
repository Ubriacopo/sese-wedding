begin;
do $$
declare saved jsonb; updated jsonb; family bigint; before_count integer;
begin
  saved := public.submit_open_response('Test public RSVP',
    '[{"guest_name":"Alice","attending":true},{"guest_name":"Bob","attending":false}]', 'Note');
  if jsonb_array_length(saved->'members') <> 2 then raise exception 'Missing public guests'; end if;
  select family_id into family from public.invitations where token = (saved->>'token')::uuid;
  if (select count(*) from public.responses r join public.guests g on g.id = r.guest_id where g.family_id = family) <> 2 then
    raise exception 'Missing dashboard responses'; end if;
  updated := public.submit_open_response('', '[{"guest_name":"Carla","attending":true}]', '',
    (saved->>'token')::uuid,
    (select jsonb_agg(jsonb_build_object('guest_id', x->'guest_id', 'attending', x->'attending')) from jsonb_array_elements(saved->'members') x));
  if jsonb_array_length(updated->'members') <> 3 then raise exception 'Added member missing'; end if;
  select count(*) into before_count from public.families;
  begin
    perform public.submit_open_response('Invalid group', '[{"guest_name":" ","attending":true}]', '');
    raise exception 'Invalid name accepted';
  exception when sqlstate '22023' then null;
  end;
  if (select count(*) from public.families) <> before_count then raise exception 'Partial registration persisted'; end if;
  update public.invitations set revoked_at = now() where family_id = family;
  if public.submit_open_response('', '[]', '', (saved->>'token')::uuid) is not null then
    raise exception 'Revoked link accepted'; end if;
end $$;
rollback;
