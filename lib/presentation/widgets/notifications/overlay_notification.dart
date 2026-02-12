import 'package:flutter/material.dart';

enum NotificationType { success, error, warning, info, deleted }

class OverlayNotification {
  static OverlayEntry? _currentEntry; // ✅ Para evitar superposiciones

  static void show({
    required BuildContext context,
    required String message,
    required NotificationType type,
    required Duration duration,
  }) {
    // ✅ Si ya hay una notificación, la quitamos inmediatamente
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }

    final overlayState = Overlay.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationAnimatedWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          if (_currentEntry != null) {
            _currentEntry!.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    overlayState.insert(_currentEntry!);
  }
}

class _NotificationAnimatedWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationAnimatedWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_NotificationAnimatedWidget> createState() => _NotificationAnimatedWidgetState();
}

class _NotificationAnimatedWidgetState extends State<_NotificationAnimatedWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // ✅ Configuración de la animación
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5), // Empieza fuera de la pantalla (Arriba)
      end: Offset.zero,               // Termina en su posición natural
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Efecto de rebote elegante
    ));

    _controller.forward(); // Iniciar animación de entrada

    // ✅ Iniciar el temporizador para salida
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((value) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;
    
    switch (widget.type) {
      case NotificationType.success:
        iconColor = const Color(0xFF22C55E);
        iconData = Icons.check;
        break;
      case NotificationType.error:
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.close;
        break;
      case NotificationType.deleted:
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.delete_outline;
        break;
      case NotificationType.warning:
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.priority_high;
        break;
      case NotificationType.info:
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.info_outline;
        break;
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition( // ✅ Animación de deslizamiento
          position: _offsetAnimation,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1C),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                      child: Icon(iconData, color: Colors.black, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}