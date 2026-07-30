import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:statusxp/config/app_links.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/referral_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class InviteFriendsScreen extends ConsumerStatefulWidget {
  const InviteFriendsScreen({this.source = 'direct', super.key});

  final String source;

  @override
  ConsumerState<InviteFriendsScreen> createState() =>
      _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends ConsumerState<InviteFriendsScreen> {
  final _codeController = TextEditingController();
  late Future<ReferralSummary> _summary;
  bool _redeeming = false;

  ReferralService get _service =>
      ReferralService(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _summary = _service.getSummary();
    AnalyticsService().logCustomEvent(
      eventName: 'referral_screen_viewed',
      parameters: {'source': widget.source},
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _summary = _service.getSummary());

  Future<void> _share(String code) async {
    AnalyticsService().logCustomEvent(
      eventName: 'referral_invite_shared',
      parameters: {'source': widget.source},
    );
    await Share.share(
      'Join me on StatusXP and turn your achievements into one gaming identity. '
      'Use referral code $code before your first sync and we both get 10 AI guides: '
      '${AppLinks.playStoreUrl}',
    );
  }

  Future<void> _redeem() async {
    if (_redeeming || _codeController.text.trim().isEmpty) return;
    setState(() => _redeeming = true);
    try {
      await _service.redeem(_codeController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Code accepted! Complete your first sync to reward both players.',
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('PostgrestException(message: ', '')
          .split(',')
          .first;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(title: const Text('INVITE & EARN')),
      body: FutureBuilder<ReferralSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: FilledButton(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            );
          }
          final summary = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.group_add,
                color: CyberpunkTheme.neonCyan,
                size: 62,
              ),
              const SizedBox(height: 14),
              const Text(
                'Give 10 AI guides. Get 10 AI guides.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your friend enters your code before their first sync. When that sync completes, both accounts receive 10 AI credits.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 24),
              Card(
                color: const Color(0xFF0A0E27),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR CODE',
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.code,
                        style: const TextStyle(
                          color: CyberpunkTheme.neonCyan,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: summary.code),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied')),
                                );
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('COPY'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _share(summary.code),
                              icon: const Icon(Icons.share),
                              label: const Text('INVITE'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${summary.rewarded}',
                      label: 'Friends activated',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      value: '${summary.creditsEarned}',
                      label: 'Credits earned',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (summary.redeemedCode == null) ...[
                const Text(
                  'HAVE A FRIEND\'S CODE?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    hintText: 'ENTER CODE',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _redeeming ? null : _redeem,
                  child: Text(_redeeming ? 'CHECKING…' : 'REDEEM CODE'),
                ),
              ] else
                const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.greenAccent),
                  title: Text(
                    'Referral code activated',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Complete your first sync to unlock both rewards.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0E27),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    ),
  );
}
