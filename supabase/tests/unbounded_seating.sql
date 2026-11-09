-- Run as database owner after migrations. All changes roll back.
begin;
update private.dashboard_settings
set password_hash = extensions.crypt('canvas-test-password', extensions.gen_salt('bf')) where id;
do $$
declare
  table_id bigint;
  position integer[];
  snapshot jsonb;
begin
  table_id := public.dashboard_save_table('canvas-test-password', 'Canvas regression', 8);
  foreach position slice 1 in array array[[-5000, -4000], [5000, -4000], [-5000, 4000], [5000, 4000]] loop
    perform public.dashboard_move_table('canvas-test-password', table_id, position[1], position[2]);
    snapshot := public.dashboard_seating_plan('canvas-test-password');
    if not exists (
      select 1 from jsonb_array_elements(snapshot->'tables') t
      where (t->>'id')::bigint = table_id
        and (t->>'x')::integer = position[1] and (t->>'y')::integer = position[2]
    ) then raise exception 'Canvas coordinates did not persist'; end if;
  end loop;
  begin
    perform public.dashboard_move_table('wrong-password', table_id, 0, 0);
    raise exception 'Unauthorized move accepted';
  exception when sqlstate '28000' then null;
  end;
end $$;
rollback;
