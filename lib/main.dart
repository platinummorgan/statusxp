import 'package:flutter/material.dart';
import 'package:statusxp/theme/theme.dart';
import 'package:statusxp/ui/screens/theme_demo_screen.dart';

void main() {
  runApp(const StatusXPApp());
}

class StatusXPApp extends StatelessWidget {
  const StatusXPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StatusXP',
      debugShowCheckedModeBanner: false,
      theme: statusXPTheme,
      home: const ThemeDemoScreen(),
    );
  }
}
