import 'dart:async';
import 'package:flutter/material.dart';

OverlayEntry? _activeToastEntry;
_AnimatedToastState? _activeToastState;

/// Shows a custom animated toast that slides in from bottom to top,
/// and slides out from top to bottom on dismiss.
/// Matches the curved-box UI shown in the user's design.
void showAnimatedToast(
  BuildContext context, {
  required Widget content,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  Color? actionColor,
  VoidCallback? onAction,
  bool showClose = true,
  double bottomOffset = 16.0,
}) {
  // If a toast is currently active, dismiss it immediately before showing new one
  if (_activeToastState != null && _activeToastState!.mounted) {
    _activeToastState!.dismissImmediately();
  }
  if (_activeToastEntry != null && _activeToastEntry!.mounted) {
    _activeToastEntry!.remove();
  }
  _activeToastEntry = null;
  _activeToastState = null;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _AnimatedToast(
      content: content,
      duration: duration,
      actionLabel: actionLabel,
      actionColor: actionColor,
      onAction: onAction,
      showClose: showClose,
      bottomOffset: bottomOffset,
      onDismiss: () {
        if (entry.mounted) {
          entry.remove();
        }
        if (_activeToastEntry == entry) {
          _activeToastEntry = null;
          _activeToastState = null;
        }
      },
      onStateCreated: (state) {
        _activeToastState = state;
      },
    ),
  );

  _activeToastEntry = entry;
  overlay.insert(entry);
}

class _AnimatedToast extends StatefulWidget {
  final Widget content;
  final Duration duration;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onAction;
  final bool showClose;
  final double bottomOffset;
  final VoidCallback onDismiss;
  final ValueChanged<_AnimatedToastState> onStateCreated;

  const _AnimatedToast({
    required this.content,
    required this.duration,
    required this.onDismiss,
    required this.onStateCreated,
    this.actionLabel,
    this.actionColor,
    this.onAction,
    this.showClose = true,
    this.bottomOffset = 16.0,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Slide in from bottom to top: Offset(0, 1.25) -> Offset.zero
    // Slide out from top to bottom: Offset.zero -> Offset(0, 1.25)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        reverseCurve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _autoTimer = Timer(widget.duration, dismiss);
  }

  void dismissImmediately() {
    _autoTimer?.cancel();
    _dismissed = true;
    if (mounted) {
      widget.onDismiss();
    }
  }

  Future<void> dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _autoTimer?.cancel();
    if (!mounted) {
      widget.onDismiss();
      return;
    }
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Curved box styling matching the user's reference image
    final Color bgColor = isDark ? const Color(0xFFE5ECE4) : const Color(0xFF1E293B);
    final Color closeIconColor = isDark ? const Color(0xFF64748B) : Colors.white70;

    return Positioned(
      bottom: mediaQuery.padding.bottom + mediaQuery.viewInsets.bottom + widget.bottomOffset,
      left: 16,
      right: 16,
      child: RepaintBoundary(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 80) {
                    dismiss();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: widget.content),
                      if (widget.actionLabel != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            widget.onAction?.call();
                            dismiss();
                          },
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              color: widget.actionColor ?? const Color(0xFFD97706),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      if (widget.showClose) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: closeIconColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          splashRadius: 16,
                          onPressed: dismiss,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
