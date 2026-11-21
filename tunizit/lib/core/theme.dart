import 'package:material_ui/material_ui.dart';

class AppColors {
  static const forest = Color(0xFF2F4A1B);
  static const olive = Color(0xFF4F6F2C);
  static const oliveLight = Color(0xFF7A9A3E);
  static const oliveSoft = Color(0xFFE8EDD6);
  static const cream = Color(0xFFF7F5EC);
  static const border = Color(0xFFDDD9C5);
  static const ink = Color(0xFF1F2A14);
  static const muted = Color(0xFF6B7059);
  static const good = Color(0xFF2E7D32);
  static const medium = Color(0xFFB7791F);
  static const low = Color(0xFFC25E1B);
}

class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x14233012), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.olive,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.olive,
    primaryContainer: AppColors.oliveSoft,
    onPrimaryContainer: AppColors.forest,
    surface: AppColors.cream,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        shape: shape,
        textStyle: textStyle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        minimumSize: const Size(64, 54),
        shape: shape,
        textStyle: textStyle,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.olive),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.olive, 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.oliveSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.forest
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.forest
              : AppColors.muted,
        ),
      ),
    ),
  );
}

// Carte blanche aux bords arrondis avec ombre légère, utilisée partout.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.color = Colors.white,
    this.borderColor = AppColors.border,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color color;
  final Color borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: shadow ? AppShadows.soft : null,
      ),
      child: child,
    );
  }
}