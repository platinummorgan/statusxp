import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/theme/theme.dart';
import 'package:statusxp/ui/widgets/web_app_shell.dart';

void main() {
  group('Web guest shell', () {
    for (final width in [390.0, 768.0, 899.0, 900.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('home is readable at width $width and text scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const WebAppShell(
                  location: '/',
                  isAuthenticated: false,
                  child: SizedBox.shrink(),
                ),
              ),
              GoRoute(
                path: '/sign-in',
                builder: (_, state) => Scaffold(
                  body: Text(
                    'Auth mode: ${state.uri.queryParameters['mode'] ?? 'signin'}',
                  ),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              theme: statusXPTheme,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('YOUR GAMING LIFE,\nALL IN ONE PLACE.'),
            findsOneWidget,
          );
          expect(find.text('Sign in'), findsOneWidget);
          expect(
            tester
                .widgetList<Scaffold>(find.byType(Scaffold))
                .any((widget) => widget.backgroundColor == backgroundDark),
            isTrue,
          );
          expect(tester.takeException(), isNull);

          // Returning users retain a working sign-in action at every size.
          await tester.tap(find.text('Sign in'));
          await tester.pumpAndSettle();
          expect(find.text('Auth mode: signin'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }, skip: !kIsWeb);
}
