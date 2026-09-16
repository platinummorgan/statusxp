import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/premium_access.dart';

Future<String?> premiumAccessIssue(SupabaseClient client) async {
  if (client.auth.currentUser == null) {
    return 'Please sign in to check your membership.';
  }
  try {
    final entitlement = await readPremiumEntitlement(client);
    if (hasActivePremium(entitlement)) return null;
    if (entitlement == null) {
      return 'No membership record was returned for this account.';
    }
    final expiry = DateTime.tryParse(
      entitlement['premium_expires_at']?.toString() ?? '',
    );
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      return 'The membership record for this account expired on ${expiry.toLocal().toString().split(' ').first}. If you renewed, your membership record may need updating.';
    }
    return 'The membership service reports that this account is not currently premium.';
  } on PostgrestException catch (error) {
    return 'We could not verify your membership (code: ${error.code ?? 'unknown'}). Please retry.';
  } catch (_) {
    return 'We could not reach the membership service. Please retry.';
  }
}

class PremiumAccessIssueScreen extends StatelessWidget {
  const PremiumAccessIssueScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Premium access')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.manage_accounts_outlined, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Check again'),
              ),
              TextButton(
                onPressed: () => context.push('/premium-subscription'),
                child: const Text('View membership'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
