import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// APP THEME — EduTrack Family
// Tema visual completo para Android e iOS.
// Se aplica en MaterialApp.router dentro de app.dart
// ═══════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────
  // TEMA CLARO (principal)
  // ─────────────────────────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,

      // ── Color scheme ────────────────────────────────────────
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navyBlue,
        primary: AppColors.navyBlue,
        primaryContainer: AppColors.royalBlue,
        secondary: AppColors.accentBlue,
        secondaryContainer: AppColors.lightBlue,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkGrey,
        onError: Colors.white,
        brightness: Brightness.light,
      ),

      primaryColor: AppColors.navyBlue,
      scaffoldBackgroundColor: AppColors.background,

      // ── AppBar ───────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // iOS
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: IconThemeData(color: Colors.white, size: 24),
        toolbarHeight: 60,
      ),

      // ── Tipografía ───────────────────────────────────────────
      fontFamily: 'Poppins',
      textTheme: _buildTextTheme(),

      // ── Cards ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.shadowLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Botones elevados ─────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lightGrey,
          disabledForegroundColor: AppColors.grey,
          elevation: 2,
          shadowColor: AppColors.shadowMedium,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Botones outlined ─────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyBlue,
          disabledForegroundColor: AppColors.grey,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.navyBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Botones de texto ─────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Inputs / TextFields ──────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGrey.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2.0),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey, width: 1.0),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: AppColors.grey,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: AppColors.accentBlue,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: AppColors.grey,
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: AppColors.error,
          height: 1.3,
        ),
        prefixIconColor: AppColors.grey,
        suffixIconColor: AppColors.grey,
        isDense: false,
      ),

      // ── BottomNavigationBar ──────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.navyBlue,
        unselectedItemColor: AppColors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        elevation: 12,
        type: BottomNavigationBarType.fixed,
      ),

      // ── NavigationBar (Material 3) ───────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.lightBlue,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.navyBlue, size: 24);
          }
          return const IconThemeData(color: AppColors.grey, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.navyBlue,
            );
          }
          return const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.grey,
          );
        }),
        elevation: 12,
        height: 68,
      ),

      // ── FloatingActionButton ─────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        shape: CircleBorder(),
        iconSize: 26,
      ),

      // ── Chips ────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightBlue,
        selectedColor: AppColors.navyBlue,
        disabledColor: AppColors.lightGrey,
        deleteIconColor: AppColors.grey,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.navyBlue,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: BorderSide.none,
      ),

      // ── Divisores ────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.lightGrey,
        thickness: 1,
        space: 1,
      ),

      // ── Snackbars ────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navyBlue,
        contentTextStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.skyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
      ),

      // ── Dialogs ──────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: AppColors.shadowStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.navyBlue,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: AppColors.darkGrey,
          height: 1.5,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),

      // ── Bottom Sheet ─────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.mediumGrey,
        dragHandleSize: Size(40, 4),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Switch ───────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.navyBlue;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue;
          }
          return AppColors.mediumGrey;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Checkbox ─────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.navyBlue;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.grey, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Radio ────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.navyBlue;
          }
          return AppColors.grey;
        }),
      ),

      // ── ListTile ─────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
        iconColor: AppColors.navyBlue,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkGrey,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          color: AppColors.grey,
        ),
      ),

      // ── PopupMenu ────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: 8,
        shadowColor: AppColors.shadowMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: AppColors.darkGrey,
        ),
      ),

      // ── IconButton ───────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.navyBlue),
      ),

      // ── Tooltip ──────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.charcoal.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── ProgressIndicator ────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentBlue,
        linearTrackColor: AppColors.lightBlue,
        circularTrackColor: AppColors.lightBlue,
      ),

      // ── DatePicker ───────────────────────────────────────────
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        headerBackgroundColor: AppColors.navyBlue,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return AppColors.lightGrey;
          return AppColors.darkGrey;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.navyBlue;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.all(AppColors.accentBlue),
        todayBackgroundColor: WidgetStateProperty.all(AppColors.lightBlue),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // ── TimePicker ───────────────────────────────────────────
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        hourMinuteColor: AppColors.lightBlue,
        hourMinuteTextColor: AppColors.navyBlue,
        dayPeriodColor: AppColors.lightBlue,
        dayPeriodTextColor: AppColors.navyBlue,
        dialBackgroundColor: AppColors.lightBlue,
        dialHandColor: AppColors.navyBlue,
        dialTextColor: AppColors.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TEMA OSCURO
  // ─────────────────────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentBlue,
        primary: AppColors.accentBlue,
        primaryContainer: const Color(0xFF1A3C5E),
        secondary: AppColors.skyBlue,
        secondaryContainer: const Color(0xFF1E3A5F),
        surface: const Color(0xFF1E1E2E),
        surfaceContainerHighest: const Color(0xFF2A2A3E),
        error: const Color(0xFFEF5350),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFFE8EAF6),
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      primaryColor: AppColors.accentBlue,
      scaffoldBackgroundColor: const Color(0xFF12121E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: IconThemeData(color: Colors.white, size: 24),
        toolbarHeight: 60,
      ),
      fontFamily: 'Poppins',
      textTheme: _buildDarkTextTheme(),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E2E),
        elevation: 4,
        shadowColor: Colors.black45,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2A2A3E),
          disabledForegroundColor: Colors.white38,
          elevation: 2,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.skyBlue,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.accentBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.skyBlue,
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A5E), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2.0),
        ),
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.white54),
        floatingLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.skyBlue),
        hintStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: Colors.white38),
        prefixIconColor: Colors.white54,
        suffixIconColor: Colors.white54,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A2E),
        selectedItemColor: AppColors.skyBlue,
        unselectedItemColor: Colors.white38,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11),
        elevation: 12,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: const Color(0xFF1E3A5F),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.skyBlue, size: 24);
          }
          return const IconThemeData(color: Colors.white38, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.skyBlue);
          }
          return const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white38);
        }),
        elevation: 12,
        height: 68,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
        iconSize: 26,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A2A3E),
        selectedColor: AppColors.accentBlue,
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A2A3E), thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A2A3E),
        contentTextStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
        actionTextColor: AppColors.skyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E2E),
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        contentTextStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: Colors.white70, height: 1.5),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E2E),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        showDragHandle: true,
        dragHandleColor: Color(0xFF3A3A5E),
        dragHandleSize: Size(40, 4),
        clipBehavior: Clip.antiAlias,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white38),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.accentBlue : const Color(0xFF3A3A5E)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.accentBlue : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: Colors.white38, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.skyBlue,
        titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        subtitleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white54),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: const Color(0xFF1E1E2E),
        headerBackgroundColor: const Color(0xFF1A3C5E),
        headerForegroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white70;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accentBlue;
          return Colors.transparent;
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TEXTO DARK — mismo tamaño, colores adaptados
  // ─────────────────────────────────────────────────────────────
  static TextTheme _buildDarkTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5, height: 1.2),
      displayMedium: TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3, height: 1.2),
      displaySmall: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
      headlineLarge: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
      headlineMedium: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
      headlineSmall: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
      titleLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE8EAF6), height: 1.4),
      titleMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE8EAF6), height: 1.4),
      titleSmall: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white54, height: 1.4),
      bodyLarge: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFFE8EAF6), height: 1.6),
      bodyMedium: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFE8EAF6), height: 1.5),
      bodySmall: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white54, height: 1.5),
      labelLarge: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3, height: 1.4),
      labelMedium: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: 0.3, height: 1.4),
      labelSmall: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white54, letterSpacing: 0.5, height: 1.4),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TEXTO — sistema tipográfico completo
  // ─────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      // ── Display — títulos de pantalla principal ──────────────
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.navyBlue,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.navyBlue,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
        height: 1.3,
      ),

      // ── Headline — títulos de sección ────────────────────────
      headlineLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
        height: 1.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.navyBlue,
        height: 1.4,
      ),

      // ── Title — títulos de card / item ───────────────────────
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkGrey,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.darkGrey,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.grey,
        height: 1.4,
      ),

      // ── Body — texto de contenido principal ──────────────────
      bodyLarge: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.darkGrey,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.darkGrey,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.grey,
        height: 1.5,
      ),

      // ── Label — etiquetas, chips, botones ────────────────────
      labelLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.grey,
        height: 1.4,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ESTILOS DE TEXTO EXTRA — uso directo en widgets
  // Úsalos cuando necesites algo fuera del TextTheme estándar
  // ─────────────────────────────────────────────────────────────

  /// Título del splash / login — muy grande
  static const TextStyle splashTitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 38,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  /// Subtítulo del splash
  static const TextStyle splashSubtitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 22,
    fontWeight: FontWeight.w300,
    color: Colors.white70,
    letterSpacing: 4,
  );

  /// Tagline del splash
  static const TextStyle splashTagline = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    color: Colors.white54,
    letterSpacing: 0.5,
  );

  /// Número grande en stats del dashboard (ej: "5 tareas")
  static const TextStyle statNumber = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.0,
  );

  /// Etiqueta debajo del número en stats
  static const TextStyle statLabel = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 13,
    color: Colors.white70,
    fontWeight: FontWeight.w500,
  );

  /// Texto de badge / chip de categoría
  static const TextStyle categoryBadge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  /// Texto de días restantes en semáforo
  static const TextStyle daysLeftText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Texto de hora en horario de clases
  static const TextStyle scheduleTime = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.navyBlue,
  );

  /// Nombre de materia en el horario
  static const TextStyle scheduleSubject = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.darkGrey,
  );

  /// Nombre del banner / greeting
  static const TextStyle greetingName = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  /// Saludo (Buenos días, Buenas tardes)
  static const TextStyle greetingText = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
  );

  /// Texto offline banner
  static const TextStyle offlineBannerText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  // ─────────────────────────────────────────────────────────────
  // DECORACIONES DE CAJA REUTILIZABLES
  // ─────────────────────────────────────────────────────────────

  /// Card estándar con sombra suave
  static BoxDecoration cardDecoration({Color? color, double radius = 16}) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );

  /// Banner de degradado azul marino (dashboard header)
  static const BoxDecoration bannerDecoration = BoxDecoration(
    gradient: AppColors.gradientNavy,
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
  );

  /// Banner azul brillante (variante estudiante)
  static const BoxDecoration bannerDecorationStudent = BoxDecoration(
    gradient: AppColors.gradientBlue,
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
  );

  /// Badge de categoría con color dinámico
  static BoxDecoration categoryBadgeDecoration(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
  );

  /// Indicador de semáforo (dot circular)
  static BoxDecoration trafficLightDot(Color color) => BoxDecoration(
    color: color,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: 0.4),
        blurRadius: 6,
        spreadRadius: 1,
      ),
    ],
  );
}
