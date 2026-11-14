import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/iphone13_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FoodieApp());
}

/// Custom scroll behavior untuk Web & Desktop agar scrolling dengan mouse wheel,
/// trackpad, dan drag terasa fluid dan responsif tanpa stuttering/patah-patah.
class SmoothWebScrollBehavior extends MaterialScrollBehavior {
  const SmoothWebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class FoodieApp extends StatelessWidget {
  const FoodieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodie Delivery',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothWebScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryContainer,
          primary: AppColors.primaryContainer,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      builder: (context, child) {
        return IPhone13Frame(
          child: child ?? const SplashScreen(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
