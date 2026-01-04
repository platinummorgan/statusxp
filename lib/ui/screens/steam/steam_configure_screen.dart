import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen for configuring Steam credentials
class SteamConfigureScreen extends StatefulWidget {
  const SteamConfigureScreen({super.key});

  @override
  State<SteamConfigureScreen> createState() => _SteamConfigureScreenState();
}

class _SteamConfigureScreenState extends State<SteamConfigureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _steamIdController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _steamIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final steamId = _steamIdController.text.trim();
      
      // Check if this Steam ID is already linked to a different account
      final existingProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('steam_id', steamId)
          .maybeSingle();
      
      if (existingProfile != null && existingProfile['id'] != userId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This Steam account (Steam ID: $steamId) is already connected to another account. If this is your account, please contact support for assistance.'
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      await supabase.from('profiles').update({
        'steam_id': steamId,
        'steam_api_key': _apiKeyController.text.trim(),
      }).eq('id', userId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Steam credentials saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save credentials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Steam'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(
                Icons.cloud,
                size: 64,
                color: Color(0xFF66C0F4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect Your Steam Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your Steam credentials to sync your achievements',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Steam ID Field
              TextFormField(
                controller: _steamIdController,
                decoration: const InputDecoration(
                  labelText: 'Steam ID',
                  hintText: '76561198025758586',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  helperText: 'Your 17-digit Steam ID',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Steam ID';
                  }
                  if (value.length != 17) {
                    return 'Steam ID must be 17 digits';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // API Key Field
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Steam Web API Key',
                  hintText: 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(),
                  helperText: 'Your Steam Web API key',
                ),
                maxLength: 32,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your API key';
                  }
                  if (value.length != 32) {
                    return 'API key must be 32 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCredentials,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save Credentials',
                        style: TextStyle(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 32),

              // Privacy Warning Card
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.privacy_tip, color: Colors.orange, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Privacy Settings Required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your Steam profile must be set to PUBLIC during sync or you\'ll get errors. Go to Profile → Edit Profile → Privacy Settings and set "Game details" to Public. You can change it back to Private after sync completes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instructions Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'How to get your credentials',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '1. Get your Steam ID',
                        '• Go to your Steam profile\n'
                        '• Look at the URL: steamcommunity.com/profiles/[YOUR_ID]\n'
                        '• Copy the 17-digit number',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '2. Get your API Key',
                        '• Visit: steamcommunity.com/dev/apikey\n'
                        '• For "Domain Name", enter anything (e.g., "StatusXP")\n'
                        '• This is just a label - it doesn\'t matter what you enter\n'
                        '• Register and copy the 32-character key',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Note: You need Steam Guard Mobile Authenticator enabled to get an API key.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
