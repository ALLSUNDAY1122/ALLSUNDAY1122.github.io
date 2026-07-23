import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'stats_store.dart';

part 'home_part.dart';
part 'game_part.dart';
part 'widgets_part.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShiwakeSwipeApp());
}

class ShiwakeSwipeApp extends StatelessWidget {
  const ShiwakeSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF101217);
    const panel = Color(0xFF191C24);
    const accent = Color(0xFFF1B44C);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '仕訳スワイプ',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: panel,
          onPrimary: Color(0xFF201500),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
