import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for displaying markdown documents (Privacy Policy, Terms of Service, etc.)
class MarkdownViewerScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const MarkdownViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<MarkdownViewerScreen> createState() => _MarkdownViewerScreenState();
}

class _MarkdownViewerScreenState extends State<MarkdownViewerScreen> {
  String _markdownContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      setState(() {
        _markdownContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _markdownContent = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceLight,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accentPrimary),
            )
          : Markdown(
              data: _markdownContent,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.6,
                ),
                h1: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                h2: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                h3: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: const TextStyle(
                  color: accentPrimary,
                  fontSize: 14,
                ),
                a: const TextStyle(
                  color: accentPrimary,
                  decoration: TextDecoration.underline,
                ),
                code: TextStyle(
                  backgroundColor: surfaceLight,
                  color: accentPrimary,
                  fontFamily: 'monospace',
                ),
                blockquote: TextStyle(
                  color: textSecondary,
                  fontStyle: FontStyle.italic,
                  backgroundColor: surfaceLight,
                ),
              ),
              onTapLink: (text, href, title) async {
                if (href != null) {
                  final uri = Uri.parse(href);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
    );
  }
}
