import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
// AppTheme — ThemeData factory + design tokens
//
// ใช้งาน:
//   MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, ...)
//   AppColors.of(context).navy   ← สีที่เปลี่ยนตาม dark/light อัตโนมัติ
//   AppTheme.navy                ← backward-compat (light value เสมอ)
// ════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  // ─── Spacing scale ───────────────────────────────────────────────
  static const double sp4 = 4.0;
  static const double sp8 = 8.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;
  static const double sp48 = 48.0;

  // ─── Border radius ────────────────────────────────────────────────
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;

  // ─── Component sizes ─────────────────────────────────────────────
  static const double inputHeight = 54.0;
  static const double buttonHeight = 54.0;

  // ─── Brand seed colors ───────────────────────────────────────────
  static const Color _seedLight = Color(0xFF2D4F8F);
  static const Color _seedDark = Color(0xFF7FA6FF);

  // ─── Light theme ─────────────────────────────────────────────────
  static ThemeData get light => _buildTheme(Brightness.light);

  // ─── Dark theme ──────────────────────────────────────────────────
  static ThemeData get dark => _buildTheme(Brightness.dark);

  // ─── Internal builder ────────────────────────────────────────────
  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seededScheme = ColorScheme.fromSeed(
      seedColor: isDark ? _seedDark : _seedLight,
      brightness: brightness,
    );
    final colors = isDark ? AppColors.dark : AppColors.light;
    final scheme = seededScheme.copyWith(
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.cardBorder,
      outlineVariant: colors.dividerColor,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Kanit',
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      textTheme: _textTheme(brightness, colors),
      iconTheme: IconThemeData(color: colors.textSecondary),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        subtitleTextStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 13,
          fontFamily: 'Kanit',
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colors.cardWhite,
        indicatorColor: colors.navy.withValues(alpha: isDark ? 0.18 : 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? colors.textPrimary : colors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontFamily: 'Kanit',
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.navy : colors.textSecondary,
          );
        }),
      ),

      // ── InputDecoration global ──
      inputDecorationTheme: _inputDecorationTheme(scheme, colors),

      // ── ElevatedButton global ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: sp24, vertical: sp12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(r12)),
          elevation: isDark ? 0 : 2,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            fontFamily: 'Kanit',
          ),
        ),
      ),

      // ── OutlinedButton global ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: sp24, vertical: sp12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(r12)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            fontFamily: 'Kanit',
          ),
        ),
      ),

      // ── TextButton global ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Kanit',
          ),
        ),
      ),

      // ── Card global ──
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: isDark
              ? BorderSide(color: colors.cardBorder, width: 1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        color: colors.cardWhite,
        margin: EdgeInsets.zero,
      ),

      // ── AppBar global ──
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 1,
        backgroundColor: colors.cardWhite,
        foregroundColor: colors.textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
          fontFamily: 'Kanit',
        ),
      ),

      // ── TabBar (คอนทราสต์บน AppBar — หลีกเลี่ยง primary ที่อ่านยากบนโหมดมืด) ──
      tabBarTheme: TabBarThemeData(
        labelColor: colors.textPrimary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.navy,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: colors.dividerColor,
      ),

      // ── DataTable ──
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          isDark ? colors.navy.withValues(alpha: 0.18) : colors.iconBgIncome,
        ),
        headingTextStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          fontFamily: 'Kanit',
        ),
        dataTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 13,
          fontFamily: 'Kanit',
        ),
        dividerThickness: 1,
        decoration: BoxDecoration(
          border: Border.all(color: colors.cardBorder),
          borderRadius: BorderRadius.circular(r8),
        ),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r12),
        ),
      ),

      // ── Tooltip (คอนทราสต์สูง — default M3 บน desktop มักอ่านยาก) ──
      tooltipTheme: _tooltipTheme(brightness, scheme),
    );
  }

  static TextTheme _textTheme(Brightness brightness, AppColors colors) {
    final base =
        ThemeData(brightness: brightness, fontFamily: 'Kanit').textTheme;
    TextStyle? primary(TextStyle? style) => style?.copyWith(
          color: colors.textPrimary,
          fontFamily: 'Kanit',
        );
    TextStyle? secondary(TextStyle? style) => style?.copyWith(
          color: colors.textSecondary,
          fontFamily: 'Kanit',
        );

    return base.copyWith(
      displayLarge: primary(base.displayLarge),
      displayMedium: primary(base.displayMedium),
      displaySmall: primary(base.displaySmall),
      headlineLarge: primary(base.headlineLarge),
      headlineMedium: primary(base.headlineMedium),
      headlineSmall: primary(base.headlineSmall),
      titleLarge: primary(base.titleLarge),
      titleMedium: primary(base.titleMedium),
      titleSmall: primary(base.titleSmall),
      bodyLarge: primary(base.bodyLarge),
      bodyMedium: primary(base.bodyMedium),
      bodySmall: secondary(base.bodySmall),
      labelLarge: primary(base.labelLarge),
      labelMedium: secondary(base.labelMedium),
      labelSmall: secondary(base.labelSmall),
    );
  }

  /// พื้นหลัง/ตัวอักษรแยกชัด light vs dark — ใช้ทั้งแอปแทน inverseSurface ของ seed
  static TooltipThemeData _tooltipTheme(
    Brightness brightness,
    ColorScheme scheme,
  ) {
    final isLight = brightness == Brightness.light;
    const bgLight = Color(0xFF1A2333);
    const bgDarkMode = Color(0xFFE8EEF8);
    const fgDarkMode = Color(0xFF101820);

    return TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 6),
      verticalOffset: 10,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      preferBelow: true,
      decoration: BoxDecoration(
        color: isLight ? bgLight : bgDarkMode,
        borderRadius: BorderRadius.circular(r8),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.12)
              : scheme.outline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.22 : 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: isLight ? Colors.white : fgDarkMode,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        fontFamily: 'Kanit',
      ),
    );
  }

  static Color foregroundFor(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF101820);
  }

  static InputDecorationTheme _inputDecorationTheme(
      ColorScheme scheme, AppColors colors) {
    final borderRadius = BorderRadius.circular(r12);
    final defaultBorder = BorderSide(color: colors.cardBorder, width: 1);

    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: sp16, vertical: sp16),
      border: OutlineInputBorder(
          borderRadius: borderRadius, borderSide: defaultBorder),
      enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius, borderSide: defaultBorder),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide:
            BorderSide(color: colors.cardBorder.withValues(alpha: 0.55)),
      ),
      labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      hintStyle: TextStyle(
        color: colors.textHint,
        fontSize: 14,
      ),
      errorStyle: TextStyle(color: scheme.error, fontSize: 12),
      floatingLabelStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return scheme.primary;
        if (states.contains(WidgetState.error)) return scheme.error;
        if (states.contains(WidgetState.disabled)) return colors.textHint;
        return colors.textSecondary;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return scheme.primary;
        if (states.contains(WidgetState.error)) return scheme.error;
        if (states.contains(WidgetState.disabled)) return colors.textHint;
        return colors.textSecondary;
      }),
    );
  }

  // ─── Static color tokens (light values — backward compat) ────────
  // หน้าใหม่ควรใช้ AppColors.of(context).xxx แทน เพื่อรองรับ dark mode
  static const Color navy = Color(0xFF1F3A66);
  static const Color navyLight = Color(0xFF325186);
  static const Color incomeGreen = Color(0xFF1F7A54);
  static const Color expenseRed = Color(0xFFC44747);
  static const Color loanAmber = Color(0xFF8A641A);
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFDEE5F0);
  static const Color dividerColor = Color(0xFFC9D3E2);
  static const Color textPrimary = Color(0xFF162338);
  static const Color textSecondary = Color(0xFF5D6A7E);
  static const Color textHint = Color(0xFF9AA8BC);
  static const Color iconBgIncome = Color(0xFFEAF6F0);
  static const Color iconBgExpense = Color(0xFFFDEEEE);
  static const Color iconBgLoan = Color(0xFFFCF5E8);
}

