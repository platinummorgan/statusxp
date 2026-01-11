import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/config/app_links.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public landing page for statusxp.com
/// 
/// Features:
/// - Hero section with branding
/// - Feature showcase
/// - Platform integrations
/// - App store download links
/// - Web app launch button
class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E27),
              backgroundDark,
              Color(0xFF1a1f3a),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header/Nav
              _buildHeader(context),
              
              // Hero Section
              _buildHeroSection(context, isWideScreen),
              
              const SizedBox(height: 80),
              
              // Features Section
              _buildFeaturesSection(context, isWideScreen),
              
              const SizedBox(height: 80),
              
              // Platform Section
              _buildPlatformSection(context, isWideScreen),
              
              const SizedBox(height: 80),
              
              // CTA Section
              _buildCTASection(context, isWideScreen),
              
              const SizedBox(height: 60),
              
              // Footer
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentPrimary.withOpacity(0.2),
                      accentSecondary.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videogame_asset_rounded,
                  color: accentPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'StatusXP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          
          // Sign In Button
          TextButton(
            onPressed: () => context.go('/'),
            style: TextButton.styleFrom(
              foregroundColor: accentPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Launch App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isWideScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 80 : 24,
        vertical: isWideScreen ? 100 : 60,
      ),
      child: Column(
        children: [
          // Main headline
          Text(
            'Your Gaming Identity,\nLeveled Up',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWideScreen ? 56 : 36,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Subheadline
          Text(
            'Track achievements across PlayStation, Xbox, and Steam.\nShowcase your gaming journey in one unified profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isWideScreen ? 20 : 16,
              color: textSecondary,
              height: 1.6,
            ),
          ),
          
          const SizedBox(height: 48),
          
          // CTA Buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPrimary,
                  foregroundColor: backgroundDark,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideScreen ? 32 : 24,
                    vertical: isWideScreen ? 20 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.rocket_launch, size: 24),
                label: Text(
                  'Launch Web App',
                  style: TextStyle(
                    fontSize: isWideScreen ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              OutlinedButton.icon(
                onPressed: () => _scrollToDownloads(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: const BorderSide(color: accentPrimary, width: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideScreen ? 32 : 24,
                    vertical: isWideScreen ? 20 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.download, size: 24),
                label: Text(
                  'Download Apps',
                  style: TextStyle(
                    fontSize: isWideScreen ? 18 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 60),
          
          // Platform Badges
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildPlatformBadge(Icons.smart_display, 'PlayStation'),
              _buildPlatformBadge(Icons.sports_esports, 'Xbox'),
              _buildPlatformBadge(Icons.computer, 'Steam'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: accentPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentPrimary, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isWideScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 80 : 24,
      ),
      child: Column(
        children: [
          Text(
            'Everything You Need',
            style: TextStyle(
              fontSize: isWideScreen ? 42 : 32,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'A complete achievement tracking platform',
            style: TextStyle(
              fontSize: isWideScreen ? 18 : 16,
              color: textSecondary,
            ),
          ),
          
          const SizedBox(height: 60),
          
          // Features Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = isWideScreen ? 3 : 1;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeatureCard(
                    context,
                    Icons.sync,
                    'Cross-Platform Sync',
                    'Automatically sync your achievements from PlayStation, Xbox, and Steam in one place.',
                    accentPrimary,
                    isWideScreen ? 350 : double.infinity,
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.leaderboard,
                    'Global Leaderboards',
                    'Compete with gamers worldwide. See how you rank based on your StatusXP score.',
                    accentSecondary,
                    isWideScreen ? 350 : double.infinity,
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.emoji_events,
                    'Flex Room',
                    'Showcase your rarest achievements and biggest gaming accomplishments.',
                    accentWarning,
                    isWideScreen ? 350 : double.infinity,
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.share,
                    'Status Posters',
                    'Create beautiful shareable cards to show off your gaming progress.',
                    accentSuccess,
                    isWideScreen ? 350 : double.infinity,
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.analytics,
                    'Detailed Stats',
                    'Track your completion rates, rarity scores, and gaming patterns over time.',
                    const Color(0xFF00D9FF),
                    isWideScreen ? 350 : double.infinity,
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.notifications_active,
                    'Smart Tracking',
                    'Get notified when new achievements are available for your games.',
                    const Color(0xFFFF10F0),
                    isWideScreen ? 350 : double.infinity,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color accentColor,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surfaceLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.2),
                  accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 32,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSection(BuildContext context, bool isWideScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 80 : 24,
      ),
      child: Column(
        children: [
          Text(
            'One Platform, Three Ecosystems',
            style: TextStyle(
              fontSize: isWideScreen ? 42 : 32,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 60),
          
          // Platform Cards
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildPlatformCard(
                'PlayStation Network',
                'Sync your PlayStation trophies automatically',
                Icons.smart_display,
                const Color(0xFF0070CC),
                isWideScreen ? 350 : double.infinity,
              ),
              _buildPlatformCard(
                'Xbox Live',
                'Track your Xbox achievements seamlessly',
                Icons.sports_esports,
                const Color(0xFF107C10),
                isWideScreen ? 350 : double.infinity,
              ),
              _buildPlatformCard(
                'Steam',
                'Import your Steam achievements instantly',
                Icons.computer,
                const Color(0xFF1B2838),
                isWideScreen ? 350 : double.infinity,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(
    String title,
    String description,
    IconData icon,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 64),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context, bool isWideScreen) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 80 : 24,
      ),
      padding: EdgeInsets.all(isWideScreen ? 60 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentPrimary.withOpacity(0.2),
            accentSecondary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentPrimary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Level Up?',
            style: TextStyle(
              fontSize: isWideScreen ? 42 : 32,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Join gamers worldwide tracking their achievements',
            style: TextStyle(
              fontSize: isWideScreen ? 18 : 16,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Download Buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStoreButton(
                'Download on the\nApp Store',
                Icons.apple,
                () => _launchURL(AppLinks.appStoreUrl),
                isWideScreen,
              ),
              _buildStoreButton(
                'Get it on\nGoogle Play',
                Icons.shop,
                () => _launchURL(AppLinks.playStoreUrl),
                isWideScreen,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Or use the web version',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => context.go('/'),
            style: TextButton.styleFrom(
              foregroundColor: accentPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Launch Web App',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
    bool isWideScreen,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isWideScreen ? 200 : 160,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: textPrimary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textPrimary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: textSecondary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Launch App'),
              ),
              TextButton(
                onPressed: () => _launchURL(AppLinks.privacyPolicyUrl),
                child: const Text('Privacy Policy'),
              ),
              TextButton(
                onPressed: () => _launchURL(AppLinks.termsOfServiceUrl),
                child: const Text('Terms of Service'),
              ),
              TextButton(
                onPressed: () => _launchURL('mailto:${AppLinks.supportEmail}'),
                child: const Text('Support'),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            '© ${DateTime.now().year} StatusXP. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToDownloads() {
    // TODO: Implement smooth scroll to downloads section
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
