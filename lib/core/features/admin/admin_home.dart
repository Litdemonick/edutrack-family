import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/providers/schedule_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/services/sync_service.dart';
import 'package:edutrack_family/core/shared/widgets/offline_banner.dart';
import 'package:edutrack_family/core/features/admin/dashboard/admin_dashboard.dart';
import 'package:edutrack_family/core/features/admin/tasks/task_list_admin.dart';
import 'package:edutrack_family/core/features/admin/events/event_list_admin.dart';
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
  bool _refreshing = false;
  late final AnimationController _fabCtrl;
  late final Animation<double> _fabRotation;

  /// Sync manual e inmediato — no espera al refresco periódico de
  /// respaldo (45s) ni a que el listener en tiempo real reaccione;
  /// lo dispara el propio usuario (swipe en celular, botón en PC)
  /// cuando quiere estar seguro de ver lo último ahora mismo.
  Future<void> _manualRefresh() async {
    setState(() => _refreshing = true);
    try {
      await SyncService.instance.fullSync();
      if (!mounted) return;
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(eventProvider.notifier).loadEvents();
      ref.read(scheduleProvider.notifier).load();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // Pages: 0=Panel 1=Tareas 2=Eventos 3=Revisión
  //        4=Horario(FAB) 5=Calendario(FAB) 6=Estadísticas(FAB)
  late final List<Widget> _pages = [
    AdminDashboard(onNavigateToReview: () => _selectPage(3)),
    const TaskListAdmin(),
    const EventListAdmin(),
    const ViewEvidenceScreen(),
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

  // Ítems de navegación que dependen del rol del adulto (padre/tutor
  // vs. profesor) — única fuente de verdad para el speed-dial
  // compacto y el trailing del NavigationRail expandido, así el
  // guard de rol de cada ítem se define una sola vez.
  List<_HomeAction> _actionsFor(UserRole role) {
    return [
      _HomeAction(
        icon: Icons.settings_rounded,
        label: 'Ajustes',
        color: AppColors.grey,
        delayMs: 300,
        visibleFor: (_) => true,
        onTap: (ctx) => ctx.push(AppRoutes.settings),
      ),
      _HomeAction(
        icon: role == UserRole.teacher
            ? Icons.groups_rounded
            : Icons.family_restroom_rounded,
        label: role == UserRole.teacher ? 'Mis estudiantes' : 'Mi familia',
        color: const Color(0xFFE91E63),
        delayMs: 240,
        visibleFor: (_) => true,
        onTap: (ctx) => ctx.push(AppRoutes.family),
      ),
      _HomeAction(
        icon: Icons.location_on_rounded,
        label: 'Ubicación',
        color: const Color(0xFF009688),
        delayMs: 210,
        // Ubicación GPS: solo el padre/tutor la ve (los profesores no
        // tienen acceso, ver firestore.rules locations/** → allow
        // read: if isGuardian()).
        visibleFor: (r) => r == UserRole.parent,
        onTap: (ctx) => ctx.push(AppRoutes.locationMap),
      ),
    ].where((a) => a.visibleFor(role)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = ref.watch(authProvider)?.role ?? UserRole.parent;
    final actions = _actionsFor(role);

    // "Ver logros" en Mi familia deja pendiente el índice de la
    // pestaña de Estadísticas — se consume una sola vez y se limpia,
    // para no volver a saltar solo en la próxima reconstrucción.
    ref.listen<int?>(pendingAdminTabProvider, (previous, next) {
      if (next != null) {
        _selectPage(next);
        ref.read(pendingAdminTabProvider.notifier).state = null;
      }
    });

    if (context.isCompact) {
      return _buildCompact(context, isDark, actions);
    }
    return _buildExpanded(context, isDark, actions);
  }

  // ── Layout teléfono: bottom nav + FAB speed dial ────────────
  Widget _buildCompact(
      BuildContext context, bool isDark, List<_HomeAction> actions) {
    final navBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: Stack(
        children: [
          // ── Contenido principal ──────────────────────────────
          // SafeArea solo arriba: evita que el contenido quede
          // debajo de la hora/notificaciones/wifi del celular. Abajo
          // lo maneja el propio bottomNavigationBar (ver más abajo)
          // para no reservar el espacio dos veces.
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _manualRefresh,
                    child: _pages[_currentIndex],
                  ),
                ),
              ],
            ),
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
          // En horizontal (altura corta) no entra apilado hacia
          // arriba sin tapar el contenido de encima — se acomoda en
          // fila (Wrap) en vez de columna, usando mucho menos alto.
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SpeedDialLayout(
                horizontal: context.isShortHeight,
                items: [
                  for (final action in actions)
                    _SpeedDialItem(
                      icon: action.icon,
                      label: action.label,
                      color: action.color,
                      visible: _fabOpen,
                      delayMs: action.delayMs,
                      onTap: () {
                        _closeFab();
                        action.onTap(context);
                      },
                    ),
                  _SpeedDialItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Estadísticas',
                    color: const Color(0xFFFF9800),
                    visible: _fabOpen,
                    delayMs: 120,
                    onTap: () => _selectPage(6),
                  ),
                  _SpeedDialItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Calendario',
                    color: const Color(0xFF4CAF50),
                    visible: _fabOpen,
                    delayMs: 60,
                    onTap: () => _selectPage(5),
                  ),
                  _SpeedDialItem(
                    icon: Icons.calendar_view_week_rounded,
                    label: 'Horario',
                    color: const Color(0xFF00BCD4),
                    visible: _fabOpen,
                    delayMs: 0,
                    onTap: () => _selectPage(4),
                  ),
                ],
                ),
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
      // SafeArea solo abajo: en celulares con barra de gestos, el
      // sistema dibuja edge-to-edge y sin esto la franja de gestos
      // se comía parte de los botones de navegación.
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
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
      ),
    );
  }

  // ── Layout tablet/escritorio: sidebar propio + contenido centrado ──
  Widget _buildExpanded(
      BuildContext context, bool isDark, List<_HomeAction> actions) {
    final destinations = <_RailDestination>[
      const _RailDestination(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Panel'),
      const _RailDestination(Icons.assignment_outlined, Icons.assignment_rounded, 'Tareas'),
      const _RailDestination(Icons.event_outlined, Icons.event_rounded, 'Eventos'),
      const _RailDestination(Icons.photo_library_outlined, Icons.photo_library_rounded, 'Revisión'),
      const _RailDestination(Icons.calendar_view_week_outlined, Icons.calendar_view_week_rounded, 'Horario'),
      const _RailDestination(Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Calendario'),
      const _RailDestination(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Estadísticas'),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar propio (no NavigationRail): widgets simples
                // y predecibles (Container+Column+Row) en vez de pelear
                // con el presupuesto de alto interno de NavigationRail,
                // que ya causó overflow/crash un par de veces. Un solo
                // Expanded(SizedBox()) como espaciador flexible + todo
                // lo demás de alto fijo — no puede desbordar.
                Container(
                  width: 236,
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Botón de refresco manual — en escritorio no
                      // hay gesto de "deslizar para actualizar"
                      // (la física de scroll ahí no rebota), así que
                      // es el equivalente al pull-to-refresh móvil.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: OutlinedButton.icon(
                          onPressed: _refreshing ? null : _manualRefresh,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(_refreshing ? 'Actualizando...' : 'Actualizar'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Scrolleable (no altura fija): si la ventana es
                      // corta (p. ej. celular en horizontal, o más
                      // destinos a futuro) la lista se desliza en vez
                      // de desbordar — el pie (familia + acciones)
                      // siempre queda visible abajo.
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (var i = 0; i < destinations.length; i++)
                                _SidebarNavItem(
                                  icon: _currentIndex == i
                                      ? destinations[i].activeIcon
                                      : destinations[i].icon,
                                  label: destinations[i].label,
                                  selected: _currentIndex == i,
                                  isDark: isDark,
                                  onTap: () => _selectPage(i),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _buildFamilyCard(isDark),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final action in actions)
                              IconButton(
                                icon:
                                    Icon(action.icon, color: Colors.white),
                                tooltip: action.label,
                                style: IconButton.styleFrom(
                                  backgroundColor: action.color,
                                  shape: const CircleBorder(),
                                ),
                                onPressed: () => action.onTap(context),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  // 1400 (no 1100): en monitores grandes 1100 dejaba
                  // demasiado espacio vacío a los costados.
                  child: CenteredConstrained(
                    maxWidth: 1400,
                    child: _pages[_currentIndex],
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta "Cuenta familiar" / "Cuenta de profesor" del sidebar ──
  Widget _buildFamilyCard(bool isDark) {
    final students = ref.watch(linkedStudentsProvider);
    final role = ref.watch(authProvider)?.role ?? UserRole.parent;
    final isTeacher = role == UserRole.teacher;
    final countLabel = isTeacher ? 'estudiantes vinculados' : 'hijos vinculados';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.family),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTeacher ? 'Cuenta de profesor' : 'Cuenta familiar',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppColors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${students.length} $countLabel',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _RailDestination(this.icon, this.activeIcon, this.label);
}

// ─────────────────────────────────────────────────────────────
// ÍTEM DEL SIDEBAR — ícono + etiqueta en fila, con fondo sólido
// cuando está seleccionado (ver mockup de escritorio).
// ─────────────────────────────────────────────────────────────
class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white54 : AppColors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.navyBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ÍTEM DE NAVEGACIÓN GATEADO POR ROL — fuente única para el
// speed-dial compacto y el trailing del NavigationRail expandido.
// ─────────────────────────────────────────────────────────────
class _HomeAction {
  final IconData icon;
  final String label;
  final Color color;
  final int delayMs;
  final bool Function(UserRole role) visibleFor;
  final void Function(BuildContext context) onTap;

  const _HomeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.delayMs,
    required this.visibleFor,
    required this.onTap,
  });
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
// SPEED DIAL LAYOUT — columna (vertical) en portrait/altura normal,
// fila envolvente (Wrap) en horizontal/altura corta. Wrap usa mucho
// menos alto porque acomoda los items uno al lado del otro en vez
// de apilarlos, así no tapa el contenido de encima cuando no hay
// espacio vertical.
// ─────────────────────────────────────────────────────────────

class _SpeedDialLayout extends StatelessWidget {
  final bool horizontal;
  final List<Widget> items;

  const _SpeedDialLayout({required this.horizontal, required this.items});

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: items,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1) const SizedBox(height: 14),
        ],
      ],
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
            mainAxisSize: MainAxisSize.min,
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
