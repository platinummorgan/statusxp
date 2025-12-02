-- Migration: 002_enable_rls.sql
-- Created: 2025-12-02
-- Description: Enable Row Level Security

alter table profiles enable row level security;
alter table user_games enable row level security;
alter table user_trophies enable row level security;
alter table user_stats enable row level security;
alter table user_profile_settings enable row level security;
alter table trophy_room_shelves enable row level security;
alter table trophy_room_items enable row level security;
