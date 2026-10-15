import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/platinum_card.dart';
import 'package:statusxp/ui/widgets/platinum_share_card.dart';
import 'platinum_card_test.dart' show fixture;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await ui.loadFontFromList(
    File('assets/fonts/Cinzel.ttf').readAsBytesSync(),
    fontFamily: 'PlatinumDisplay',
  );
  await ui.loadFontFromList(
    File('assets/fonts/Cinzel.ttf').readAsBytesSync(),
    fontFamily: 'sans-serif',
  );
  for (final ai in [false, true]) {
    testWidgets('render ${ai ? 'AI' : 'cover'} export at 1080 pixels wide', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      final cover = File(
        ai
            ? 'output/platinum-preview/ai-background.png'
            : 'output/platinum-preview/game-cover.jpg',
      );
      final provider = cover.existsSync()
          ? MemoryImage(cover.readAsBytesSync())
          : null;
      await tester.pumpWidget(MaterialApp(home: SizedBox(key: key)));
      if (provider != null)
        await tester.runAsync(
          () => precacheImage(provider, key.currentContext!),
        );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/app_icon.png'),
          key.currentContext!,
        );
        await precacheImage(
          const AssetImage('assets/images/platinum_trophy.png'),
          key.currentContext!,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: PlatinumShareCard(
                  items: [
                    PlatinumCardData.fromJson({
                      ...fixture(rarity: 10.3),
                      'notable': [
                        {'name': 'Knight’s Honor', 'rarity': 2.8},
                        {'name': 'Wisdom of a Sage', 'rarity': 3.2},
                        {'name': 'Bond of a Pyromancer', 'rarity': 3.9},
                      ],
                    }),
                  ],
                  showTrophy: !ai,
                  background: provider,
                  quote: 'Every death was worth it.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File(
          ai
              ? 'output/platinum-preview/share-card-ai.png'
              : 'output/platinum-preview/share-card.png',
        );
        await out.parent.create(recursive: true);
        await out.writeAsBytes(data!.buffer.asUint8List());
        expect(image.width, 1080);
        expect(image.height, 1500);
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }
}
