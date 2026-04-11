import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import '../models/question.dart';
import '../services/anki_service.dart';
import '../services/mistakes_service.dart';
import '../services/stats_service.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> with TickerProviderStateMixin {
  // --- ÉTATS ---
  List<Question> _questions = [];
  final Map<int, int> _userAnswers = {};

  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _loadingText = "Ouverture des sujets...";

  bool _isSubmitting = false;
  bool _showResult = false;

  int _finalFaults = 0;
  bool _finalPassed = false;
  bool _finalTimeOut = false;

  bool _enableHaptic = true;

  Timer? _timer;
  int _remainingSeconds = 45 * 60; // 45 minutes

  // --- NOUVELLE RÉPARTITION OFFICIELLE (Total 40) ---
  // Basée sur votre document : Min/Max respectés.
  final Map<String, int> _officialQuotas = {
    'part_1': 7, // Milieu (Min 6 - Max 10)
    'part_2': 7, // Diplômes/Loi (Min 6 - Max 10)
    'part_3': 7, // Admin (Min 5 - Max 10)
    'part_4': 7, // Sécurité (Min 5 - Max 8)
    'part_5': 7, // Surveillance (Min 5 - Max 8)
    'part_6': 5, // Secourisme (Min 3 - Max 5)
  };

  @override
  void initState() {
    super.initState();
    // CORRECTION : On lance le chargement, mais PAS le timer tout de suite
    Future.delayed(const Duration(milliseconds: 300), () {
      _loadExam();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            if (!_isSubmitting && !_showResult) {
              _submitExam(timeOut: true);
            }
          }
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // --- DÉTECTION INTELLIGENTE DES PARTIES ---
  String _detectCategory(String themeTitle) {
    String t = themeTitle.toLowerCase();

    // Partie 6 : Secourisme (Prioritaire)
    if (t.contains('secour') || t.contains('pse') || t.contains('accident') || t.contains('noyade') || t.contains('urgence') || t.contains('soin') || t.contains('vital')) {
      return 'part_6';
    }
    // Partie 1 : Connaissance du Milieu
    if (t.contains('météo') || t.contains('meteo') || t.contains('vent') || t.contains('mer') || t.contains('ocean') || t.contains('plage') || t.contains('hydro') || t.contains('environnement') || t.contains('bateau') || t.contains('marée')) {
      return 'part_1';
    }
    // Partie 4 : Organisation Sécurité
    if (t.contains('balisage') || t.contains('zone') || t.contains('drapeau') || t.contains('signal') || t.contains('chenal') || t.contains('material')) {
      return 'part_4';
    }
    // Partie 5 : Surveillance & Activités
    if (t.contains('activit') || t.contains('surveillance') || t.contains('nautique') || t.contains('voile') || t.contains('surf') || t.contains('kite') || t.contains('jet') || t.contains('conduite')) {
      return 'part_5';
    }
    // Partie 3 : Organisation Administrative
    if (t.contains('admin') || t.contains('organi') || t.contains('maire') || t.contains('préfet') || t.contains('prefet') || t.contains('commune') || t.contains('etat') || t.contains('poste')) {
      return 'part_3';
    }
    // Partie 2 : Diplômes & Obligations (Par défaut si rien d'autre, souvent "Réglementation" générique)
    if (t.contains('diplôme') || t.contains('diplome') || t.contains('compétence') || t.contains('obligation') || t.contains('juridique') || t.contains('civil') || t.contains('pénal') || t.contains('penal') || t.contains('loi') || t.contains('decret') || t.contains('arrêté')) {
      return 'part_2';
    }

    // Fallback : Si on ne sait pas, on met dans "Réglementation" (Partie 2)
    return 'part_2';
  }

  Future<void> _loadExam() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      bool isPremium = false;
      if (user != null) {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) isPremium = userDoc.data()?['isPremium'] ?? false;
      }

      // Initialisation des paniers
      Map<String, List<Question>> buckets = {
        'part_1': [], 'part_2': [], 'part_3': [],
        'part_4': [], 'part_5': [], 'part_6': []
      };

      var themes = await FirebaseFirestore.instance.collection('themes').get();
      int totalThemes = themes.docs.length;

      for (int i = 0; i < totalThemes; i++) {
        var theme = themes.docs[i];
        String themeTitle = theme['title'] ?? '';
        String category = _detectCategory(themeTitle);

        if (mounted) {
          setState(() {
            _loadingProgress = (i + 1) / (totalThemes + 1);
            _loadingText = "Tri : $themeTitle...";
          });
        }

        var qSnap = await theme.reference.collection('questions').limit(50).get();
        for (var d in qSnap.docs) {
          Map<String, dynamic> data = d.data();
          if (!isPremium && (data['isPremium'] ?? false)) continue;
          buckets[category]?.add(Question.fromFirestore(d, theme: themeTitle));
        }
      }

      if (mounted) setState(() { _loadingText = "Génération de l'épreuve..."; _loadingProgress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 500));

      List<Question> finalExam = [];

      // Tirage selon quotas officiels
      _officialQuotas.forEach((part, quota) {
        List<Question>? available = buckets[part];
        if (available != null && available.isNotEmpty) {
          available.shuffle();
          finalExam.addAll(available.take((available.length < quota) ? available.length : quota));
        }
      });

      // Si pas assez de questions, on complète avec le reste (fallback)
      if (finalExam.length < 40) {
        List<Question> leftovers = [];
        buckets.forEach((key, list) { leftovers.addAll(list); });
        Set<String> existingIds = finalExam.map((q) => q.id).toSet();
        leftovers.removeWhere((q) => existingIds.contains(q.id));
        leftovers.shuffle();
        int needed = 40 - finalExam.length;
        finalExam.addAll(leftovers.take(needed));
      }

      finalExam.shuffle();

      if (mounted) {
        setState(() {
          _questions = finalExam;
          _isLoading = false;
        });
        // CORRECTION : Le timer démarre SEULEMENT maintenant
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectAnswer(int questionIndex, int optionIndex) {
    _triggerFeedback(isSelection: true);
    setState(() {
      _userAnswers[questionIndex] = optionIndex;
    });
  }

  void _triggerFeedback({bool isSelection = false, bool isSuccess = false, bool isFailure = false}) {
    if (!_enableHaptic) return;

    // Plus besoin de vérifier "canVibrate", Flutter le fait tout seul.

    if (isSelection) {
      HapticFeedback.selectionClick();
    } else if (isSuccess) {
      HapticFeedback.lightImpact();
    } else if (isFailure) {
      HapticFeedback.heavyImpact(); // Vibration plus lourde pour l'échec
    }
  }

  void _submitExam({bool timeOut = false}) async {
    // --- CORRECTION ANTI-DOUBLON ---
    if (_isSubmitting || _showResult) return;
    // -----------------------------

    _timer?.cancel();
    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(milliseconds: 600));

    int faults = 0;
    int successCount = 0;
    final user = FirebaseAuth.instance.currentUser;

    List<Map<String, dynamic>> examDetails = [];
    List<Future> asyncTasks = [];

    for (int i = 0; i < _questions.length; i++) {
      Question q = _questions[i];
      int? userAnswer = _userAnswers[i];
      bool isCorrect = (userAnswer != null && userAnswer == q.correctAnswerIndex);

      if (isCorrect) {
        successCount++;
      } else {
        faults++;
        asyncTasks.add(MistakesService.addMistake(q));
      }

      String userRespString = (userAnswer != null && userAnswer < q.options.length) ? q.options[userAnswer] : "Aucune réponse";
      String correctRespString = (q.correctAnswerIndex < q.options.length) ? q.options[q.correctAnswerIndex] : "?";

      examDetails.add({
        'questionText': q.questionText,
        'userAnswer': userRespString,
        'correctAnswer': correctRespString,
        'isCorrect': isCorrect,
        'explanation': q.explanation,
      });

      if (user != null) {
        asyncTasks.add(AnkiService.saveFlashcardReview(user.uid, q, isCorrect ? 3 : 1));
      }
    }

    if (asyncTasks.isNotEmpty) await Future.wait(asyncTasks);

    bool isPassed = faults < 10; // Moins de 10 fautes = Réussite

    if (user != null) {
      await StatsService.saveExamResult(user.uid, successCount, _questions.length, isPassed, examDetails);
    }

    if (mounted) {
      _triggerFeedback(isSuccess: isPassed, isFailure: !isPassed);
      setState(() {
        _isSubmitting = false;
        _finalFaults = faults;
        _finalPassed = isPassed;
        _finalTimeOut = timeOut;
        _showResult = true;
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Row(children: [Icon(Icons.tune), SizedBox(width: 10), Text("Options")]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vibration),
                            SizedBox(width: 15),
                            Text("Vibrations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Switch(
                          value: _enableHaptic,
                          onChanged: (val) {
                            setDialogState(() => _enableHaptic = val);
                            setState(() {});
                            if(val) HapticFeedback.heavyImpact();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
              ],
            );
          },
        );
      },
    );
  }

  // --- INTERFACE ---
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeInOut,
            child: _isLoading ? _buildLoadingView() : _buildExamView(),
          ),
        ),

        if (_isSubmitting)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4 * value),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          const SizedBox(height: 20),
                          Material(
                            color: Colors.transparent,
                            child: Text(
                                "Correction en cours...",
                                style: TextStyle(color: Colors.white.withValues(alpha: value), fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        if (_showResult)
          Positioned.fill(
            child: _buildResultOverlay(),
          ),
      ],
    );
  }

  Widget _buildResultOverlay() {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ),

        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: Opacity(opacity: value.clamp(0.0, 1.0), child: child));
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: _finalPassed ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(_finalPassed ? Icons.emoji_events_rounded : Icons.cancel_rounded, size: 60, color: _finalPassed ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 20),
                    Text(_finalTimeOut ? "TEMPS ÉCOULÉ" : (_finalPassed ? "ADMIS !" : "AJOURNÉ"), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _finalPassed ? Colors.green : Colors.red, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Text("Score : ${40 - _finalFaults} / 40", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("$_finalFaults fautes commises", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(10)),
                      child: Text(_finalPassed ? "Félicitations ! Vous respectez les quotas du BNSSA. Continuez comme ça !" : "Il faut faire moins de 10 fautes pour réussir l'examen. Ne lâchez rien !", textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _finalPassed ? Colors.green : Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Quitter l'examen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text("Retrouvez le corrigé complet dans votre Profil.", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1), shape: BoxShape.circle), child: const Icon(Icons.school_rounded, size: 60, color: Colors.blue)),
              const SizedBox(height: 40),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _loadingProgress),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, _) => ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], color: Colors.blueAccent)),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(_loadingText, key: ValueKey<String>(_loadingText), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamView() {
    if (_questions.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text("Erreur génération.")));
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    int answeredCount = _userAnswers.length;
    Color timerColor = _remainingSeconds < 300 ? Colors.red : Colors.blue[800]!;
    if (isDark && _remainingSeconds >= 300) timerColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Examen Blanc", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: timerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: timerColor.withValues(alpha: 0.5))),
            child: Row(children: [Icon(Icons.timer_outlined, size: 18, color: timerColor), const SizedBox(width: 5), Text(_formatTime(_remainingSeconds), style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontFamily: "monospace"))]),
          ),
          IconButton(icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87), onPressed: _showSettingsDialog),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: (answeredCount == _questions.length && !_isSubmitting && !_showResult)
          ? FloatingActionButton.extended(onPressed: () => _submitExam(), label: const Text("Valider"), icon: const Icon(Icons.check), backgroundColor: Colors.green)
          : null,
      body: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: 0, end: answeredCount / _questions.length),
            builder: (context, value, _) => LinearProgressIndicator(value: value, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], color: Colors.blue, minHeight: 4),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _questions.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 30),
              itemBuilder: (context, index) {
                if (index == _questions.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 80, top: 20),
                    child: SizedBox(height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2), onPressed: (_isSubmitting || _showResult) ? null : () => _submitExam(), child: Text("TERMINER L'ÉPREUVE ($answeredCount/40)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  );
                }
                return _buildQuestionCard(index, _questions[index], isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Question q, bool isDark) {
    bool isAnswered = _userAnswers.containsKey(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: isAnswered ? Colors.blue : (isDark ? Colors.grey[700] : Colors.grey[300]), shape: BoxShape.circle), child: Text("${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, color: isAnswered ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700])))), const SizedBox(width: 10), Text(q.themeName.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800]))]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))], border: isAnswered ? Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1) : null),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[const SizedBox(height: 15), ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(q.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover))],
            const SizedBox(height: 15), const Divider(height: 1), const SizedBox(height: 10),
            ...List.generate(q.options.length, (optIndex) {
              bool isSelected = _userAnswers[index] == optIndex;
              return _buildOption(index, optIndex, q.options[optIndex], isSelected, isDark);
            }),
          ]),
        ),
      ],
    );
  }

  Widget _buildOption(int qIndex, int optIndex, String text, bool isSelected, bool isDark) {
    Color bgColor = isSelected ? Colors.blue.withValues(alpha: 0.1) : (isDark ? Colors.grey[800]! : Colors.grey[100]!);
    Color borderColor = isSelected ? Colors.blue : Colors.transparent;
    return GestureDetector(
      onTap: (_isSubmitting || _showResult) ? null : () => _selectAnswer(qIndex, optIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor, width: 2)),
        child: Row(children: [Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? Colors.blue : Colors.grey, size: 20), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)))]),
      ),
    );
  }
}