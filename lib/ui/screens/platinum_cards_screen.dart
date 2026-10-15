import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:statusxp/domain/platinum_card.dart';
import 'package:statusxp/state/platinum_card_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/platinum_share_card.dart';
import 'package:statusxp/utils/save_share_image.dart';

class PlatinumCardsScreen extends ConsumerStatefulWidget {
  const PlatinumCardsScreen({super.key, this.initialItems = const []});
  final List<PlatinumCardData> initialItems;
  @override
  ConsumerState<PlatinumCardsScreen> createState() =>
      _PlatinumCardsScreenState();
}

class _PlatinumCardsScreenState extends ConsumerState<PlatinumCardsScreen> {
  final List<PlatinumCardData> _more = [];
  final Set<String> _selected = {};
  bool _loading = false, _hasMore = true;
  @override
  void initState() {
    super.initState();
    if (widget.initialItems.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(widget.initialItems);
      });
    }
  }

  void _open(List<PlatinumCardData> items) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlatinumCardEditor(items: items)),
  );
  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(platinumCardsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platinum celebrations'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(platinumCardsProvider),
            child: const Text('Retry loading platinums'),
          ),
        ),
        data: (first) {
          final merged = {
            for (final item in [...first, ..._more, ...widget.initialItems])
              item.key: item,
          };
          final items = merged.values.toList()
            ..sort((a, b) => b.number.compareTo(a.number));
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Your earned platinums will appear here after syncing.',
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _selected.isEmpty
                          ? 'Celebrate any platinum. Select up to four for a collection card.'
                          : '${_selected.length} selected',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => _open(
                        items.where((x) => _selected.contains(x.key)).toList(),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        _selected.length == 1
                            ? 'Create share card'
                            : 'Create collection card',
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: first.length == 40 && _hasMore
                                ? OutlinedButton(
                                    onPressed: _loading
                                        ? null
                                        : () async {
                                            setState(() => _loading = true);
                                            try {
                                              final page = await ref
                                                  .read(
                                                    platinumCardRepositoryProvider,
                                                  )
                                                  .list(
                                                    offset:
                                                        first.length +
                                                        _more.length,
                                                  );
                                              if (mounted) {
                                                setState(() {
                                                  _more.addAll(page);
                                                  _hasMore = page.length == 40;
                                                });
                                              }
                                            } catch (_) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Could not load more platinums. Try again.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _loading = false,
                                                );
                                              }
                                            }
                                          },
                                    child: Text(
                                      _loading ? 'Loading…' : 'Load more',
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          );
                        }
                        final item = items[index];
                        return ListTile(
                          leading: Checkbox(
                            value: _selected.contains(item.key),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  if (_selected.length < 4) {
                                    _selected.add(item.key);
                                  }
                                } else {
                                  _selected.remove(item.key);
                                }
                              });
                            },
                          ),
                          title: Text(item.gameName),
                          subtitle: Text(
                            'Platinum #${item.number} · ${item.platform}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Create share card',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () => _open([item]),
                          ),
                          onTap: () => _open([item]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PlatinumCardEditor extends ConsumerStatefulWidget {
  const PlatinumCardEditor({super.key, required this.items});
  final List<PlatinumCardData> items;
  @override
  ConsumerState<PlatinumCardEditor> createState() => _PlatinumCardEditorState();
}

class _PlatinumCardEditorState extends ConsumerState<PlatinumCardEditor> {
  final _capture = ScreenshotController();
  final _quote = TextEditingController();
  Uint8List? _custom, _ai;
  String _source = 'cover', _style = 'cinematic';
  bool _rarity = true, _notable = true, _busy = false, _generating = false;
  double _x = 0, _y = 0, _zoom = 1;
  String? _requestId;
  @override
  void dispose() {
    _quote.dispose();
    super.dispose();
  }

  ImageProvider? get _background => _source == 'screenshot' && _custom != null
      ? MemoryImage(_custom!)
      : _source == 'ai' && _ai != null
      ? MemoryImage(_ai!)
      : widget.items.first.coverUrl != null
      ? NetworkImage(widget.items.first.coverUrl!)
      : null;
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      if (file == null) return;
      if (await file.length() > 15 * 1024 * 1024) {
        _message('Choose an image smaller than 15 MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await precacheImage(MemoryImage(bytes), context);
      if (mounted) {
        setState(() {
          _custom = bytes;
          _source = 'screenshot';
          _x = 0;
          _y = 0;
          _zoom = 1;
        });
      }
    } catch (_) {
      _message('That image could not be opened. Try another screenshot.');
    }
  }

  String _uuid() {
    final b = List.generate(16, (_) => Random.secure().nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _generate() async {
    if (_generating) return;
    final user = ref.read(currentUserIdProvider);
    setState(() => _generating = true);
    try {
      if (!await ref.read(platinumPremiumProvider.future)) {
        if (mounted) context.push('/premium-subscription?source=platinum_art');
        return;
      }
      _requestId ??= _uuid();
      final game = widget.items.first.ref.gameRef;
      final response = await ref
          .read(supabaseClientProvider)
          .functions
          .invoke(
            'generate-platinum-art',
            body: {
              'requestId': _requestId,
              'platformId': game.platformId,
              'gameId': game.platformGameId,
              'style': _style,
            },
          );
      if (response.status != 200) throw StateError('not-ready');
      final data = Map<String, dynamic>.from(response.data as Map);
      // Private storage downloads use the current session; never a public bucket.
      final bytes = await ref
          .read(supabaseClientProvider)
          .storage
          .from('platinum-art')
          .download(data['objectPath'] as String);
      if (!mounted || ref.read(currentUserIdProvider) != user) return;
      await precacheImage(MemoryImage(bytes), context);
      if (mounted) {
        setState(() {
          _ai = bytes;
          _source = 'ai';
          _x = 0;
          _y = 0;
          _zoom = 1;
          _requestId = null;
        });
      }
    } catch (error) {
      // Preserve the request ID on uncertain network failures so a retry cannot bill twice.
      final details = error is FunctionException ? error.details : null;
      final code = details is Map ? details['code'] : null;
      if (code == 'premium_required') {
        ref.invalidate(platinumPremiumProvider);
        _message('AI artwork requires active Premium.');
      } else if (code == 'limit_reached') {
        _message(
          'The AI artwork limit has been reached. Please try again later.',
        );
      } else if (code == 'abandoned') {
        _requestId = null;
        _message('That generation took too long. Try a new background.');
      } else if (code == 'failed') {
        _requestId = null;
        _message(
          'Artwork could not be generated. Try again; failed requests do not use your allowance.',
        );
      } else {
        _message('Artwork is not ready yet. Retry to check this same request.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _export({required bool save}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = _background;
      await Future.wait([
        precacheImage(const AssetImage('assets/images/app_icon.png'), context),
        precacheImage(
          const AssetImage('assets/images/platinum_trophy.png'),
          context,
        ),
        for (final item in widget.items) ...[
          if (item.avatarUrl != null)
            precacheImage(
              NetworkImage(item.avatarUrl!),
              context,
              onError: (_, _) {},
            ),
          if (widget.items.length > 1 && item.coverUrl != null)
            precacheImage(
              NetworkImage(item.coverUrl!),
              context,
              onError: (_, _) {},
            ),
          if (_notable)
            for (final trophy in item.notable.take(3))
              if (trophy.iconUrl != null)
                precacheImage(
                  NetworkImage(trophy.iconUrl!),
                  context,
                  onError: (_, _) {},
                ),
        ],
      ]);
      if (!mounted) return;
      if (image != null) {
        var failed = false;
        await precacheImage(image, context, onError: (_, _) => failed = true);
        if (failed) throw StateError('background');
      }
      if (!mounted) return;
      final bytes = await _capture.capture(
        pixelRatio: 1.5,
        delay: const Duration(milliseconds: 150),
      );
      if (bytes == null) throw StateError('capture');
      final name = widget.items.length > 1
          ? 'statusxp-platinum-collection.png'
          : 'statusxp-platinum-${widget.items.first.number}.png';
      if (save && await saveShareImage(bytes, name)) return;
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
        fileNameOverrides: [name],
        text:
            '${widget.items.length == 1 ? widget.items.first.gameName : 'My platinum collection'} • StatusXP https://statusxp.com',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      _message(
        'Could not export the card. Check that its images loaded and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(platinumPremiumProvider).asData?.value == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Make it yours')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final w = min(c.maxWidth, 480.0);
                    return SizedBox(
                      width: w,
                      height:
                          w *
                          PlatinumShareCard.height /
                          PlatinumShareCard.width,
                      child: FittedBox(
                        child: Screenshot(
                          controller: _capture,
                          child: PlatinumShareCard(
                            items: widget.items,
                            background: _background,
                            quote: _quote.text,
                            showRarity: _rarity,
                            showNotable: _notable,
                            alignment: Alignment(_x, _y),
                            zoom: _zoom,
                            showTrophy: _source != 'ai',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Game cover'),
                      selected: _source == 'cover',
                      onSelected: (_) => setState(() {
                        _source = 'cover';
                        _x = 0;
                        _y = 0;
                        _zoom = 1;
                      }),
                    ),
                    ActionChip(
                      label: const Text('My screenshot'),
                      avatar: const Icon(Icons.photo_outlined, size: 18),
                      onPressed: _pick,
                    ),
                    ActionChip(
                      label: Text(
                        premium ? 'AI artwork' : 'AI artwork · Premium',
                      ),
                      avatar: Icon(
                        premium ? Icons.auto_awesome : Icons.lock_outline,
                        size: 18,
                      ),
                      onPressed: _generating
                          ? null
                          : () => premium
                                ? _generate()
                                : context.push(
                                    '/premium-subscription?source=platinum_art',
                                  ),
                    ),
                    if (_ai != null)
                      ChoiceChip(
                        label: const Text('Use AI background'),
                        selected: _source == 'ai',
                        onSelected: (_) => setState(() => _source = 'ai'),
                      ),
                  ],
                ),
                if (premium) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _style,
                    decoration: const InputDecoration(
                      labelText: 'AI artwork style',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cinematic',
                        child: Text('Cinematic'),
                      ),
                      DropdownMenuItem(
                        value: 'painted',
                        child: Text('Painted legend'),
                      ),
                      DropdownMenuItem(
                        value: 'cosmic',
                        child: Text('Cosmic celebration'),
                      ),
                    ],
                    onChanged: _generating
                        ? null
                        : (value) => setState(() {
                            _style = value!;
                            _requestId = null;
                          }),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Premium includes 3 AI backgrounds per calendar month. Generate only when you choose.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (_generating)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Creating your background… This can take a minute.',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _quote,
                  maxLength: 120,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Your story (optional)',
                    hintText: 'Every death was worth it.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  title: const Text('Show platinum rarity'),
                  subtitle: const Text('PlayStation rarity, when available'),
                  value: _rarity,
                  onChanged: (v) => setState(() => _rarity = v),
                ),
                if (widget.items.length == 1)
                  SwitchListTile(
                    title: const Text('Show notable trophies'),
                    subtitle: const Text(
                      'Up to three of your rarest earned trophies in this game',
                    ),
                    value: _notable,
                    onChanged: (v) => setState(() => _notable = v),
                  ),
                ExpansionTile(
                  title: const Text('Adjust background framing'),
                  children: [
                    const Text('Horizontal position'),
                    Slider(
                      value: _x,
                      min: -1,
                      max: 1,
                      onChanged: (v) => setState(() => _x = v),
                    ),
                    const Text('Vertical position'),
                    Slider(
                      value: _y,
                      min: -1,
                      max: 1,
                      onChanged: (v) => setState(() => _y = v),
                    ),
                    const Text('Zoom'),
                    Slider(
                      value: _zoom,
                      min: 1,
                      max: 2.5,
                      onChanged: (v) => setState(() => _zoom = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || _generating
                          ? null
                          : () => _export(save: false),
                      icon: const Icon(Icons.ios_share),
                      label: Text(_busy ? 'Preparing…' : 'Share card'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || _generating
                          ? null
                          : () => _export(save: true),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save image'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
