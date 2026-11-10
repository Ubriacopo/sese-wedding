-- Run as owner after all migrations. Test data and password changes roll back.
begin;
update private.dashboard_settings set password_hash = extensions.crypt('credits-test-password', extensions.gen_salt('bf')) where id;
do $$
declare
  test_password text := 'credits-test-password'; suffix text := gen_random_uuid()::text;
  named bigint; numbered bigint; revoked bigint; credit_names text[]; sample jsonb;
  guest_one text := 'Credit Guest One '; guest_two text := 'Credit Guest Two ';
  companion text := 'Credit Companion '; placeholder text := 'Credit Placeholder ';
  revoked_name text := 'Credit Revoked ';
begin
  guest_one := guest_one || suffix;
  guest_two := guest_two || suffix;
  companion := companion || suffix;
  revoked_name := revoked_name || suffix;
  named := public.dashboard_create_family(test_password, 'Credits named ' || suffix, array[guest_one, guest_two], null, true);
  numbered := public.dashboard_create_family(test_password, 'Credits numbered ' || suffix, '{}', 2, true);
  revoked := public.dashboard_create_family(test_password, 'Credits revoked ' || suffix, array[revoked_name], null, false);
  update public.families set plus_one_name = companion where id = named;
  update public.guests set guest_name = placeholder || suffix || ' ' || headcount_slot::text
    where family_id = numbered and headcount_slot is not null;
  update public.invitations set revoked_at = now() where family_id = revoked;

  select array_agg(guest_name order by guest_name) into credit_names
  from public.guest_credits()
  where guest_name in (guest_one, guest_two, companion, revoked_name,
    placeholder || suffix || ' 1', placeholder || suffix || ' 2');
  if credit_names is distinct from array[companion, guest_one, guest_two] then
    raise exception 'Unexpected credit names: %', credit_names;
  end if;
  select to_jsonb(credits) into sample
  from (select * from public.guest_credits()) credits where guest_name = guest_one;
  if sample is distinct from jsonb_build_object('guest_name', guest_one) then
    raise exception 'Credits returned fields other than the guest name: %', sample;
  end if;
  if not has_function_privilege('anon', 'public.guest_credits()', 'execute')
    or not has_function_privilege('authenticated', 'public.guest_credits()', 'execute') then
    raise exception 'Public guest credits access is not granted';
  end if;
  if exists (
    select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) privilege
    where p.oid = 'public.guest_credits()'::regprocedure and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ) then raise exception 'Guest credits is executable by PUBLIC'; end if;
end $$;
rollback;
