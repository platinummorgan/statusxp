import 'package:flutter/material.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/widgets/stat_card.dart';
import 'package:statusxp/ui/widgets/section_header.dart';

/// Theme Demo Screen
/// 
/// Demonstrates all theme components and widgets for v0.1.
/// This is a temporary demo screen to showcase the design system.
class ThemeDemoScreen extends StatelessWidget {
  const ThemeDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StatusXP Theme Demo'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Typography'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Display Large', style: theme.textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text('Display Medium', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text('Headline Large', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text('Headline Medium', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Title Large', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Title Medium', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Body Medium', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Body Small', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text('Label Small', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const SectionHeader(title: 'Stat Cards'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  StatCard(
                    title: 'TOTAL PLATINUMS',
                    value: '7',
                    accentColor: accentPrimary,
                  ),
                  const SizedBox(height: 12),
                  StatCard(
                    title: 'TOTAL TROPHIES',
                    value: '509',
                    subtitle: 'Across 12 games',
                    accentColor: accentSecondary,
                  ),
                  const SizedBox(height: 12),
                  const StatCard(
                    title: 'RAREST TROPHY',
                    value: '2.1%',
                    subtitle: 'Return to the Dream',
                    showGlow: false,
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Buttons'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Elevated Button'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Filled Button'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined Button'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Text Button'),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Colors'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ColorChip(color: accentPrimary, label: 'Primary'),
                  _ColorChip(color: accentSecondary, label: 'Secondary'),
                  _ColorChip(color: accentSuccess, label: 'Success'),
                  _ColorChip(color: accentWarning, label: 'Warning'),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: backgroundDark,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
