import 'package:flutter/material.dart';
import 'package:statusxp/theme/theme.dart';
import 'package:statusxp/ui/navigation/app_router.dart';

void main() {
  runApp(const StatusXPApp());
}

class StatusXPApp extends StatelessWidget {
  const StatusXPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StatusXP',
      debugShowCheckedModeBanner: false,
      theme: statusXPTheme,
      routerConfig: appRouter,
    );
  }
}
