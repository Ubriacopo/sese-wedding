create function public.guest_credits() returns table (guest_name text)
language sql stable security definer set search_path = '' as $$
  select credits.guest_name
  from (
    select btrim(g.guest_name) as guest_name, f.id as family_id, 0 as person_type, g.id as person_id
    from public.invitations i
    join public.families f on f.id = i.family_id
    join public.guests g on g.family_id = f.id
    where i.revoked_at is null and g.headcount_slot is null
      and nullif(btrim(g.guest_name), '') is not null
    union all
    select btrim(f.plus_one_name), f.id, 1, null::bigint
    from public.invitations i
    join public.families f on f.id = i.family_id
    where i.revoked_at is null and f.allow_plus_one
      and nullif(btrim(f.plus_one_name), '') is not null
  ) credits
  order by credits.family_id, credits.person_type, credits.person_id;
$$;

revoke all on function public.guest_credits() from public;
grant execute on function public.guest_credits() to anon, authenticated;