// Test icon proxy functionality
import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon } from './icon-proxy-utils.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function testIconProxy() {
  console.log('Testing icon proxy...');
  
  // Test with a PlayStation icon URL
  const testUrl = 'https://image.api.playstation.com/trophy/np/NPWR10600_00_0011DEAD1880AC5A22A7AF5C9B41E73ABDFB36C0B8/25D90F3E9C68AE29B6C1A9C1A9F651D5E0F35C00.PNG';
  const testId = 'test_trophy_123';
  
  console.log(`Attempting to proxy: ${testUrl}`);
  
  const result = await uploadExternalIcon(testUrl, testId, 'psn', supabase);
  
  if (result) {
    console.log('✅ SUCCESS! Proxied URL:', result);
  } else {
    console.log('❌ FAILED to proxy icon');
  }
}

testIconProxy().catch(console.error);
