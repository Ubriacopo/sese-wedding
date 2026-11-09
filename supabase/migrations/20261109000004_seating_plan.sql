create table public.seating_tables (
  id bigint generated always as identity primary key,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  capacity integer not null default 8 check (capacity between 1 and 20),
  x integer not null default 20 check (x between 0 and 900),
  y integer not null default 20 check (y between 0 and 600),
  archived boolean not null default false
);
create table public.seating_assignments (
  table_id bigint not null references public.seating_tables(id),
  seat_number integer not null check (seat_number between 1 and 20),
  guest_id bigint unique references public.guests(id),
  companion_family_id bigint unique references public.families(id),
  primary key (table_id, seat_number),
  check (num_nonnulls(guest_id, companion_family_id) = 1)
);
alter table public.seating_tables enable row level security;
alter table public.seating_assignments enable row level security;
revoke all on public.seating_tables, public.seating_assignments from public, anon, authenticated;

create function public.dashboard_seating_plan(admin_password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  return jsonb_build_object(
    'tables', coalesce((select jsonb_agg(to_jsonb(t) order by t.id) from public.seating_tables t), '[]'::jsonb),
    'people', coalesce((select jsonb_agg(to_jsonb(p) order by p.family_name, p.name, p.key) from (
      select 'guest:' || g.id as key, g.guest_name as name, f.family_name, r.attending,
        false as companion, a.table_id, a.seat_number
      from public.guests g join public.families f on f.id = g.family_id
      join public.invitations i on i.guest_id = g.id
      left join public.responses r on r.invitation_id = i.id
      left join public.seating_assignments a on a.guest_id = g.id
      union all
      select 'companion:' || f.id, f.plus_one_name, f.family_name,
        case when exists (select 1 from public.guests g join public.invitations i on i.guest_id = g.id
          join public.responses r on r.invitation_id = i.id where g.family_id = f.id and r.attending) then true
        when exists (select 1 from public.guests g join public.invitations i on i.guest_id = g.id
          left join public.responses r on r.invitation_id = i.id where g.family_id = f.id and r.attending is null) then null
        else false end,
        true, a.table_id, a.seat_number
      from public.families f left join public.seating_assignments a on a.companion_family_id = f.id
      where f.allow_plus_one and f.plus_one_name is not null
    ) p), '[]'::jsonb)
  );
end $$;

create function public.dashboard_save_table(admin_password text, table_name text, seat_capacity integer,
  selected_table_id bigint default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare saved_id bigint;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if table_name is null or char_length(btrim(table_name)) not between 1 and 80 or seat_capacity is null or seat_capacity not between 1 and 20 then
    raise exception 'Nome o capienza non validi' using errcode = '22023'; end if;
  if selected_table_id is null then
    insert into public.seating_tables (name, capacity) values (btrim(table_name), seat_capacity) returning id into saved_id;
    update public.seating_tables set x = 20 + (((saved_id - 1) % 4)::integer * 290),
      y = 20 + (((saved_id - 1) / 4 % 3)::integer * 280) where id = saved_id;
  else
    perform 1 from public.seating_tables where id = selected_table_id for update;
    if not found then raise exception 'Tavolo non trovato' using errcode = '22023'; end if;
    if exists (select 1 from public.seating_assignments where table_id = selected_table_id and seat_number > seat_capacity) then
      raise exception 'Sposta prima gli invitati dai posti da rimuovere' using errcode = '22023'; end if;
    update public.seating_tables set name = btrim(table_name), capacity = seat_capacity where id = selected_table_id returning id into saved_id;
  end if;
  return saved_id;
end $$;

create function public.dashboard_move_table(admin_password text, selected_table_id bigint, position_x integer, position_y integer) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  update public.seating_tables set x = position_x, y = position_y where id = selected_table_id;
  if not found then raise exception 'Tavolo non trovato' using errcode = '22023'; end if;
  return true;
end $$;

create function public.dashboard_archive_table(admin_password text, selected_table_id bigint, is_archived boolean) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  update public.seating_tables set archived = is_archived where id = selected_table_id;
  if not found then raise exception 'Tavolo non trovato' using errcode = '22023'; end if;
  return true;
end $$;

create function public.dashboard_assign_seat(admin_password text, person_key text,
  selected_table_id bigint default null, selected_seat integer default null) returns boolean
language plpgsql security definer set search_path = '' as $$
declare person_id bigint; is_companion boolean; target_capacity integer;
begin
  if not private.dashboard_authorized(admin_password) then raise exception 'Accesso non autorizzato' using errcode = '28000'; end if;
  if person_key is null or person_key !~ '^(guest|companion):[0-9]+$' then raise exception 'Invitato non valido' using errcode = '22023'; end if;
  person_id := split_part(person_key, ':', 2)::bigint;
  is_companion := split_part(person_key, ':', 1) = 'companion';
  if is_companion then
    perform 1 from public.families where id = person_id and allow_plus_one and plus_one_name is not null for update;
  else
    perform 1 from public.guests where id = person_id for update;
  end if;
  if not found then raise exception 'Invitato non trovato' using errcode = '22023'; end if;
  if selected_table_id is not null then
    select capacity into target_capacity from public.seating_tables where id = selected_table_id and not archived for update;
    if not found or selected_seat is null or selected_seat not between 1 and target_capacity then raise exception 'Posto non valido' using errcode = '22023'; end if;
    if exists (select 1 from public.seating_assignments where table_id = selected_table_id and seat_number = selected_seat
      and not (coalesce(guest_id = person_id and not is_companion, false) or coalesce(companion_family_id = person_id and is_companion, false))) then
      raise exception 'Il posto è già occupato' using errcode = '22023'; end if;
  elsif selected_seat is not null then raise exception 'Tavolo non valido' using errcode = '22023'; end if;
  delete from public.seating_assignments where (not is_companion and guest_id = person_id) or (is_companion and companion_family_id = person_id);
  if selected_table_id is not null then
    insert into public.seating_assignments (table_id, seat_number, guest_id, companion_family_id)
    values (selected_table_id, selected_seat, case when not is_companion then person_id end, case when is_companion then person_id end);
  end if;
  return true;
end $$;

-- Removing a family's companion also frees their seat; renaming keeps the assignment.
create function private.clear_companion_seat() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not new.allow_plus_one or new.plus_one_name is null then
    delete from public.seating_assignments where companion_family_id = new.id;
  end if;
  return new;
end $$;
create trigger clear_companion_seat after update of allow_plus_one, plus_one_name on public.families
for each row execute function private.clear_companion_seat();
revoke all on function private.clear_companion_seat() from public, anon, authenticated;

revoke all on function public.dashboard_seating_plan(text), public.dashboard_save_table(text, text, integer, bigint),
  public.dashboard_move_table(text, bigint, integer, integer), public.dashboard_archive_table(text, bigint, boolean),
  public.dashboard_assign_seat(text, text, bigint, integer) from public;
grant execute on function public.dashboard_seating_plan(text), public.dashboard_save_table(text, text, integer, bigint),
  public.dashboard_move_table(text, bigint, integer, integer), public.dashboard_archive_table(text, bigint, boolean),
  public.dashboard_assign_seat(text, text, bigint, integer) to anon, authenticated;
