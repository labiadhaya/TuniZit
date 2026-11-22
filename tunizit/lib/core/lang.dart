import 'package:material_ui/material_ui.dart';
import 'theme.dart';

// حالة لغة الواجهة: false للفرنسية و true للعربية.
class AppLang {
  static final ValueNotifier<bool> isAr = ValueNotifier<bool>(false);
  static bool get ar => isAr.value;
  // ترجع النص المناسب حسب اللغة المختارة.
  static String tr(String fr, String arabic) => isAr.value ? arabic : fr;
}

// يعاود يبني الواجهة اللي داخلو كي المستخدم يبدّل اللغة.
class LangBuilder extends StatelessWidget {
  const LangBuilder({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.isAr,
      builder: (context, _, __) => builder(context),
    );
  }
}

// زرّ تبديل اللغة بين الفرنسية والعربية.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});

  Widget _seg(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LangBuilder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seg('FR', !AppLang.ar, () => AppLang.isAr.value = false),
            _seg('العربية', AppLang.ar, () => AppLang.isAr.value = true),
          ],
        ),
      ),
    );
  }
}

// شعار Tunizit مع الاسم والجملة التعريفية.
class TunizitLogo extends StatelessWidget {
  const TunizitLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.forest, AppColors.oliveLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(Icons.eco, color: Colors.white, size: size * 0.55),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tunizit',
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
                height: 1.1,
              ),
            ),
            Text(
              AppLang.tr('Smart Olive Farming', 'مساعد الزيتون الذكي'),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}