// ════════════════════════════════════════════════════════════════════════════
// AppColors — semantic color tokens, เปลี่ยนตาม dark/light อัตโนมัติ
//
// ใช้งาน:
//   final c = AppColors.of(context);
//   Container(color: c.navy)
//   Text('...', style: TextStyle(color: c.incomeGreen))
// ════════════════════════════════════════════════════════════════════════════
class AppColors {
  final Color navy;
  final Color navyLight;
  final Color incomeGreen;
  final Color expenseRed;
  final Color loanAmber;
  final Color background;
  final Color surface;
  final Color cardWhite;
  final Color cardBorder;
  final Color dividerColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color iconBgIncome;
  final Color iconBgExpense;
  final Color iconBgLoan;
  /// พื้นโต๊ะรอบแผ่นรายงาน (ให้แผ่นกระดาษลอยชัด)
  final Color reportDesk;
  /// พื้นแผ่นรายงาน — ใกล้กระดาษพิมพ์จริง
  final Color reportPaper;
  /// ขอบ/เส้นแบบฟอร์มบนกระดาษ
  final Color reportPaperBorder;
  /// หัวตารางแบบเอกสารราชการ
  final Color reportTableHeader;

  const AppColors({
    required this.navy,
    required this.navyLight,
    required this.incomeGreen,
    required this.expenseRed,
    required this.loanAmber,
    required this.background,
    required this.surface,
    required this.cardWhite,
    required this.cardBorder,
    required this.dividerColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.iconBgIncome,
    required this.iconBgExpense,
    required this.iconBgLoan,
    required this.reportDesk,
    required this.reportPaper,
    required this.reportPaperBorder,
    required this.reportTableHeader,
  });

