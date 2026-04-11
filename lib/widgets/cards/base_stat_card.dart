import 'package:flutter/material.dart';

class BaseStatCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const BaseStatCard({
    super.key,
    required this.title,
    required this.child,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey[800],
                ),
              ),
            ),
            Expanded(child: Center(child: child)),
          ],
        ),
      ),
    );
  }
}