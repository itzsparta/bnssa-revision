import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  // --- CONTENU COMPLET (5 Piliers) ---
  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Bienvenue Sauveteur",
      "desc": "L'outil ultime pour réussir ton BNSSA. Prépare-toi efficacement et suis ta progression jour après jour.",
      "icon": Icons.pool,
      "color": Colors.blue
    },
    {
      "title": "Entraînement Ciblé",
      "desc": "Accède à des centaines de QCM classés par thèmes officiels (Secourisme, Réglementation, Météo...).",
      "icon": Icons.quiz,
      "color": Colors.orange
    },
    {
      "title": "Mémoire & IA (Anki)",
      "desc": "Ne perds plus de temps. Notre algorithme intelligent te fait réviser uniquement ce que tu es sur le point d'oublier.",
      "icon": Icons.psychology,
      "color": Colors.purple
    },
    {
      "title": "Esprit d'Équipe",
      "desc": "Rejoins un Clan avec le code de ton club. Compare tes scores et motive-toi avec ta promo.",
      "icon": Icons.groups,
      "color": Colors.redAccent
    },
    {
      "title": "Mode Examen",
      "desc": "Mets-toi en conditions réelles : 40 questions, temps limité. Seras-tu prêt le jour J ?",
      "icon": Icons.timer,
      "color": Colors.green
    },
  ];

  Future<void> _finishOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen', true); // On enregistre que c'est vu

    if (!mounted) return;
    Navigator.of(context).pop(); // On ferme la page pour revenir à l'appli
  }

  @override
  Widget build(BuildContext context) {
    bool isLastPage = _currentIndex == _pages.length - 1;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- BOUTON PASSER ---
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: const Text("PASSER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ),

            // --- CARROUSEL ---
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: _pages[index]['color'].withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _pages[index]['icon'],
                            size: 80,
                            color: _pages[index]['color'],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _pages[index]['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _pages[index]['desc'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // --- INDICATEURS & BOUTONS ---
            Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Points de progression
                  Row(
                    children: List.generate(
                      _pages.length,
                          (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 5),
                        height: 8,
                        width: _currentIndex == index ? 25 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),

                  // Bouton Suivant / Terminer
                  ElevatedButton(
                    onPressed: () {
                      if (isLastPage) {
                        _finishOnboarding();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastPage ? Colors.blue : Colors.grey[200],
                      foregroundColor: isLastPage ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      isLastPage ? "C'EST PARTI !" : "SUIVANT",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}