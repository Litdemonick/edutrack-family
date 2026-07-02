import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/shared/widgets/offline_banner.dart';
import 'package:edutrack_family/core/features/admin/dashboard/admin_dashboard.dart';
import 'package:edutrack_family/core/features/admin/tasks/task_list_admin.dart';
import 'package:edutrack_family/core/features/admin/events/event_list_admin.dart';
import 'package:edutrack_family/core/features/admin/history/history_screen.dart';
import 'package:edutrack_family/core/features/admin/evidence/view_evidence_screen.dart';
import 'package:edutrack_family/core/features/student/calendar/schedule/class_schedule_screen.dart';
import 'package:edutrack_family/core/features/student/calendar/student_calendar.dart';
import 'package:edutrack_family/core/features/admin/stats/admin_stats_screen.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _fabOpen = false;
  late final AnimationController _fabCtrl;
  late final Animation<double> _fabRotation;

  // Pages: 0=Panel 1=Tareas 2=Eventos 3=Revisión
  //        4=Historial(FAB) 5=Horario(FAB) 6=Calendario(FAB) 7=Estadísticas(FAB)
  late final List<Widget> _pages = [
    AdminDashboard(onNavigateToReview: () => _selectPage(3)),
    const TaskListAdmin(),
    const EventListAdmin(),
    const ViewEvidenceScreen(),
    const HistoryScreen(),
    const ClassScheduleScreen(),
    const StudentCalendar(),
    const AdminStatsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    // 0.375 turns = 135° → turns + into ×
    _fabRotation = Tween<double>(begin: 0.0, end: 0.375).animate(
      CurvedAnimation(parent: _fabCtrl, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    if (_fabOpen) {
      _fabCtrl.forward();
    } else {
      _fabCtrl.reverse();
    }
  }

  void _closeFab() {
    if (!_fabOpen) return;
    setState(() => _fabOpen = false);
    _fabCtrl.reverse();
  }

  void _selectPage(int index) {
    _closeFab();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: Stack(
        children: [
          // ── Contenido principal ──────────────────────────────
          Column(
            children: [
              const OfflineBanner(),
              Expanded(child: _pages[_currentIndex]),
            ],
          ),

          // ── Overlay de atenuación al abrir FAB ──────────────
          AnimatedOpacity(
            opacity: _fabOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: GestureDetector(
                onTap: _closeFab,
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),

          // ── Speed dial — aparece sobre el FAB ───────────────
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SpeedDialItem(
                    icon: Icons.settings_rounded,
                    label: 'Ajustes',
                    color: AppColors.grey,
                    visible: _fabOpen,
                    delayMs: 240,
                    onTap: () {
                      _closeFab();
                      context.push(AppRoutes.settings);
                    },
                  ),
                  const SizedBox(height: 14),
                  _SpeedDialItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Estadísticas',
                    color: const Color(0xFFFF9800),
                    visible: _fabOpen,
                    delayMs: 180,
                    onTap: () => _selectPage(7),
                  ),
                  const SizedBox(height: 14),
                  _SpeedDialItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Calendario',
                    color: const Color(0xFF4CAF50),
                    visible: _fabOpen,
                    delayMs: 120,
                    onTap: () => _selectPage(6),
                  ),
                  const SizedBox(height: 14),
                  _SpeedDialItem(
                    icon: Icons.calendar_view_week_rounded,
                    label: 'Horario de Yordan',
                    color: const Color(0xFF00BCD4),
                    visible: _fabOpen,
                    delayMs: 60,
                    onTap: () => _selectPage(5),
                  ),
                  const SizedBox(height: 14),
                  _SpeedDialItem(
                    icon: Icons.history_rounded,
                    label: 'Historial',
                    color: const Color(0xFF7C4DFF),
                    visible: _fabOpen,
                    delayMs: 0,
                    onTap: () => _selectPage(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── FAB central ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleFab,
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: _fabOpen ? 8 : 4,
        shape: const CircleBorder(),
        child: AnimatedBuilder(
          animation: _fabRotation,
          builder: (_, _) => Transform.rotate(
            angle: _fabRotation.value * 2 * math.pi,
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── BottomAppBar con notch ───────────────────────────────
      bottomNavigationBar: BottomAppBar(
        color: navBg,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Panel',
              isSelected: _currentIndex == 0,
              color: AppColors.accentBlue,
              onTap: () => _selectPage(0),
            ),
            _NavItem(
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              label: 'Tareas',
              isSelected: _currentIndex == 1,
              color: const Color(0xFFFF6B35),
              onTap: () => _selectPage(1),
            ),
            const Spacer(), // espacio para el FAB
            _NavItem(
              icon: Icons.event_outlined,
              activeIcon: Icons.event_rounded,
              label: 'Eventos',
              isSelected: _currentIndex == 2,
              color: const Color(0xFF4CAF50),
              onTap: () => _selectPage(2),
            ),
            _NavItem(
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library_rounded,
              label: 'Revisión',
              isSelected: _currentIndex == 3,
              color: const Color(0xFFFF4081),
              onTap: () => _selectPage(3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAV ITEM — icono + label con bounce al seleccionarse
// ─────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.30), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.30, end: 0.88), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white38 : Colors.black54;

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scale,
                builder: (_, child) =>
                    Transform.scale(scale: _scale.value, child: child),
                child: Icon(
                  widget.isSelected ? widget.activeIcon : widget.icon,
                  size: 24,
                  color: widget.isSelected ? widget.color : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isSelected ? widget.color : inactiveColor,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPEED DIAL ITEM — chip de label + botón circular
// Entra deslizando desde abajo con fade al mostrarse
// ─────────────────────────────────────────────────────────────

class _SpeedDialItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool visible;
  final int delayMs;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.visible,
    required this.delayMs,
    required this.onTap,
  });

  @override
  State<_SpeedDialItem> createState() => _SpeedDialItemState();
}

class _SpeedDialItemState extends State<_SpeedDialItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    if (widget.visible) _playIn();
  }

  @override
  void didUpdateWidget(_SpeedDialItem old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _playIn();
    } else if (!widget.visible && old.visible) {
      _ctrl.reverse();
    }
  }

  void _playIn() {
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chip de etiqueta
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón circular con color de categoría
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
