import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'stats_store.dart';

part 'home_part.dart';
part 'game_part.dart';
part 'widgets_part.dart';
part 'delight_motion_part.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF101217),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
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
          secondary: Color(0xFF53C3A3),
          tertiary: Color(0xFFE87878),
          surface: panel,
          onPrimary: Color(0xFF201500),
        ),
        useMaterial3: true,
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          },
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
