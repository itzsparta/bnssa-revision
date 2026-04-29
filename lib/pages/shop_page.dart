import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final AdService _adService = AdService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _adService.loadAd();
  }

  // --- LOGIQUE MÉTIER ---
  void _watchAdForCredits() {
    if (user == null) return;
    _adService.showRewardedAd(context, () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // --- VALIDATION D'UNE LICENCE (Côté Élève) ---
  void _redeemCode() {
    TextEditingController codeCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Activer une licence"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Entrez votre code (ex: BNSSA-XY78)."),
              const SizedBox(height: 15),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                decoration: InputDecoration(
                    hintText: "CODE-XXXX",
                    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.vpn_key)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () async {
                  if (codeCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);

                  try {
                    String inputCode = codeCtrl.text.trim().toUpperCase();

                    // 1. Recherche du code
                    var snapshot = await FirebaseFirestore.instance
                        .collection('license_codes')
                        .where('code', isEqualTo: inputCode)
                        .limit(1)
                        .get();

                    if (snapshot.docs.isEmpty) throw "Code introuvable.";
                    var doc = snapshot.docs.first;
                    var data = doc.data();

                    // 2. Vérifications de sécurité
                    if (data['isUsed'] == true) throw "Ce code a déjà été utilisé.";

                    // --- VÉRIFICATION DATE (Codes Formateur) ---
                    if (data['expiresAt'] != null) {
                      Timestamp exp = data['expiresAt'];
                      if (DateTime.now().isAfter(exp.toDate())) {
                        throw "Ce code a expiré (Fin du trimestre formateur).";
                      }
                    }

                    // 3. Activation
                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      // Marquer le code comme utilisé
                      transaction.update(doc.reference, {
                        'isUsed': true,
                        'usedBy': user!.uid,
                        'usedAt': FieldValue.serverTimestamp()
                      });

                      // Donner le Premium à l'élève A VIE
                      transaction.update(
                          FirebaseFirestore.instance.collection('users').doc(user!.uid),
                          {'isPremium': true, 'credits': 9999}
                      );
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Licence activée ! Accès illimité débloqué."),
                          backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Erreur: $e"), backgroundColor: Colors.red));
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: const Text("Valider"))
          ],
        ));
  }

  // --- ACHAT (Côté Formateur/Client) ---
  void _buyItem(String type, int price, String label, int creditAmount) async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      // Simulation ou Service Réel d'achat
      String productId = "bnssa_$type";
      bool success = await PurchaseService.purchaseProduct(productId);

      if (!success) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Livraison du contenu
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(user!.uid);

      if (type.startsWith('credits_')) {
        batch.update(userRef, {'credits': FieldValue.increment(creditAmount)});
      }
      else if (type == 'pack_premium') {
        batch.update(userRef, {'isPremium': true, 'credits': 9999});
      }
      else if (type == 'pack_trainer') {
        // --- ABONNEMENT FORMATEUR ---
        DateTime expireDate = DateTime.now().add(const Duration(days: 90));

        batch.update(userRef, {
          'role': 'trainer',
          'isPremium': true,
          'subscription_end': Timestamp.fromDate(expireDate)
        });

        // Génération de 3 codes qui expirent dans 90 jours
        for (int i = 0; i < 3; i++) {
          DocumentReference newCodeRef = firestore.collection('license_codes').doc();
          batch.set(newCodeRef, {
            'code': PurchaseService.generateRandomCode(),
            'createdBy': user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(expireDate), // DATE LIMITE
            'isUsed': false,
            'type': 'pack_reussite_trimestre'
          });
        }
      }
      else if (type.startsWith('pack_group_')) {
        // Achat unitaire (pas d'expiration)
        int quantity = int.parse(type.split('_')[2]);
        for (int i = 0; i < quantity; i++) {
          DocumentReference newCodeRef = firestore.collection('license_codes').doc();
          batch.set(newCodeRef, {
            'code': PurchaseService.generateRandomCode(),
            'createdBy': user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': null,
            'isUsed': false,
            'type': 'pack_reussite'
          });
        }
      }

      await batch.commit();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Achat réussi !"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Erreur : $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text("Boutique"), elevation: 0),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _redeemCode,
                  icon: const Icon(Icons.vpn_key),
                  label: const Text("J'ai un Code Licence"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
                  ),
                ),
                const SizedBox(height: 25),

                Text("Abonnements & Packs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 15),

                // PACK ÉTUDIANT (Standard)
                _buildPackCard(
                  title: "PACK RÉUSSITE",
                  price: "9.99 €",
                  isPopular: true,
                  color: Colors.amber[700]!,
                  features: const [
                    "🎓 Examens Blancs ILLIMITÉS",
                    "🔓 Tout débloqué (Thèmes, Quiz)",
                    "⚡ Crédits illimités (À vie)"
                  ],
                  onTap: () => _buyItem('pack_premium', 10, "Pack Réussite", 0),
                  isDark: isDark,
                ),
                const SizedBox(height: 15),

                // PACK FORMATEUR (Refait au propre)
                _buildPackCard(
                  title: "FORMATEUR PRO",
                  price: "29.99 € / 3 mois",
                  isPopular: false,
                  color: Colors.blue[800]!,
                  features: const [
                    "💎 Votre accès Premium inclus",
                    "👥 Espace Formateur (Suivi élèves)",
                    "📦 3 Licences élèves / trimestre",
                    "⏳ Validité des codes : 3 mois",
                    "✨ Pour l'élève : Accès illimité à vie"
                  ],
                  onTap: () => _buyItem('pack_trainer', 30, "Pack Formateur", 0),
                  isDark: isDark,
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),

                Text("Recharger des Crédits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 15),

                // Pub
                InkWell(
                  onTap: _watchAdForCredits,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
                        SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Crédits Gratuits", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Regarder une pub (+5 Crédits)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Spacer(),
                        Text("GRATUIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Grille Crédits
                Row(
                  children: [
                    Expanded(child: _buildCreditCardMini("20 Crédits", "1.99€", Colors.green, () => _buyItem('credits_20', 2, "20 Cr.", 20), cardColor, isDark)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCreditCardMini("50 Crédits", "3.99€", Colors.purple, () => _buyItem('credits_50', 4, "50 Cr.", 50), cardColor, isDark)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCreditCardMini("100 Crédits", "6.99€", Colors.orange, () => _buyItem('credits_100', 7, "100 Cr.", 100), cardColor, isDark)),
                  ],
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),

                // Achats de licences supplémentaires
                Row(children: [
                  Icon(Icons.card_giftcard, color: Colors.purple.shade300),
                  const SizedBox(width: 10),
                  Text("Licences supplémentaires", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                ]),
                const SizedBox(height: 5),
                const Text("Celles-ci n'expirent jamais (achat définitif).", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 15),

                _buildBulkLicenseCard("Licence Unitaire", "9.99 €", "1 code à offrir", Icons.person, Colors.purple, () => _buyItem('pack_group_1', 10, "Licence Unitaire", 0), isDark),
                const SizedBox(height: 10),
                _buildBulkLicenseCard("Pack Groupe (5)", "39.99 €", "7.99€ / licence", Icons.group, Colors.indigo, () => _buyItem('pack_group_5', 40, "Pack Groupe 5", 0), isDark),
                const SizedBox(height: 10),
                _buildBulkLicenseCard("Pack Club (10)", "69.99 €", "6.99€ / licence", Icons.school, Colors.deepPurple, () => _buyItem('pack_group_10', 70, "Pack Club 10", 0), isDark),

                const SizedBox(height: 50),
              ],
            ),
          ),
          if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator()))
        ],
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildCreditCardMini(String amount, String price, Color color, VoidCallback onTap, Color cardColor, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(Icons.flash_on, color: color),
            const SizedBox(height: 5),
            Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBulkLicenseCard(String title, String price, String subtitle, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(price),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackCard({required String title, required String price, required bool isPopular, required Color color, required List<String> features, required VoidCallback onTap, required bool isDark}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isPopular ? Border.all(color: color, width: 2) : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16))),
                  const SizedBox(width: 8),
                  Text(price, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              const Divider(height: 20),
              ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [
                // Uniformisation des icônes : On utilise des icônes spécifiques pour faire pro
                Icon(
                    f.contains("⚠️") ? Icons.timelapse : // Icône pour validité
                    f.contains("💎") ? Icons.diamond :    // Icône pour premium
                    f.contains("👥") ? Icons.groups :     // Icône pour formateur
                    f.contains("📦") ? Icons.inventory_2 : // Icône pour licences
                    Icons.check_circle, // Par défaut
                    color: f.contains("⚠️") ? Colors.orange : (isPopular ? color : Colors.green),
                    size: 18
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))
              ]))),
              const SizedBox(height: 15),
              SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: onTap, child: const Text("CHOISIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
        if (isPopular)
          Positioned(top: -10, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: const Text("POPULAIRE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
      ],
    );
  }
}