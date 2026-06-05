import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../services/user_service.dart';
import '../services/theme_service.dart';
import '../services/credit_service.dart';
import '../services/anki_service.dart';
import '../services/mistakes_service.dart';
import '../services/ad_service.dart';
import '../services/team_service.dart';
import '../services/stats_service.dart';
import '../services/progression_service.dart';
import '../widgets/report_dialog.dart';
import '../widgets/header_stats.dart';
import '../widgets/training/team_status_card.dart';
import '../widgets/training/theme_progress_bar.dart';
import '../models/question.dart';
import '../utils/page_transition.dart';
import 'onboarding_page.dart';
import 'mistakes_page.dart';
import 'daily_review_page.dart';
import 'exam_intro_page.dart';
import 'shop_page.dart';
import '../services/notification_service.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> with AutomaticKeepAliveClientMixin {
  final AdService _adService = AdService();
  final UserService _userService = UserService();
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isProcessing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _adService.loadAd();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.requestPermissions();
      await NotificationService.scheduleDailyReminder();
      _checkFirstTimeTutorial();
    });
  }

  Future<void> _checkFirstTimeTutorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('tutorial_seen') ?? false;
    if (!seen && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingPage()));
    }
  }

  Future<void> _createUserProfileIfNeeded() async {
    if (user == null) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isProfileReady = prefs.getBool('profile_created_v2') ?? false;
    if (isProfileReady) return;
    await _userService.createUserProfileIfNeeded(user!.uid, user!.email);
    await prefs.setBool('profile_created_v2', true);
    if (mounted) setState(() {});
  }

  void _goToStore() {
    Navigator.push(context, SlideRightRoute(page: const ShopPage())).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<bool> _processPayment(int cost, {String title = "Crédits insuffisants"}) async {
    if (user == null) return false;
    try {
      await _createUserProfileIfNeeded();
      final missing = await CreditService.tryDeductCredits(user!.uid, cost);
      if (missing == null) return true;
      if (mounted && missing > 0) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text("Cette action coûte $cost crédits.\nIl vous en manque $missing."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _goToStore();
                },
                child: const Text("Obtenir Pack Réussite"),
              ),
            ],
          ),
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _unlockTheme(String themeId, String themeTitle, int cost) async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });
    try {
      bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lock_open, color: Colors.blue),
            SizedBox(width: 10),
            Text("Débloquer le thème"),
          ]),
          content: Text('Voulez-vous acheter le thème "$themeTitle" définitivement pour $cost crédits ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Non")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Oui, acheter")),
          ],
        ),
      ) ?? false;
      if (!confirm) return;

      final missing = await CreditService.unlockTheme(user!.uid, themeId, cost);
      if (missing == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Thème "$themeTitle" débloqué !'), backgroundColor: Colors.green),
          );
        }
      } else if (missing > 0 && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Débloquer le thème"),
            content: Text("Cette action coûte $cost crédits.\nIl vous en manque $missing."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _goToStore();
                },
                child: const Text("Obtenir Pack Réussite"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _openBetisierWithCredits() async {
    if (user == null || _isProcessing) return;
    setState(() { _isProcessing = true; });
    try {
      await _createUserProfileIfNeeded();
      final hasMistakes = await _userService.hasMistakes(user!.uid);
      if (!mounted) return;
      if (!hasMistakes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("👏 Bravo ! Aucune erreur à rattraper."), backgroundColor: Colors.green),
        );
        return;
      }
      final missing = await CreditService.tryDeductCredits(user!.uid, 2);
      if (!mounted) return;
      if (missing == null) await Navigator.push(context, SlideRightRoute(page: const MistakesPage()));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _startMockExam() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });
    try {
      bool paid = await _processPayment(5);
      if (!mounted) return;
      if (paid) await Navigator.push(context, SlideRightRoute(page: const ExamIntroPage()));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _startTheme(String themeId, String themeTitle) async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });
    try {
      bool paid = await _processPayment(1);
      if (!mounted) return;
      if (paid) await Navigator.push(context, SlideRightRoute(page: ThemeRunnerPage(themeId: themeId, themeTitle: themeTitle)));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _resetAnki() async {
    if (user != null) {
      bool confirm = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Réinitialiser Anki ?"),
          content: const Text("Tout effacer ?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Non")),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Oui")),
          ],
        ),
      ) ?? false;
      if (confirm) await AnkiService.resetAll(user!.uid);
    }
  }

  IconData _getIconForTheme(Map<String, dynamic> data) {
    String iconField = (data['icon'] ?? '').toString().toLowerCase().trim();
    if (iconField.isNotEmpty) {
      if (iconField.contains('pool') || iconField.contains('swim')) return Icons.pool;
      if (iconField.contains('medic') || iconField.contains('health')) return Icons.medical_services;
      if (iconField.contains('gavel') || iconField.contains('law')) return Icons.gavel;
      if (iconField.contains('boat') || iconField.contains('ship')) return Icons.directions_boat;
      if (iconField.contains('alert') || iconField.contains('warning')) return Icons.warning_amber_rounded;
    }
    String t = (data['title'] ?? '').toString().toLowerCase();
    if (t.contains('mer') || t.contains('marin') || t.contains('côtier') || t.contains('navig')) return Icons.sailing;
    if (t.contains('bateau') || t.contains('embarcation')) return Icons.directions_boat;
    if (t.contains('météo') || t.contains('vent') || t.contains('nuage')) return Icons.cloud;
    if (t.contains('radio') || t.contains('vhe') || t.contains('crr')) return Icons.radio;
    if (t.contains('signal') || t.contains('balisage')) return Icons.flag;
    if (t.contains('droit') || t.contains('règle') || t.contains('regle') || t.contains('loi') || t.contains('juridique')) return Icons.gavel;
    if (t.contains('secour') || t.contains('pse') || t.contains('soin') || t.contains('pansement') || t.contains('urgence')) return Icons.medical_services;
    if (t.contains('technique') || t.contains('nage') || t.contains('natation') || t.contains('piscine') || t.contains('eau')) return Icons.pool;
    if (t.contains('apnée') || t.contains('plongée')) return Icons.scuba_diving;
    if (t.contains('qcm') || t.contains('exam') || t.contains('test') || t.contains('quiz')) return Icons.quiz;
    if (t.contains('annale') || t.contains('sujet')) return Icons.library_books;
    return Icons.school;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return StreamBuilder(
      stream: user == null ? null : _userService.userStream(user!.uid),
      builder: (context, userSnap) {
        if (userSnap.hasData && !userSnap.data!.exists) {
          _createUserProfileIfNeeded();
          return const Center(child: CircularProgressIndicator());
        }

        var userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
        bool isPremium = userData['isPremium'] ?? false;
        List<dynamic> unlockedThemes = userData['unlocked_themes'] ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              TeamStatusCard(userId: user?.uid),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Column(
                  children: [
                    _buildGradientActionCard(
                      icon: Icons.timer_outlined,
                      title: "EXAMEN BLANC (40 Q)",
                      subtitle: isPremium ? "Pack Réussite : ILLIMITÉ" : "Conditions réelles • 5 Crédits ⚡",
                      gradientColors: const [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      shadowColor: Colors.blueAccent.withValues(alpha: 0.4),
                      isPremium: isPremium,
                      onTap: _startMockExam,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradientActionCard(
                            icon: Icons.replay_circle_filled_rounded,
                            title: "Rattrapage",
                            subtitle: isPremium ? "ILLIMITÉ" : "Erreurs • 2 ⚡",
                            gradientColors: const [Color(0xFFFF512F), Color(0xFFF09819)],
                            shadowColor: Colors.orange.withValues(alpha: 0.4),
                            isPremium: isPremium,
                            onTap: _openBetisierWithCredits,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildGradientActionCard(
                            icon: Icons.shopping_bag_outlined,
                            title: "Boutique",
                            subtitle: "Packs & Crédits",
                            gradientColors: const [Color(0xFF11998e), Color(0xFF38ef7d)],
                            shadowColor: Colors.green.withValues(alpha: 0.4),
                            isPremium: false,
                            onTap: _goToStore,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              StreamBuilder<Map<String, int>>(
                stream: AnkiService.getAnkiStatsStream(user?.uid),
                builder: (context, snapshot) {
                  int due = snapshot.data?['due'] ?? 0;
                  int total = snapshot.data?['total'] ?? 0;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF141E30), Color(0xFF243B55)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.psychology, size: 28, color: Colors.blueAccent),
                              ),
                              const SizedBox(width: 15),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text("Mémoire à Long Terme", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text("$total cartes apprises", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ]),
                            ]),
                            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.white30), onPressed: _resetAnki),
                          ],
                        ),
                        const SizedBox(height: 15),
                        due == 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                                  SizedBox(width: 10),
                                  Text("Tout est mémorisé !", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ]),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () { Navigator.push(context, SlideRightRoute(page: const DailyReviewPage())); },
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text("RÉVISER $due CARTES", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  );
                },
              ),

              const Padding(
                padding: EdgeInsets.only(left: 20, top: 15, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Thèmes d'entraînement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey)),
                ),
              ),

              StreamBuilder(
                stream: ThemeService().themesStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var themes = snapshot.data!.docs.where((doc) => doc.id.startsWith('theme_')).toList();
                  if (themes.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Aucun thème disponible."));

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    itemCount: themes.length,
                    itemBuilder: (context, index) {
                      var data = themes[index].data() as Map<String, dynamic>;
                      String themeId = themes[index].id;
                      bool isPremiumTheme = data['is_premium'] ?? false;
                      bool isUnlocked = unlockedThemes.contains(themeId) || isPremium;
                      bool isLocked = isPremiumTheme && !isUnlocked;
                      int unlockCost = data['unlock_cost'] ?? 20;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isLocked ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]) : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isLocked ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (isLocked) {
                                _unlockTheme(themeId, data['title'] ?? 'Thème', unlockCost);
                              } else {
                                _startTheme(themeId, data['title'] ?? '');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: isLocked
                                          ? null
                                          : LinearGradient(
                                              colors: [Colors.blue.shade50, Colors.blue.shade100],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      color: isLocked ? Colors.grey.withValues(alpha: 0.1) : null,
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
                                        Text(
                                          data['title'] ?? 'Thème',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLocked ? Colors.grey : textColor),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isLocked ? "Verrouillé • $unlockCost Crédits" : (isPremium ? "ILLIMITÉ" : "1 Crédit"),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isLocked ? Colors.redAccent : (isDark ? Colors.white60 : Colors.grey[600]),
                                            fontWeight: isLocked ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                        if (user != null && !isLocked) ...[
                                          const SizedBox(height: 8),
                                          ThemeProgressBar(themeId: themeId, userId: user!.uid, isDark: isDark),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: isLocked ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGradientActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
    required bool isPremium,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isProcessing ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: _isProcessing &&
                    ((title == "Rattrapage" && gradientColors[0] == const Color(0xFFFF512F)) ||
                        (title.contains("EXAMEN") && gradientColors[0] == const Color(0xFF6A11CB)))
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 32, color: Colors.white),
                          if (isPremium && title != "Boutique") ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.star_rounded, color: Colors.yellowAccent, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// --- INTERFACE DE QUIZ "DUOLINGO STYLE" ---

class ThemeRunnerPage extends StatefulWidget {
  final String themeId;
  final String themeTitle;
  const ThemeRunnerPage({super.key, required this.themeId, required this.themeTitle});
  @override
  State<ThemeRunnerPage> createState() => _ThemeRunnerPageState();
}

class _ThemeRunnerPageState extends State<ThemeRunnerPage> {
  List<Question> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _answered = false;
  int? _selectedOption;
  int _score = 0;
  DateTime? _questionStartTime;
  bool _enableHaptic = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _triggerFeedback(bool isCorrect) {
    if (!_enableHaptic) return;
    if (isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
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
                        const Row(children: [
                          Icon(Icons.vibration),
                          SizedBox(width: 15),
                          Text("Vibrations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ]),
                        Switch(
                          value: _enableHaptic,
                          onChanged: (val) {
                            setDialogState(() => _enableHaptic = val);
                            setState(() {});
                            if (val) HapticFeedback.selectionClick();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            );
          },
        );
      },
    );
  }

  Future<void> _loadQuestions() async {
    try {
      var loaded = await ThemeService().getThemeQuestions(widget.themeId, widget.themeTitle);

      loaded = loaded.map((q) => q.withShuffledOptions().withMaskedLongAnswer()).toList();

      loaded.shuffle();
      if (loaded.length > 10) loaded = loaded.take(10).toList();

      if (mounted) {
        setState(() {
          _questions = loaded;
          _loading = false;
          _questionStartTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submitAnswer(int optionIndex) async {
    if (_answered) return;

    if (_questionStartTime != null) {
      int ms = DateTime.now().difference(_questionStartTime!).inMilliseconds;
      StatsService.updateAverageTime(ms);
    }

    setState(() {
      _answered = true;
      _selectedOption = optionIndex;
    });

    bool isCorrect = (optionIndex == _questions[_currentIndex].correctAnswerIndex);
    _triggerFeedback(isCorrect);
    await StatsService.updateThemeStats(widget.themeId, isCorrect);
    await StatsService.updateDailyActivity('qcm');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AnkiService.saveFlashcardReview(user.uid, _questions[_currentIndex], isCorrect ? 3 : 1);
      if (isCorrect) {
        await UserService().updateThemeStat(user.uid, widget.themeId, _questions[_currentIndex].id);
      }
    }

    if (isCorrect) {
      setState(() => _score++);
      TeamService().updateUserScoreInTeam(1);
    } else {
      MistakesService.addMistake(_questions[_currentIndex]);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
        _questionStartTime = DateTime.now();
      });
    } else {
      _showEndDialog();
    }
  }

  void _showEndDialog() {
    if (mounted) ProgressionService.completeQuest(context, 'daily_qcm');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSuccess = _score >= (_questions.length / 2);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(25),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSuccess ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  size: 60, color: isSuccess ? Colors.amber : Colors.grey),
              const SizedBox(height: 20),
              Text(
                isSuccess ? "Félicitations !" : "Entraînement terminé",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text("Score : $_score / ${_questions.length}",
                  style: TextStyle(fontSize: 18, color: Colors.grey[700], fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text("CONTINUER", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    Color surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (_loading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty) return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: Text(widget.themeTitle)), body: const Center(child: Text("Aucune question.")));

    final q = _questions[_currentIndex];
    double progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const HeaderStats(),
        centerTitle: true,
        backgroundColor: surfaceColor,
        elevation: 0,
        foregroundColor: textColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.grey),
            tooltip: "Signaler une erreur",
            onPressed: () => showDialog(context: context, builder: (_) => ReportDialog(question: q)),
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettingsDialog),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
            minHeight: 6.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                widget.themeTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ),

            if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(q.imageUrl!, height: 180, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()),
              ),
              const SizedBox(height: 20),
            ],

            Text(q.questionText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor, height: 1.3)),
            const SizedBox(height: 25),

            ...List.generate(q.options.length, (index) {
              return _buildAnswerOption(index, q.options[index], q.correctAnswerIndex, isDark);
            }),

            const SizedBox(height: 20),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _answered ? 1.0 : 0.0,
              child: _answered
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.lightbulb, size: 20, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text("L'explication du pro", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                q.explanation.isEmpty ? "Pas d'explication détaillée." : q.explanation,
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedOption == q.correctAnswerIndex ? Colors.green : Colors.blueAccent,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _nextQuestion,
                            child: Text(
                              _currentIndex < _questions.length - 1 ? "QUESTION SUIVANTE" : "VOIR MON SCORE",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption(int index, String text, int correctIndex, bool isDark) {
    bool isSelected = _selectedOption == index;
    bool isCorrect = index == correctIndex;
    bool showResult = _answered;

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
      } else if (isSelected && !isCorrect) {
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
      onTap: _answered ? null : () => _submitAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected || (showResult && isCorrect) ? 2 : 1),
          boxShadow: [
            if (!showResult)
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
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
                  fontWeight: (isSelected || (showResult && isCorrect)) ? FontWeight.bold : FontWeight.normal,
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
                    color: isSelected ? Colors.blueAccent : Colors.grey.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  color: isSelected ? Colors.blueAccent : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
