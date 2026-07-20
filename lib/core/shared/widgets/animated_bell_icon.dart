import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// ANIMATED BELL ICON — EduTrack Family
// Campana animada estilo YouTube: oscilación amortiguada al haber
// notificaciones no leídas. Badge rojo con contador en esquina.
// ═══════════════════════════════════════════════════════════════

class AnimatedBellIcon extends StatefulWidget {
  final int unread;
  final VoidCallback onTap;

  const AnimatedBellIcon({
    super.key,
    required this.unread,
    required this.onTap,
  });

  @override
  State<AnimatedBellIcon> createState() => _AnimatedBellIconState();
}

class _AnimatedBellIconState extends State<AnimatedBellIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _angle;
  int _prevUnread = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Oscilación amortiguada: la campana cuelga del punto superior
    // y oscila con amplitud decreciente hasta detenerse (como YouTube).
    _angle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.00, end: 0.28), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.28, end: -0.28), weight: 16),
      TweenSequenceItem(tween: Tween(begin: -0.28, end: 0.20), weight: 13),
      TweenSequenceItem(tween: Tween(begin: 0.20, end: -0.20), weight: 13),
      TweenSequenceItem(tween: Tween(begin: -0.20, end: 0.10), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.10, end: -0.10), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.10, end: 0.04), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0.00), weight: 12),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _prevUnread = widget.unread;
    if (widget.unread > 0) {
      // Pequeño delay al inicio para que el usuario vea la campana primero
      Future.delayed(const Duration(milliseconds: 600), _ring);
    }
  }

  @override
  void didUpdateWidget(AnimatedBellIcon old) {
    super.didUpdateWidget(old);
    // Anima cada vez que llega una notificación nueva
    if (widget.unread > _prevUnread && widget.unread > 0) {
      _ring();
    }
    _prevUnread = widget.unread;
  }

  void _ring() {
    if (mounted) _ctrl.forward(from: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: AnimatedBuilder(
            animation: _angle,
            builder: (_, child) => Transform.rotate(
              alignment: Alignment.topCenter,
              angle: _angle.value,
              child: child,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  widget.unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                  color: Colors.white,
                  size: 27,
                ),
                if (widget.unread > 0)
                  Positioned(
                    top: -5,
                    right: -6,
                    child: _NotifBadge(count: widget.unread),
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
// BADGE rojo estilo YouTube
// ─────────────────────────────────────────────────────────────
class _NotifBadge extends StatelessWidget {
  final int count;
  const _NotifBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final wide = count > 9; // pill en vez de círculo para 2+ dígitos

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 4.5 : 0,
        vertical: 1.5,
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
