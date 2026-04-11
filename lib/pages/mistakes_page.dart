import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/mistakes_service.dart';
import '../services/team_service.dart';

class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});

  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  List<Question> _mistakes = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  bool _answered = false;
  int? _selectedOption;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    List<Question> loaded = await MistakesService.getMistakes();
    loaded.shuffle();

    if (mounted) {
      setState(() {
        _mistakes = loaded;
        _isLoading = false;
      });
    }
  }

  void _submitAnswer(int index) {
    if (_answered) {
      return;
    }

    setState(() {
      _answered = true;
      _selectedOption = index;
    });

    Question currentQ = _mistakes[_currentIndex];
    bool correct = (index == currentQ.correctAnswerIndex);

    if (correct) {
      setState(() => _isCorrect = true);
      TeamService().updateUserScoreInTeam(1);
      MistakesService.removeMistake(currentQ.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Bien joué ! +1 Point pour le Clan 🛡️"),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1500),
        ));
      }
    } else {
      setState(() => _isCorrect = false);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _mistakes.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
        _isCorrect = false;
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session de rattrapage terminée !")));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_mistakes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Rattrapage")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text("Aucune erreur à rattraper !",
                  style: TextStyle(
                      fontSize: 18,
                      color: textColor,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("C'est propre, beau travail.",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final q = _mistakes[_currentIndex];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: Text("Rattrapage (${_currentIndex + 1}/${_mistakes.length})"),
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.5))),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          "Une seule chance ! Réussis pour gagner 1 pt Clan et effacer l'erreur.",
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(q.questionText,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 15),
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(q.imageUrl!,
                      height: 180, fit: BoxFit.cover)),
            ],
            const SizedBox(height: 30),
            ...List.generate(q.options.length, (index) {
              Color btnColor = cardColor;
              Color borderColor = Colors.transparent;
              IconData? icon;

              if (_answered) {
                if (index == q.correctAnswerIndex) {
                  btnColor = Colors.green.withValues(alpha: 0.2);
                  borderColor = Colors.green;
                  icon = Icons.check_circle;
                } else if (index == _selectedOption &&
                    index != q.correctAnswerIndex) {
                  btnColor = Colors.red.withValues(alpha: 0.2);
                  borderColor = Colors.red;
                  icon = Icons.cancel;
                } else if (_selectedOption != null &&
                    index != q.correctAnswerIndex) {
                  btnColor = cardColor.withValues(alpha: 0.5);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _submitAnswer(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _answered && index == q.correctAnswerIndex
                                ? Colors.green
                                : borderColor,
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(q.options[index],
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor))),
                        if (icon != null) Icon(icon, color: borderColor),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_answered) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: _isCorrect
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isCorrect ? Colors.green : Colors.red)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isCorrect ? "Rattrapé ! 🎉" : "Encore raté... 😕",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isCorrect ? Colors.green : Colors.red,
                            fontSize: 16)),
                    const SizedBox(height: 5),
                    Text(
                        q.explanation.isEmpty
                            ? "Pas d'explication."
                            : q.explanation,
                        style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _nextQuestion,
                child: Text(
                    _currentIndex < _mistakes.length - 1
                        ? "ERREUR SUIVANTE"
                        : "TERMINER",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
