import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/config/supabase_config.dart';
import 'package:statusxp/data/data_migration_service.dart';
import 'package:statusxp/theme/theme.dart';
import 'package:statusxp/ui/navigation/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Run first-time data migration if needed
  await _runInitialMigration();

  runApp(const ProviderScope(child: StatusXPApp()));
}

/// Run data migration on first app launch.
Future<void> _runInitialMigration() async {
  final client = Supabase.instance.client;
  final migrationService = DataMigrationService(client);
  
  // For demo purposes, we use a fixed demo user ID
  // In a real app, this would be the authenticated user's ID
  const demoUserId = 'demo-user-id';
  
  await migrationService.migrateInitialData(demoUserId);
}

class StatusXPApp extends StatelessWidget {
  const StatusXPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StatusXP',
      debugShowCheckedModeBanner: false,
      theme: statusXPTheme,
      routerConfig: appRouter,
    );
  }
}
