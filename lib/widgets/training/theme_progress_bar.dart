import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/theme_service.dart';
import '../../services/user_service.dart';

class ThemeProgressBar extends StatelessWidget {
  final String themeId;
  final String userId;
  final bool isDark;

  const ThemeProgressBar({
    super.key,
    required this.themeId,
    required this.userId,
    required this.isDark,
  });

  // Cache statique : le nombre de questions par thème ne change jamais en cours de session.
  // Évite N requêtes aggregate à chaque rebuild de la liste.
  static final Map<String, Future<int>> _countCache = {};

  static Future<int> _getQuestionCount(String themeId) =>
      _countCache.putIfAbsent(themeId, () => ThemeService().getThemeQuestionCount(themeId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _getQuestionCount(themeId),
      builder: (context, totalSnap) {
        if (!totalSnap.hasData) {
          return SizedBox(
            height: 6.0,
            child: LinearProgressIndicator(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              backgroundColor: Colors.transparent,
            ),
          );
        }
        final int total = totalSnap.data!;
        if (total == 0) return const SizedBox();

        return StreamBuilder<DocumentSnapshot>(
          stream: UserService().themeStatStream(userId, themeId),
          builder: (context, userSnap) {
            int correctCount = 0;
            if (userSnap.hasData && userSnap.data!.exists) {
              final data = userSnap.data!.data() as Map<String, dynamic>;
              correctCount = data['correct_ids'] is List
                  ? (data['correct_ids'] as List).length
                  : (data['correct_count'] ?? 0);
            }
            final double progress = (correctCount / total).clamp(0.0, 1.0);
            return Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6.0,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    color: progress == 1.0 ? Colors.green : Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.grey[600]),
              ),
            ]);
          },
        );
      },
    );
  }
}
