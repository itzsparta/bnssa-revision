import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'training_page.dart'; // Nécessaire pour accéder à ThemeRunnerPage
import 'community_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'shop_page.dart';
import '../widgets/header_stats.dart';
import '../utils/page_transition.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _checkDailyReward();
    _updateUserActivity();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateUserActivity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'last_connection': FieldValue.serverTimestamp(),
        'last_reviewed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _checkDailyReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    Timestamp? lastGift = data['last_daily_gift'];
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    bool shouldGiveCredit = false;

    if (lastGift == null) {
      shouldGiveCredit = true;
    } else {
      DateTime lastDate = lastGift.toDate();
      DateTime lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      if (today.isAfter(lastDay)) {
        shouldGiveCredit = true;
      }
    }

    if (shouldGiveCredit) {
      await userRef.update({
        'credits': FieldValue.increment(1),
        'last_daily_gift': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("🎁 Cadeau du jour !"),
            content: const Text("Tu as reçu 1 Crédit ⚡ gratuit pour t'entraîner aujourd'hui !"),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Merci !"))
            ],
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginPage();
    }

    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const HeaderStats(),
        centerTitle: true,
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        automaticallyImplyLeading: false,
        // --- AJOUT DE LA LOUPE ICI ---
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: ThemeSearchDelegate());
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: const [
          TrainingPage(),
          CommunityPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.all(TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: isDark ? Colors.white : Colors.black)),
                iconTheme: WidgetStateProperty.all(IconThemeData(color: isDark ? Colors.white : Colors.black)),
                indicatorColor: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2),
              ),
              child: NavigationBar(
                height: 75.0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                backgroundColor: Colors.transparent,
                elevation: 0.0,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.pool_outlined), selectedIcon: Icon(Icons.pool, color: Colors.blue), label: 'Entraînement'),
                  NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups, color: Colors.blue), label: 'Social'),
                  NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: Colors.blue), label: 'Profil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- CLASSE DE RECHERCHE ---

// --- CLASSE DE RECHERCHE CORRIGÉE ---

class ThemeSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Rechercher un thème...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildThemeList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildThemeList(context);
  }

  Widget _buildThemeList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('themes').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // Filtrer les thèmes selon la recherche
        var themes = snapshot.data!.docs.where((doc) {
          String title = (doc['title'] ?? '').toString().toLowerCase();
          return doc.id.startsWith('theme_') && title.contains(query.toLowerCase());
        }).toList();

        if (themes.isEmpty) {
          return Center(child: Text("Aucun thème trouvé pour '$query'"));
        }

        return ListView.builder(
          itemCount: themes.length,
          itemBuilder: (context, index) {
            var data = themes[index].data() as Map<String, dynamic>;
            String title = data['title'] ?? 'Thème inconnu';
            String themeId = themes[index].id;
            bool isPremiumTheme = data['is_premium'] ?? false;
            int unlockCost = data['unlock_cost'] ?? 20;

            return ListTile(
              leading: const Icon(Icons.article_outlined, color: Colors.blueAccent),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isPremiumTheme ? "Premium • $unlockCost Crédits" : "Standard • 1 Crédit ⚡"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _handleThemeClick(context, themeId, title, isPremiumTheme, unlockCost),
            );
          },
        );
      },
    );
  }

  void _handleThemeClick(BuildContext context, String themeId, String title, bool isPremiumTheme, int cost) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Récupérer les infos utilisateur (Crédits & Abonnements)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    // 1. Sécurité : On vérifie si la page est toujours là après le chargement
    if (!context.mounted) return;
    if (!userDoc.exists) return;

    Map<String, dynamic> userData = userDoc.data()!;
    int credits = userData['credits'] ?? 0;
    bool isUserPremium = userData['isPremium'] ?? false;
    List<dynamic> unlockedThemes = userData['unlocked_themes'] ?? [];

    bool isUnlocked = unlockedThemes.contains(themeId) || isUserPremium;

    // A. CAS : THÈME VERROUILLÉ (PREMIUM)
    if (isPremiumTheme && !isUnlocked) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Thème verrouillé"),
            content: Text("Ce thème coûte $cost crédits ⚡ pour être débloqué définitivement."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx); // On ferme la popup tout de suite

                    if (credits >= cost) {
                      // Achat
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                        'credits': FieldValue.increment(-cost),
                        'unlocked_themes': FieldValue.arrayUnion([themeId])
                      });

                      // 2. Sécurité
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thème débloqué !"), backgroundColor: Colors.green));
                    } else {
                      // Pas assez de crédits
                      if (!context.mounted) return;
                      _showNoCreditsDialog(context);
                    }
                  },
                  child: const Text("Débloquer")
              )
            ],
          )
      );
      return;
    }

    // B. CAS : THÈME STANDARD (1 Crédit la partie)
    if (!isUnlocked) { // Si pas premium user, on paie 1 crédit
      if (credits < 1) {
        _showNoCreditsDialog(context);
        return;
      }
      // On déduit le crédit
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'credits': FieldValue.increment(-1)
      });

      // 3. Sécurité
      if (!context.mounted) return;
    }

    // C. LANCEMENT DU QUIZ
    close(context, null); // Ferme la recherche
    Navigator.push(context, SlideRightRoute(page: ThemeRunnerPage(themeId: themeId, themeTitle: title)));
  }

  void _showNoCreditsDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Crédits ⚡ insuffisants"),
          content: const Text("Il te manque des crédits pour lancer ce thème."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  close(context, null); // Ferme la recherche aussi
                  Navigator.push(context, SlideRightRoute(page: const ShopPage()));
                },
                child: const Text("Boutique")
            )
          ],
        )
    );
  }
}