import 'package:flutter/material.dart';

class TeamTabBar extends StatelessWidget {
  final int viewMode;
  final bool isDark;
  final ValueChanged<int> onModeChanged;

  const TeamTabBar({
    super.key,
    required this.viewMode,
    required this.isDark,
    required this.onModeChanged,
  });

  Widget _buildTabButton(String text, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => onModeChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3b82f6) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected && !isDark
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
              : null,
        ),
        child: Center(
          child: Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.grey,
                  fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black45 : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(child: _buildTabButton("Classement", 1, viewMode == 1)),
          Expanded(child: _buildTabButton("Membres", 0, viewMode == 0)),
        ]),
      ),
    );
  }
}
