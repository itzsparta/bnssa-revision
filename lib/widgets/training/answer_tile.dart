import 'package:flutter/material.dart';

class AnswerTile extends StatelessWidget {
  final int index;
  final String text;
  final int correctIndex;
  final bool isDark;
  final bool isSelected;
  final bool showResult;
  final VoidCallback? onTap;

  const AnswerTile({
    super.key,
    required this.index,
    required this.text,
    required this.correctIndex,
    required this.isDark,
    required this.isSelected,
    required this.showResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = index == correctIndex;

    Color borderColor = Colors.grey.withValues(alpha: 0.3);
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    IconData? icon;

    if (showResult) {
      if (isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green[700] ?? Colors.green;
        icon = Icons.check_circle;
      } else if (isSelected) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red[700] ?? Colors.red;
        icon = Icons.cancel;
      } else {
        textColor = Colors.grey;
      }
    } else if (isSelected) {
      borderColor = Colors.blueAccent;
      bgColor = Colors.blue.withValues(alpha: 0.1);
      textColor = Colors.blueAccent;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected || (showResult && isCorrect) ? 2 : 1,
          ),
          boxShadow: [
            if (!showResult)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: (isSelected || (showResult && isCorrect))
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, color: textColor),
            ] else if (!showResult) ...[
              const SizedBox(width: 10),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.grey.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  color: isSelected ? Colors.blueAccent : null,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
