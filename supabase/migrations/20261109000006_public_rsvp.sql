-- Public RSVP registration, with optional existing family invitation.
create function public.submit_open_response(
  family_name text, added_people jsonb, guest_notes text,
  invitation_token uuid default null, member_responses jsonb default '[]'::jsonb,
  confirmed_count integer default null, companion_name text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  selected_family bigint; selected_token uuid; capacity integer;
  person jsonb; new_guest bigint; slot integer;
  answers jsonb := member_responses;
begin
  if jsonb_typeof(added_people) is distinct from 'array'
    or jsonb_typeof(member_responses) is distinct from 'array'
    or jsonb_array_length(added_people) > 100 then
    raise exception 'Persone non valide' using errcode = '22023';
  end if;
  if invitation_token is null then
    if family_name is null or char_length(btrim(family_name)) not between 1 and 160
      or jsonb_array_length(added_people) = 0 or jsonb_array_length(member_responses) <> 0
      or confirmed_count is not null or companion_name is not null then
      raise exception 'Gruppo non valido' using errcode = '22023';
    end if;
    insert into public.families (family_name) values (btrim(family_name)) returning id into selected_family;
    select i.token into selected_token from public.invitations i where i.family_id = selected_family;
  else
    select f.id, f.maximum_guests, i.token into selected_family, capacity, selected_token
    from public.invitations i join public.families f on f.id = i.family_id
    where i.token = invitation_token and i.revoked_at is null for update of f, i;
    if not found then return null; end if;
  end if;
  if capacity is not null then
    if jsonb_array_length(added_people) <> 0 or confirmed_count is null or confirmed_count not between 0 and 100 then
      raise exception 'Numero non valido' using errcode = '22023';
    end if;
    -- Headcount invitations can grow too; create real guest slots for the dashboard.
    if confirmed_count > capacity then
      for slot in (capacity + 1)..confirmed_count loop
        insert into public.guests (family_id, guest_name, headcount_slot)
        values (selected_family, 'Ospite ' || slot, slot);
      end loop;
      update public.families set maximum_guests = confirmed_count where id = selected_family;
    end if;
  else
    if (select count(*) from public.guests where family_id = selected_family) + jsonb_array_length(added_people) > 100 then
      raise exception 'Troppe persone' using errcode = '22023';
    end if;
    for person in select value from jsonb_array_elements(added_people) loop
      if jsonb_typeof(person->'guest_name') is distinct from 'string'
        or char_length(btrim(person->>'guest_name')) not between 1 and 160
        or jsonb_typeof(person->'attending') is distinct from 'boolean' then
        raise exception 'Persona non valida' using errcode = '22023';
      end if;
      insert into public.guests (family_id, guest_name)
        values (selected_family, btrim(person->>'guest_name')) returning id into new_guest;
      answers := answers || jsonb_build_array(jsonb_build_object('guest_id', new_guest, 'attending', person->'attending'));
    end loop;
  end if;
  if not public.submit_family_response(selected_token, guest_notes, answers, confirmed_count, companion_name) then
    raise exception 'Invito non valido' using errcode = '22023';
  end if;
  return public.get_invitation(selected_token) || jsonb_build_object('token', selected_token);
end $$;
revoke all on function public.submit_open_response(text, jsonb, text, uuid, jsonb, integer, text) from public;
grant execute on function public.submit_open_response(text, jsonb, text, uuid, jsonb, integer, text) to anon, authenticated;
