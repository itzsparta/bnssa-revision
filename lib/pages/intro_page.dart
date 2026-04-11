import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Pour accéder à AuthWrapper

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Couleurs dynamiques (Ajout de const pour la performance)
  final List<Color> _pageColors = const [
    Color(0xFF007AFF), // Bleu (QCM)
    Color(0xFFFF9F43), // Orange (Anki)
    Color(0xFF2ECC71), // Vert (Stats)
    Color(0xFF9B59B6), // Violet (Clans)
    Color(0xFFE74C3C), // Rouge (Formateur)
  ];

  Future<void> _finishIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenIntro', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    Color currentColor = _pageColors[_currentPage];

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. FOND DÉCORATIF
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicateurs de page
                      Row(
                        children: List.generate(5, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            height: 6,
                            width: _currentPage == index ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? currentColor : Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      // Bouton Passer
                      if (_currentPage < 4)
                        TextButton(
                          onPressed: _finishIntro,
                          child: const Text("Passer", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // 3. SLIDER CONTENU
                SizedBox(
                  height: 500,
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildPunchyPage(
                        title: "OBJECTIF 20/20 🎯",
                        subtitle: "QCM Officiels & Examen Blanc",
                        desc: "Ne perds pas de temps. Entraîne-toi sur les vraies questions de l'examen.",
                        visual: _buildMockQCMCard(isDark, _pageColors[0]),
                        isDark: isDark,
                      ),
                      _buildPunchyPage(
                        title: "MÉMOIRE TURBO 🚀",
                        subtitle: "Algorithme Intelligent",
                        desc: "L'appli détecte tes faiblesses et te fait réviser uniquement ce que tu oublies.",
                        visual: _buildMockAnkiInterface(isDark, _pageColors[1]),
                        isDark: isDark,
                      ),
                      _buildPunchyPage(
                        title: "ZÉRO DOUTE 📈",
                        subtitle: "Statistiques Précises",
                        desc: "Suis ta courbe de progression. Arrive le jour J avec une confiance totale.",
                        visual: _buildMockStatsGraph(isDark, _pageColors[2]),
                        isDark: isDark,
                      ),
                      _buildPunchyPage(
                        title: "L'UNION FAIT LA FORCE 🔥",
                        subtitle: "Clans & Classements",
                        desc: "Crée ton clan, défie tes potes et grimpe au sommet du classement !",
                        visual: _buildMockClanRanking(isDark, _pageColors[3]),
                        isDark: isDark,
                      ),
                      _buildPunchyPage(
                        title: "MODE FORMATEUR 🎓",
                        subtitle: "Suivi des Élèves",
                        desc: "Vous formez ? Visualisez les résultats de vos groupes en temps réel.",
                        visual: _buildMockInstructorSpace(isDark, _pageColors[4]),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 4. BOUTON ACTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentColor,
                        foregroundColor: Colors.white,
                        elevation: 10,
                        shadowColor: currentColor.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        if (_currentPage == 4) {
                          _finishIntro();
                        } else {
                          _controller.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.elasticOut);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getButtonText(_currentPage),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText(int page) {
    switch (page) {
      case 0: return "C'EST PARTI !";
      case 1: return "SUPER !";
      case 2: return "JE CONTINUE";
      case 3: return "JE REJOINS";
      case 4: return "GO MON BNSSA !";
      default: return "SUIVANT";
    }
  }

  Widget _buildPunchyPage({
    required String title,
    required String subtitle,
    required String desc,
    required Widget visual,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, double val, child) {
              return Transform.scale(scale: val, child: child);
            },
            child: SizedBox(height: 260, child: Center(child: visual)),
          ),

          const SizedBox(height: 40),

          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(subtitle.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 1.5)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(desc, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, height: 1.4, color: isDark ? Colors.white70 : Colors.black87)),
          ),
        ],
      ),
    );
  }

  // --- MOCKUPS VISUELS ---

  Widget _buildMockQCMCard(bool isDark, Color accent) {
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        width: 260, height: 200,
        decoration: _cardDeco(isDark, accent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _badge("QCM OFFICIEL", accent),
            const SizedBox(height: 25),
            _skeletonLine(180, isDark),
            const SizedBox(height: 10),
            _skeletonLine(140, isDark),
            const SizedBox(height: 25),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: accent, size: 28),
              const SizedBox(width: 10),
              _skeletonLine(100, isDark),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMockAnkiInterface(bool isDark, Color accent) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(angle: 0.05, child: Container(width: 240, height: 150, decoration: _cardDeco(isDark, Colors.grey))),
        Container(
          width: 240, height: 150,
          decoration: _cardDeco(isDark, accent),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flash_on_rounded, size: 50, color: accent),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _dot(Colors.red), _dot(Colors.orange), _dot(Colors.green),
              ])
            ],
          ),
        ),
      ],
    );
  }

  // CORRECTION ICI : Passage de Color au lieu de bool pour _bar
  Widget _buildMockStatsGraph(bool isDark, Color accent) {
    // On définit la couleur de base des barres selon le mode
    Color baseBarColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      width: 260, height: 200,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isDark, accent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bar(40, baseBarColor),
          _bar(70, baseBarColor),
          _bar(50, baseBarColor),
          _bar(100, accent), // La barre "Peak" prend la couleur accent
          _bar(80, baseBarColor),
          _bar(60, baseBarColor),
        ],
      ),
    );
  }

  Widget _buildMockClanRanking(bool isDark, Color accent) {
    return Container(
      width: 260, height: 220,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isDark, accent),
      child: Column(
        children: [
          Row(children: [const Icon(Icons.emoji_events, color: Colors.amber), const SizedBox(width: 10), Text("CLASSEMENT", style: TextStyle(fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black))]),
          const SizedBox(height: 20),
          _rankRow(1, "Team BNSSA", accent, isDark),
          const SizedBox(height: 15),
          _rankRow(2, "Les Requins", Colors.grey, isDark),
          const SizedBox(height: 15),
          _rankRow(3, "Sauveteurs", Colors.orange, isDark),
        ],
      ),
    );
  }

  Widget _buildMockInstructorSpace(bool isDark, Color accent) {
    return Container(
      width: 260, height: 200,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isDark, accent),
      child: Column(
        children: [
          _badge("GROUPE MARSEILLE", accent),
          const SizedBox(height: 25),
          _studentRow("Thomas", 0.9, Colors.green, isDark),
          const SizedBox(height: 15),
          _studentRow("Sarah", 0.4, Colors.red, isDark),
        ],
      ),
    );
  }

  // --- HELPER STYLES ---

  BoxDecoration _cardDeco(bool isDark, Color borderCol) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: borderCol.withValues(alpha: 0.3), width: 2),
      boxShadow: [BoxShadow(color: borderCol.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
    );
  }

  Widget _badge(String text, Color col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
  );

  Widget _skeletonLine(double w, bool isDark) => Container(
    height: 10, width: w,
    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(5)),
  );

  Widget _dot(Color c) => Container(width: 15, height: 15, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  // CORRECTION ICI : _bar prend maintenant une Couleur (Color c)
  Widget _bar(double h, Color c) => Container(
    width: 15, height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
  );

  Widget _rankRow(int r, String n, Color c, bool isDark) => Row(children: [
    CircleAvatar(radius: 12, backgroundColor: c.withValues(alpha: 0.2), child: Text("$r", style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold))),
    const SizedBox(width: 10),
    Text(n, style: TextStyle(fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black)),
  ]);

  Widget _studentRow(String n, double p, Color c, bool isDark) => Row(children: [
    Text(n, style: TextStyle(fontSize: 12, color: isDark?Colors.white:Colors.black)),
    const SizedBox(width: 10),
    Expanded(child: LinearProgressIndicator(value: p, color: c, backgroundColor: isDark?Colors.white10:Colors.grey[100], minHeight: 8, borderRadius: BorderRadius.circular(4))),
  ]);
}