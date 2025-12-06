import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';
import 'package:statusxp/features/display_case/providers/display_case_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';

/// Shows a dialog to select a trophy to add to the display case
/// Returns true if a trophy was added successfully
Future<bool?> showTrophySelectorDialog(
  BuildContext context,
  int shelfNumber,
  int position,
) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => _TrophySelectorDialog(
      shelfNumber: shelfNumber,
      position: position,
    ),
  );
}

class _TrophySelectorDialog extends ConsumerStatefulWidget {
  final int shelfNumber;
  final int position;

  const _TrophySelectorDialog({
    required this.shelfNumber,
    required this.position,
  });

  @override
  ConsumerState<_TrophySelectorDialog> createState() => _TrophySelectorDialogState();
}

class _TrophySelectorDialogState extends ConsumerState<_TrophySelectorDialog> {
  DisplayItemType _selectedDisplayType = DisplayItemType.trophyIcon;
  int? _selectedGameId;
  String? _selectedGameName;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(displayCaseThemeProvider);
    final userId = ref.watch(currentUserIdProvider);
    final repository = ref.watch(displayCaseRepositoryProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.primaryAccent.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryAccent.withOpacity(0.3),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Back button (if game selected)
                  if (_selectedGameId != null)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedGameId = null;
                          _selectedGameName = null;
                        });
                      },
                      icon: Icon(Icons.arrow_back, color: theme.textColor),
                    ),
                  Expanded(
                    child: Text(
                      _selectedGameId == null ? 'SELECT GAME' : _selectedGameName?.toUpperCase() ?? 'SELECT TROPHY',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: theme.textGlow(color: theme.primaryAccent),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.textColor),
                  ),
                ],
              ),
            ),

            // Display type toggle (only show when game selected)
            if (_selectedGameId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'DISPLAY AS:',
                      style: TextStyle(
                        color: theme.textColor.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildDisplayTypeButton(
                      'ICON',
                      DisplayItemType.trophyIcon,
                      Icons.emoji_events,
                      theme,
                    ),
                    const SizedBox(width: 8),
                    _buildDisplayTypeButton(
                      'COVER',
                      DisplayItemType.gameCover,
                      Icons.image,
                      theme,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Game list or Trophy list
            Expanded(
              child: _selectedGameId == null
                  ? _buildGameList(userId!, theme)
                  : _buildTrophyList(userId!, _selectedGameId!, repository, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameList(String userId, DisplayCaseTheme theme) {
    final repository = ref.read(displayCaseRepositoryProvider);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repository.getAvailableTrophies(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.primaryAccent),
          );
        }

        final trophies = snapshot.data ?? [];
        
        // Group trophies by game name
        final gameMap = <String, Map<String, dynamic>>{};
        for (final trophy in trophies) {
          final gameName = trophy['game_name'] as String? ?? 'Unknown';
          final gameImage = trophy['game_image_url'] as String?;
          
          if (!gameMap.containsKey(gameName)) {
            gameMap[gameName] = {
              'game_name': gameName,
              'game_image_url': gameImage,
              'trophy_count': 0,
            };
          }
          gameMap[gameName]!['trophy_count'] = (gameMap[gameName]!['trophy_count'] as int) + 1;
        }

        final games = gameMap.values.toList();
        games.sort((a, b) => (b['trophy_count'] as int).compareTo(a['trophy_count'] as int));

        if (games.isEmpty) {
          return Center(
            child: Text(
              'NO GAMES WITH TROPHIES',
              style: TextStyle(
                color: theme.textColor.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return _buildGameCard(game, theme);
          },
        );
      },
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game, DisplayCaseTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryAccent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedGameId = 1; // Dummy ID since we're using game name
            _selectedGameName = game['game_name'] as String;
          });
        },
        leading: game['game_image_url'] != null
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primaryAccent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    game['game_image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.videogame_asset,
                      color: theme.primaryAccent,
                    ),
                  ),
                ),
              )
            : Icon(Icons.videogame_asset, color: theme.primaryAccent, size: 32),
        title: Text(
          game['game_name'],
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${game['trophy_count']} trophies earned',
          style: TextStyle(
            color: theme.textColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: theme.primaryAccent,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildTrophyList(String userId, int gameId, dynamic repository, DisplayCaseTheme theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repository.getAvailableTrophies(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.primaryAccent),
          );
        }

        final allTrophies = snapshot.data ?? [];
        final trophies = allTrophies.where((t) => 
          t['game_name'] == _selectedGameName
        ).toList();

        if (trophies.isEmpty) {
          return Center(
            child: Text(
              'NO TROPHIES FOR THIS GAME',
              style: TextStyle(
                color: theme.textColor.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: trophies.length,
          itemBuilder: (context, index) {
            final trophy = trophies[index];
            return _buildTrophyCard(trophy, theme);
          },
        );
      },
    );
  }

  Widget _buildDisplayTypeButton(
    String label,
    DisplayItemType type,
    IconData icon,
    DisplayCaseTheme theme,
  ) {
    final isSelected = _selectedDisplayType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDisplayType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryAccent.withOpacity(0.3)
              : theme.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.primaryAccent : theme.textColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primaryAccent : theme.textColor.withOpacity(0.7),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.primaryAccent : theme.textColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyCard(Map<String, dynamic> trophy, DisplayCaseTheme theme) {
    final tier = trophy['tier'] as String;
    final tierColor = theme.getTierColor(tier);
    final repository = ref.read(displayCaseRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tierColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: () async {
          // Add trophy to display case at specified position
          final success = await repository.addItem(
            userId: userId!,
            trophyId: trophy['trophy_id'] as int,
            displayType: _selectedDisplayType,
            shelfNumber: widget.shelfNumber,
            positionInShelf: widget.position,
          );

          if (!mounted) return;

          Navigator.pop(context, success != null); // Return success status

          if (success != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${trophy['trophy_name']} to display!'),
                backgroundColor: theme.primaryAccent,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to add trophy. Position may be occupied.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        leading: trophy['icon_url'] != null
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tierColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    trophy['icon_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.emoji_events,
                      color: tierColor,
                    ),
                  ),
                ),
              )
            : Icon(Icons.emoji_events, color: tierColor, size: 32),
        title: Text(
          trophy['trophy_name'],
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          trophy['game_name'],
          style: TextStyle(
            color: theme.textColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tierColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tierColor, width: 1),
          ),
          child: Text(
            tier.toUpperCase(),
            style: TextStyle(
              color: tierColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
