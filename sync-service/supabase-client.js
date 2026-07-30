import { createClient } from '@supabase/supabase-js';
import ws from 'ws';

// Supabase realtime-js requires a WebSocket constructor on Node < 22.
if (typeof globalThis.WebSocket === 'undefined') {
  globalThis.WebSocket = ws;
}

export function createServiceClient() {
  return createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    {
      realtime: { transport: ws },
    }
  );
}
