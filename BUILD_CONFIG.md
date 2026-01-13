# Build Configuration

## Environment Variables

This project requires environment variables for Supabase configuration. The values are passed via `--dart-define` flags during build.

### Required Variables

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous/public key

### Development Build

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key-here
```

### Release Build

```powershell
flutter build apk --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key-here
```

### Using .env file (optional)

1. Copy `.env.example` to `.env`
2. Fill in your actual values
3. Use a tool like `flutter_dotenv` or build scripts to pass these to `--dart-define`

**Note:** Never commit `.env` or any file containing actual credentials to version control.
