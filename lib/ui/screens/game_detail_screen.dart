import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

/// Game Detail Screen - Edit existing game data
/// 
/// Allows editing of game properties and saves changes to local JSON.
/// After saving, triggers refresh of all provider data.
class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.game});

  final Game game;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _earnedTrophiesController;
  late TextEditingController _totalTrophiesController;
  late TextEditingController _rarityController;
  late String _selectedPlatform;
  late bool _hasPlatinum;

  final List<String> _platformOptions = [
    'PS4',
    'PS5',
    'Xbox',
    'Steam',
    'Switch',
    'PC',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.game.name);
    _earnedTrophiesController = TextEditingController(
      text: widget.game.earnedTrophies.toString(),
    );
    _totalTrophiesController = TextEditingController(
      text: widget.game.totalTrophies.toString(),
    );
    _rarityController = TextEditingController(
      text: widget.game.rarityPercent.toStringAsFixed(1),
    );
    _selectedPlatform = widget.game.platform;
    _hasPlatinum = widget.game.hasPlatinum;

    // Add platform to options if not already there
    if (!_platformOptions.contains(_selectedPlatform)) {
      _platformOptions.add(_selectedPlatform);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _earnedTrophiesController.dispose();
    _totalTrophiesController.dispose();
    _rarityController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      HapticFeedback.lightImpact();

      final updatedGame = widget.game.copyWith(
        name: _nameController.text.trim(),
        platform: _selectedPlatform,
        hasPlatinum: _hasPlatinum,
        earnedTrophies: int.parse(_earnedTrophiesController.text),
        totalTrophies: int.parse(_totalTrophiesController.text),
        rarityPercent: double.parse(_rarityController.text),
      );

      final service = ref.read(gameEditServiceProvider);
      
      if (service == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No authenticated user')),
        );
        return;
      }
      
      await service.updateGame(updatedGame);

      // Refresh all data
      ref.refreshCoreData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game updated successfully'),
          backgroundColor: accentPrimary,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.name),
        leading: BackButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Game Name',
                filled: true,
                fillColor: surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name cannot be empty';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Platform dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: InputDecoration(
                labelText: 'Platform',
                filled: true,
                fillColor: surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _platformOptions.map((platform) {
                return DropdownMenuItem(
                  value: platform,
                  child: Text(platform),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPlatform = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Platinum switch
            SwitchListTile(
              title: const Text('Has Platinum Trophy'),
              value: _hasPlatinum,
              activeThumbColor: accentPrimary,
              tileColor: surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onChanged: (value) {
                setState(() {
                  _hasPlatinum = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Trophy counts
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _earnedTrophiesController,
                    decoration: InputDecoration(
                      labelText: 'Earned Trophies',
                      filled: true,
                      fillColor: surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final earned = int.tryParse(value);
                      if (earned == null) {
                        return 'Invalid number';
                      }
                      final total = int.tryParse(_totalTrophiesController.text);
                      if (total != null && earned > total) {
                        return 'Cannot exceed total';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _totalTrophiesController,
                    decoration: InputDecoration(
                      labelText: 'Total Trophies',
                      filled: true,
                      fillColor: surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final total = int.tryParse(value);
                      if (total == null || total <= 0) {
                        return 'Must be > 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Rarity percentage
            TextFormField(
              controller: _rarityController,
              decoration: InputDecoration(
                labelText: 'Rarity Percentage',
                suffixText: '%',
                filled: true,
                fillColor: surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final rarity = double.tryParse(value);
                if (rarity == null || rarity < 0 || rarity > 100) {
                  return 'Must be 0-100';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPrimary,
                  foregroundColor: surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: accentPrimary.withValues(alpha: 0.3),
                ),
                child: Text(
                  'SAVE CHANGES',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: surfaceDark,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
