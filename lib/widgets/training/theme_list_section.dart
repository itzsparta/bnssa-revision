import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

import 'theme_progress_bar.dart';

class ThemeListSection extends StatelessWidget {
  final String? userId;
  final bool isPremium;
  final List<dynamic> unlockedThemes;
  final void Function(String themeId, String themeTitle) onStartTheme;
  final void Function(String themeId, String themeTitle, int cost) onUnlockTheme;

  const ThemeListSection({
    super.key,
    required this.userId,
    required this.isPremium,
    required this.unlockedThemes,
    required this.onStartTheme,
    required this.onUnlockTheme,
  });

  IconData _getIconForTheme(Map<String, dynamic> data) {
    final String iconField = (data['icon'] ?? '').toString().toLowerCase().trim();
    if (iconField.isNotEmpty) {
      if (iconField.contains('pool') || iconField.contains('swim')) {
        return Icons.pool;
      }
      if (iconField.contains('medic') || iconField.contains('health')) {
        return Icons.medical_services;
      }
      if (iconField.contains('gavel') || iconField.contains('law')) {
        return Icons.gavel;
      }
      if (iconField.contains('boat') || iconField.contains('ship')) {
        return Icons.directions_boat;
      }
      if (iconField.contains('alert') || iconField.contains('warning')) {
        return Icons.warning_amber_rounded;
      }
    }
    final String t = (data['title'] ?? '').toString().toLowerCase();
    if (t.contains('mer') || t.contains('marin') || t.contains('côtier') || t.contains('navig')) {
      return Icons.sailing;
    }
    if (t.contains('bateau') || t.contains('embarcation')) { return Icons.directions_boat; }
    if (t.contains('météo') || t.contains('vent') || t.contains('nuage')) { return Icons.cloud; }
    if (t.contains('radio') || t.contains('vhe') || t.contains('crr')) { return Icons.radio; }
    if (t.contains('signal') || t.contains('balisage')) { return Icons.flag; }
    if (t.contains('droit') || t.contains('règle') || t.contains('regle') || t.contains('loi') || t.contains('juridique')) {
      return Icons.gavel;
    }
    if (t.contains('secour') || t.contains('pse') || t.contains('soin') || t.contains('pansement') || t.contains('urgence')) {
      return Icons.medical_services;
    }
    if (t.contains('technique') || t.contains('nage') || t.contains('natation') || t.contains('piscine') || t.contains('eau')) {
      return Icons.pool;
    }
    if (t.contains('apnée') || t.contains('plongée')) { return Icons.scuba_diving; }
    if (t.contains('qcm') || t.contains('exam') || t.contains('test') || t.contains('quiz')) {
      return Icons.quiz;
    }
    if (t.contains('annale') || t.contains('sujet')) { return Icons.library_books; }
    return Icons.school;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Column(children: [
      const Padding(
        padding: EdgeInsets.only(left: 20, top: 15, bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text("Thèmes d'entraînement",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey)),
        ),
      ),
      FutureBuilder(
        future: ThemeService().getAllThemes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final themes = snapshot.data!.docs
              .where((doc) => doc.id.startsWith('theme_'))
              .toList();
          if (themes.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Aucun thème disponible."));
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final data = themes[index].data() as Map<String, dynamic>;
              final String themeId = themes[index].id;
              final bool isPremiumTheme = data['is_premium'] ?? false;
              final bool isUnlocked = unlockedThemes.contains(themeId) || isPremium;
              final bool isLocked = isPremiumTheme && !isUnlocked;
              final int unlockCost = data['unlock_cost'] ?? 20;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isLocked
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100])
                      : cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isLocked
                      ? []
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (isLocked) {
                        onUnlockTheme(themeId, data['title'] ?? 'Thème', unlockCost);
                      } else {
                        onStartTheme(themeId, data['title'] ?? '');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 15),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: isLocked
                                ? null
                                : LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.blue.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                            color: isLocked
                                ? Colors.grey.withValues(alpha: 0.1)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLocked ? Icons.lock : _getIconForTheme(data),
                            color: isLocked ? Colors.grey : Colors.blue[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? 'Thème',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isLocked ? Colors.grey : textColor)),
                              const SizedBox(height: 4),
                              Text(
                                isLocked
                                    ? "Verrouillé • $unlockCost Crédits"
                                    : (isPremium ? "ILLIMITÉ" : "1 Crédit"),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLocked
                                      ? Colors.redAccent
                                      : (isDark
                                          ? Colors.white60
                                          : Colors.grey[600]),
                                  fontWeight: isLocked
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              if (userId != null && !isLocked) ...[
                                const SizedBox(height: 8),
                                ThemeProgressBar(
                                    themeId: themeId,
                                    userId: userId!,
                                    isDark: isDark),
                              ]
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: isLocked
                                ? Colors.grey.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.5)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ]);
  }
}
