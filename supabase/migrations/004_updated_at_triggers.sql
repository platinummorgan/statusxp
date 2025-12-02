-- Migration: 004_updated_at_triggers.sql
-- Created: 2025-12-02
-- Description: Automatic updated_at timestamp triggers

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_profiles_updated_at
  before update on profiles
  for each row
  execute function update_updated_at_column();

create trigger update_game_titles_updated_at
  before update on game_titles
  for each row
  execute function update_updated_at_column();

create trigger update_trophies_updated_at
  before update on trophies
  for each row
  execute function update_updated_at_column();

create trigger update_user_games_updated_at
  before update on user_games
  for each row
  execute function update_updated_at_column();

create trigger update_user_stats_updated_at
  before update on user_stats
  for each row
  execute function update_updated_at_column();

create trigger update_user_profile_settings_updated_at
  before update on user_profile_settings
  for each row
  execute function update_updated_at_column();

create trigger update_trophy_room_shelves_updated_at
  before update on trophy_room_shelves
  for each row
  execute function update_updated_at_column();

create trigger update_trophy_room_items_updated_at
  before update on trophy_room_items
  for each row
  execute function update_updated_at_column();
