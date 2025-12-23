-- Migration: 003_rls_policies.sql
-- Created: 2025-12-02
-- Description: Row Level Security Policies

-- ============================================================================
-- PROFILES
-- ============================================================================
create policy "Users can read their own rows"
on profiles
for select
using (auth.uid() = id);

create policy "Users can modify their own rows"
on profiles
for all
using (auth.uid() = id)
with check (auth.uid() = id);

-- ============================================================================
-- USER GAMES
-- ============================================================================
create policy "Users can read their own rows"
on user_games
for select
using (auth.uid() = user_id);

create policy "Users can modify their own rows"
on user_games
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================================
-- USER TROPHIES
-- ============================================================================
create policy "Users can read their own rows"
on user_trophies
for select
using (auth.uid() = user_id);

create policy "Users can modify their own rows"
on user_trophies
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================================
-- USER STATS
-- ============================================================================
create policy "Users can read their own rows"
on user_stats
for select
using (auth.uid() = user_id);

create policy "Users can modify their own rows"
on user_stats
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================================
-- USER PROFILE SETTINGS
-- ============================================================================
create policy "Users can read their own rows"
on user_profile_settings
for select
using (auth.uid() = user_id);

create policy "Users can modify their own rows"
on user_profile_settings
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================================
-- TROPHY ROOM SHELVES
-- ============================================================================
create policy "Users can read their own rows"
on trophy_room_shelves
for select
using (auth.uid() = user_id);

create policy "Users can modify their own rows"
on trophy_room_shelves
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================================
-- TROPHY ROOM ITEMS
-- ============================================================================
create policy "Users can read their own rows"
on trophy_room_items
for select
using (auth.uid() = (select user_id from trophy_room_shelves where id = shelf_id));

create policy "Users can modify their own rows"
on trophy_room_items
for all
using (auth.uid() = (select user_id from trophy_room_shelves where id = shelf_id))
with check (auth.uid() = (select user_id from trophy_room_shelves where id = shelf_id));

-- ============================================================================
-- READ-ONLY CATALOG TABLES (Public Read, Service Role Write)
-- ============================================================================

-- PLATFORMS
create policy "Public read access"
on platforms
for select
using (true);

-- GAME TITLES
create policy "Public read access"
on game_titles
for select
using (true);

-- TROPHIES
create policy "Public read access"
on trophies
for select
using (true);

-- PROFILE THEMES
create policy "Public read access"
on profile_themes
for select
using (true);
