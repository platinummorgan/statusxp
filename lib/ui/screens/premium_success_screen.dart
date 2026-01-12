import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/theme/colors.dart';

/// Premium Subscription Success Screen
/// 
/// Shown after successful Stripe payment
class PremiumSuccessScreen extends StatelessWidget {
  const PremiumSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentPrimary.withOpacity(0.3),
                      accentSecondary.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: accentSuccess,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to Premium! 🎉',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your subscription is now active.\nEnjoy unlimited AI guides and all premium features!',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentPrimary,
                    foregroundColor: backgroundDark,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Exploring',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
