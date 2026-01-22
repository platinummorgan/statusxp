import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/theme/colors.dart';

/// Provider for fetching app updates
final appUpdatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    
    final response = await supabase
        .from('app_updates')
        .select('id, title, description, release_date, version')
        .order('release_date', ascending: false);
    
    return List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    print('Error fetching app updates: $e');
    return [];
  }
});

/// Updates Screen - Display changelog/updates from database
class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(appUpdatesProvider);

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Updates',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: updatesAsync.when(
        data: (updates) {
          if (updates.isEmpty) {
            return const Center(
              child: Text(
                'No updates available',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // Group updates by date
          final groupedUpdates = <String, List<Map<String, dynamic>>>{};
          for (final update in updates) {
            final dateStr = update['release_date'] as String?;
            final DateTime? releaseDate = dateStr != null 
                ? DateTime.tryParse(dateStr) 
                : null;
            
            final dateKey = releaseDate != null
                ? DateFormat('MMMM d, yyyy').format(releaseDate)
                : 'Unknown date';
            
            if (!groupedUpdates.containsKey(dateKey)) {
              groupedUpdates[dateKey] = [];
            }
            groupedUpdates[dateKey]!.add(update);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groupedUpdates.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dateKey = groupedUpdates.keys.elementAt(index);
              final dateUpdates = groupedUpdates[dateKey]!;
              return _buildDateGroup(dateKey, dateUpdates);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(accentSecondary),
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load updates',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateGroup(String dateKey, List<Map<String, dynamic>> updates) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.white10,
          highlightColor: Colors.white.withOpacity(0.05),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: Row(
            children: [
              const Icon(Icons.calendar_today, color: accentSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dateKey,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${updates.length}',
                  style: const TextStyle(
                    color: accentSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white54,
          children: updates.map((update) => _buildUpdateItem(update)).toList(),
        ),
      ),
    );
  }

  Widget _buildUpdateItem(Map<String, dynamic> update) {
    final version = update['version'] as String?;
    final title = update['title'] as String? ?? 'Update';
    final description = update['description'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (version != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentSecondary, width: 1),
                  ),
                  child: Text(
                    'v$version',
                    style: const TextStyle(
                      color: accentSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
