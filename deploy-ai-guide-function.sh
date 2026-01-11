# Deploy generate-achievement-guide Edge Function

## 1. Deploy the function to Supabase
supabase functions deploy generate-achievement-guide

## 2. Set the OpenAI API key as a secret
supabase secrets set OPENAI_API_KEY=your_openai_api_key_here

## 3. Verify the secret is set
supabase secrets list

## Note: Get your OpenAI API key from https://platform.openai.com/api-keys
