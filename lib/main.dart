import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'home/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (_) {}
  runApp(const PolyFlixApp());
}

/// 应用统一的视觉色彩令牌。
abstract final class PolyFlixColors {
  static const violet = Color(0xFF6657E8);
  static const indigo = Color(0xFF3730A3);
  static const coral = Color(0xFFFF775F);
  static const softViolet = Color(0xFFE9E7FF);
  static const midnight = Color(0xFF12121C);
}

enum AppThemeMode { light, dark, system }

class ThemeNotifier extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  void setMode(AppThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

final themeNotifier = ThemeNotifier();

class PolyFlixApp extends StatelessWidget {
  const PolyFlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: '影现播放器',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const HomePage(),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    const scheme = ColorScheme.light(
      primary: PolyFlixColors.violet,
      onPrimary: Colors.white,
      primaryContainer: PolyFlixColors.softViolet,
      onPrimaryContainer: PolyFlixColors.indigo,
      secondary: PolyFlixColors.coral,
      onSecondary: Colors.white,
      surface: Color(0xFFFFFBFF),
      onSurface: Color(0xFF1B1B25),
      surfaceContainerHighest: Color(0xFFEDECF3),
      outline: Color(0xFF787680),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F7FB),
      fontFamily: 'sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1B1B25),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }

  ThemeData _darkTheme() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFFC4BEFF),
      onPrimary: Color(0xFF27215A),
      primaryContainer: Color(0xFF46408E),
      onPrimaryContainer: Color(0xFFE4E1FF),
      secondary: Color(0xFFFFB4A5),
      onSecondary: Color(0xFF5F160B),
      surface: Color(0xFF12121C),
      onSurface: Color(0xFFE5E1EB),
      surfaceContainerHighest: Color(0xFF2A2934),
      outline: Color(0xFF928F99),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: PolyFlixColors.midnight,
      fontFamily: 'sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFE5E1EB),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1D1C27),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF24232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  static const _labels = {
    AppThemeMode.system: '跟随系统',
    AppThemeMode.light: '浅色模式',
    AppThemeMode.dark: '深色模式',
  };

  static const _icons = {
    AppThemeMode.system: Icons.brightness_auto_rounded,
    AppThemeMode.light: Icons.light_mode_rounded,
    AppThemeMode.dark: Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '切换外观',
      onPressed: () => _showThemeSheet(context),
      icon: Icon(_icons[themeNotifier.mode]),
    );
  }

  void _showThemeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('外观模式', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...AppThemeMode.values.map(
                (mode) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(_icons[mode]),
                  title: Text(_labels[mode]!),
                  trailing: mode == themeNotifier.mode
                      ? Icon(Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () {
                    themeNotifier.setMode(mode);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