  // ─── Light palette ───────────────────────────────────────────────
  static const AppColors light = AppColors(
    navy: Color(0xFF1F3A66),
    navyLight: Color(0xFF325186),
    incomeGreen: Color(0xFF1F7A54),
    expenseRed: Color(0xFFC44747),
    loanAmber: Color(0xFF8A641A),
    background: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    cardWhite: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFDEE5F0),
    dividerColor: Color(0xFFC9D3E2),
    textPrimary: Color(0xFF162338),
    textSecondary: Color(0xFF5D6A7E),
    textHint: Color(0xFF9AA8BC),
    iconBgIncome: Color(0xFFEAF6F0),
    iconBgExpense: Color(0xFFFDEEEE),
    iconBgLoan: Color(0xFFFCF5E8),
    reportDesk: Color(0xFFD9E0EA),
    reportPaper: Color(0xFFFFFDF8),
    reportPaperBorder: Color(0xFFC5CCD6),
    reportTableHeader: Color(0xFFEEF1F5),
  );

  // ─── Dark palette ────────────────────────────────────────────────
  static const AppColors dark = AppColors(
    navy: Color(0xFF8FB4FF),
    navyLight: Color(0xFFB8CEFF),
    incomeGreen: Color(0xFF45B789),
    expenseRed: Color(0xFFE67878),
    loanAmber: Color(0xFFE2B56A),
    background: Color(0xFF10151F),
    surface: Color(0xFF202B3D),
    cardWhite: Color(0xFF1C2638),
    cardBorder: Color(0xFF44546D),
    dividerColor: Color(0xFF52627B),
    textPrimary: Color(0xFFF4F7FF),
    textSecondary: Color(0xFFC6D0E2),
    textHint: Color(0xFF9EACC2),
    iconBgIncome: Color(0xFF193329),
    iconBgExpense: Color(0xFF3B2227),
    iconBgLoan: Color(0xFF3A3120),
    reportDesk: Color(0xFF0C1018),
    reportPaper: Color(0xFF232C3C),
    reportPaperBorder: Color(0xFF4A5A72),
    reportTableHeader: Color(0xFF2C3648),
  );

  // ─── Context-aware factory ───────────────────────────────────────
  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
