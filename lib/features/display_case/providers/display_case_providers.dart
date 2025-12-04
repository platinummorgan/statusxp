import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/features/display_case/repositories/display_case_repository.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';
import 'package:statusxp/features/display_case/themes/playstation_theme.dart';
import 'package:statusxp/state/statusxp_providers.dart';

/// Provider for the Display Case repository
final displayCaseRepositoryProvider = Provider<DisplayCaseRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DisplayCaseRepository(supabase);
});

/// Provider for the current display case theme
/// TODO: When settings are added, this should read from user preferences
final displayCaseThemeProvider = Provider<DisplayCaseTheme>((ref) {
  return PlayStationTheme(); // Default to PlayStation theme
});
