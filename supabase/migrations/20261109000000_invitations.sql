-- Run in the Supabase SQL editor or apply with the Supabase CLI.
-- A link grants access to exactly one invitation; keep tokens private.
create table public.invitations (
  id bigint generated always as identity primary key,
  token uuid not null unique default gen_random_uuid(),
  guest_name text not null check (char_length(btrim(guest_name)) between 1 and 160),
  response_name text check (response_name is null or char_length(btrim(response_name)) between 1 and 160),
  attending boolean,
  notes text check (notes is null or char_length(notes) <= 1000),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

alter table public.invitations enable row level security;
revoke all on public.invitations from public, anon, authenticated;

create function public.get_invitation(invitation_token uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'guest_name', guest_name,
    'response_name', response_name,
    'attending', attending,
    'notes', notes,
    'responded_at', responded_at
  )
  from public.invitations
  where token = invitation_token and revoked_at is null;
$$;

create function public.submit_invitation_response(invitation_token uuid, guest_response_name text, guest_attending boolean, guest_notes text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if guest_response_name is null or char_length(btrim(guest_response_name)) not between 1 and 160
     or guest_attending is null or guest_notes is null or char_length(guest_notes) > 1000 then
    raise exception 'Invalid response' using errcode = '22023';
  end if;
  update public.invitations
  set response_name = btrim(guest_response_name), attending = guest_attending,
      notes = btrim(guest_notes), responded_at = now()
  where token = invitation_token and revoked_at is null;
  return found;
end;
$$;

revoke all on function public.get_invitation(uuid) from public;
revoke all on function public.submit_invitation_response(uuid, text, boolean, text) from public;
grant execute on function public.get_invitation(uuid) to anon, authenticated;
grant execute on function public.submit_invitation_response(uuid, text, boolean, text) to anon, authenticated;
