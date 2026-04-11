import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Pour les vibrations
import 'dart:math'; // Pour l'animation pi
import '../services/anki_service.dart';
import '../models/question.dart';

class DailyReviewPage extends StatefulWidget {
  const DailyReviewPage({super.key});

  @override
  State<DailyReviewPage> createState() => _DailyReviewPageState();
}

class _DailyReviewPageState extends State<DailyReviewPage> {
  List<Question> _reviewList = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  // État pour savoir si la carte est retournée
  bool _isFlipped = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() { _isLoading = false; _finished = true; });
      return;
    }

    // Récupération des cartes dues
    List<Question> cards = await AnkiService.getDueCards(user.uid);

    if (mounted) {
      setState(() {
        _reviewList = cards;
        _isLoading = false;
      });
    }
  }

  void _submitReview(int quality) {
    // Feedback Haptique
    if (quality <= 1) {
      HapticFeedback.heavyImpact(); // Erreur / Dur
    } else {
      HapticFeedback.mediumImpact(); // Succès / Facile
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Question currentCard = _reviewList[_currentIndex];
    AnkiService.saveFlashcardReview(user.uid, currentCard, quality);

    setState(() {
      if (_currentIndex < _reviewList.length - 1) {
        _currentIndex++;
        _isFlipped = false; // Nouvelle carte -> Recto
      } else {
        _finished = true;
      }
    });
  }

  void _flipCard() {
    HapticFeedback.selectionClick();
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- COULEURS ---
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    Color appBarBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA);
    Color textColor = isDark ? Colors.white : Colors.black;
    Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    if (_isLoading) {
      return Scaffold(backgroundColor: scaffoldBg, body: const Center(child: CircularProgressIndicator()));
    }

    if (_reviewList.isEmpty) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(title: Text("Révision du jour", style: TextStyle(color: textColor)), backgroundColor: appBarBg, elevation: 0, iconTheme: IconThemeData(color: textColor)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text("Aucune carte à réviser !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Retour à l'accueil"))
            ],
          ),
        ),
      );
    }

    if (_finished) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(title: Text("Terminé", style: TextStyle(color: textColor)), backgroundColor: appBarBg, elevation: 0, iconTheme: IconThemeData(color: textColor)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
              const SizedBox(height: 20),
              Text("Session terminée !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),
              Text("${_reviewList.length} cartes révisées.", style: TextStyle(color: subTextColor)),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Retour"))
            ],
          ),
        ),
      );
    }

    final question = _reviewList[_currentIndex];
    double progress = (_currentIndex + 1) / _reviewList.length;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text("Carte ${_currentIndex + 1}/${_reviewList.length}", style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300], valueColor: const AlwaysStoppedAnimation(Colors.blue)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ZONE CARTE ANIMÉE
            Expanded(
              child: GestureDetector(
                onTap: _flipCard,
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: _isFlipped ? 1 : 0),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, double val, child) {
                    final angle = val * pi;
                    final isBack = val >= 0.5;

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective
                        ..rotateY(angle),
                      child: isBack
                          ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildCardBack(question, isDark),
                      )
                          : _buildCardFront(question, isDark),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            // BOUTONS DE RÉPONSE
            if (_isFlipped)
              Row(
                children: [
                  Expanded(child: _buildEvalButton("Oublié", Colors.red, 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildEvalButton("Dur", Colors.orange, 1)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildEvalButton("Bon", Colors.blue, 2)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildEvalButton("Facile", Colors.green, 3)),
                ],
              )
            else
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _flipCard,
                  icon: const Icon(Icons.rotate_right),
                  label: const Text("VOIR LA RÉPONSE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --- RECTO (QUESTION) ---
  Widget _buildCardFront(Question q, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(q.themeName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.5)),
          const SizedBox(height: 30),
          Text(q.questionText, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 30),
          Text("(Appuyez pour retourner)", style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black26, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // --- VERSO (RÉPONSE) ---
  Widget _buildCardBack(Question q, bool isDark) {
    bool hasOptions = q.options.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
      ),
      child: SingleChildScrollView( // Ajout du scroll au cas où la réponse est longue
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("RÉPONSE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.5)),
            const SizedBox(height: 20),

            // CAS 1 : QCM (Options disponibles)
            if (hasOptions) ...[
              ...List.generate(q.options.length, (index) {
                bool isCorrect = index == q.correctAnswerIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withValues(alpha: 0.2) : (isDark ? Colors.black12 : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: isCorrect ? Border.all(color: Colors.green) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isCorrect ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          q.options[index],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              if(q.explanation.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Text("Explication :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54)),
                const SizedBox(height: 5),
                Text(q.explanation, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, fontStyle: FontStyle.italic)),
              ]
            ]
            // CAS 2 : PAS DE QCM (Réponse directe ou Explication)
            else ...[
              // On affiche l'explication comme réponse principale
              Text(
                q.explanation.isNotEmpty ? q.explanation : "Réponse non disponible.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEvalButton(String label, Color color, int quality) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
      onPressed: () => _submitReview(quality),
      child: FittedBox(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
    );
  }
}