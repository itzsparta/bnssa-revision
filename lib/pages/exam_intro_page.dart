import 'package:flutter/material.dart';
import '../utils/page_transition.dart';
import 'exam_page.dart';

class ExamIntroPage extends StatelessWidget {
  const ExamIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Détection du mode sombre
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Définition des couleurs dynamiques
    Color backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color subTextColor = isDark ? Colors.white70 : Colors.black87;
    Color cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, size: 60, color: Colors.purple),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Examen Blanc",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
            ),
            const SizedBox(height: 10),
            Text(
              "Mettez-vous en conditions réelles. L'examen officiel du QCM BNSSA suit ces règles strictes.",
              style: TextStyle(fontSize: 16, color: subTextColor, height: 1.5),
            ),
            const SizedBox(height: 30),

            // --- RÈGLES OFFICIELLES ---
            _buildRuleItem(
                Icons.quiz,
                "40 Questions (Officielles)",
                // Liste concise des 6 parties
                "Répartition en 6 thèmes : Milieu, Diplômes, Admin, Sécurité, Surveillance, Secours.",
                Colors.blue,
                textColor,
                subTextColor,
                cardColor
            ),
            const SizedBox(height: 20),
            _buildRuleItem(
                Icons.timer,
                "45 Minutes",
                "Temps officiel. L'examen s'arrête à 0.",
                Colors.orange,
                textColor,
                subTextColor,
                cardColor
            ),
            const SizedBox(height: 20),
            _buildRuleItem(
                Icons.warning_amber,
                "Moins de 10 fautes",
                "Vous devez avoir au moins 30/40 pour réussir.",
                Colors.red,
                textColor,
                subTextColor,
                cardColor
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                onPressed: () {
                  // On remplace la page actuelle pour qu'on ne puisse pas faire "Retour" pendant l'examen
                  Navigator.pushReplacement(context, SlideRightRoute(page: const ExamPage()));
                },
                child: const Text(
                  "COMMENCER L'ÉPREUVE",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String title, String subtitle, Color iconColor, Color titleColor, Color subColor, Color bgCard) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: subColor, fontSize: 13, height: 1.2)),
            ],
          ),
        )
      ],
    );
  }
}