import 'package:flutter/material.dart';
import '../../data/auth_service.dart';

class RoleCard extends StatelessWidget {
  final UserRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFarmer = role == UserRole.farmer;
    final letter = isFarmer ? 'F' : 'E';
    final title = isFarmer ? 'Farmer' : 'Exporter';
    final avatarColor = isFarmer ? const Color(0xFF266E4E) : const Color(0xFFE5A93C);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF4F9F5) : const Color(0xFFFAFBFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF20583E) : Colors.grey.shade300,
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF20583E).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular avatar with dotted style border
              CustomPaint(
                painter: _DottedCirclePainter(
                  color: isSelected ? avatarColor : Colors.grey.shade400,
                  dotCount: 22,
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? avatarColor.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? avatarColor : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF1B2A21) : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  final int dotCount;

  _DottedCirclePainter({required this.color, this.dotCount = 20});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dotted circle
    const dashLength = 4.0;
    const dashSpace = 3.5;
    final circumference = 2 * 3.1415926535 * radius;
    final count = (circumference / (dashLength + dashSpace)).floor();

    for (int i = 0; i < count; i++) {
      final startAngle = (i * (dashLength + dashSpace)) / radius;
      final sweepAngle = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dotCount != dotCount;
}
