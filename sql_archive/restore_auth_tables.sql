-- Recreate missing auth tables
-- WARNING: This is attempting to restore core Supabase auth infrastructure

-- Create auth.config table
CREATE TABLE IF NOT EXISTS auth.config (
    key text PRIMARY KEY,
    value text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create auth.providers table  
CREATE TABLE IF NOT EXISTS auth.providers (
    id text PRIMARY KEY,
    provider text NOT NULL,
    enabled boolean DEFAULT false,
    config jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Insert Google provider configuration
INSERT INTO auth.providers (id, provider, enabled, config) VALUES (
    'google',
    'google', 
    true,
    '{"client_id": "395832690159-fe24vs3m6udhe15ufm2m3jnn0k1pdrap.apps.googleusercontent.com"}'
) ON CONFLICT (id) DO UPDATE SET
    enabled = EXCLUDED.enabled,
    config = EXCLUDED.config;

-- Enable Google in auth config
INSERT INTO auth.config (key, value) VALUES 
    ('EXTERNAL_GOOGLE_ENABLED', 'true'),
    ('EXTERNAL_GOOGLE_CLIENT_ID', '395832690159-fe24vs3m6udhe15ufm2m3jnn0k1pdrap.apps.googleusercontent.com')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;