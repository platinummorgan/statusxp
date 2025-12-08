const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function runMigration() {
  try {
    console.log('Running database migration...');

    const sql = fs.readFileSync('../RUN_IN_SUPABASE_SQL_EDITOR.sql', 'utf8');

    // Execute the entire SQL as one statement
    console.log('Executing migration SQL...');

    // Note: This won't work with Supabase client. We need to run this in the Supabase dashboard
    console.log('Please run the following SQL in your Supabase SQL Editor:');
    console.log('='.repeat(50));
    console.log(sql);
    console.log('='.repeat(50));

  } catch (error) {
    console.error('Migration script failed:', error);
  }
}

runMigration();