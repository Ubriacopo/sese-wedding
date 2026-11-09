-- Table positions are world coordinates on an expandable canvas, including negatives.
alter table public.seating_tables
  drop constraint seating_tables_x_check,
  drop constraint seating_tables_y_check;
