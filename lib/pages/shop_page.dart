// lib/pages/shop_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ad_service.dart';
import '../services/haptic_service.dart';
import '../services/purchase_service.dart';
import '../widgets/trainer_pack_card.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final AdService _adService = AdService();
  final HapticService _hapticService = HapticService();
  bool _isLoading = false; // uniquement pour la validation de code
  final Set<String> _loadingItems = {}; // loading par produit

  @override
  void initState() {
    super.initState();
    _adService.loadAd();
  }

  bool _isItemLoading(String key) => _loadingItems.contains(key);

  void _watchAdForCredits() {
    if (user == null) return;
    _hapticService.triggerSelection();
    _adService.showRewardedAd(context, () {
      if (mounted) setState(() {});
    });
  }

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
            const Text("Entrez le code fourni par votre formateur."),
            const SizedBox(height: 15),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: "BNSSA-XXXX",
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                String inputCode = codeCtrl.text.trim().toUpperCase();

                var snapshot = await FirebaseFirestore.instance
                    .collection('license_codes')
                    .where('code', isEqualTo: inputCode)
                    .limit(1)
                    .get();

                if (snapshot.docs.isEmpty) throw "Code introuvable.";
                var doc = snapshot.docs.first;
                var data = doc.data();

                if (data['isUsed'] == true) throw "Ce code a déjà été utilisé.";

                if (data['expiresAt'] != null) {
                  Timestamp exp = data['expiresAt'];
                  if (DateTime.now().isAfter(exp.toDate())) {
                    throw "Ce code a expiré (Fin du trimestre formateur).";
                  }
                }

                await FirebaseFirestore.instance.runTransaction((transaction) async {
                  transaction.update(doc.reference, {
                    'isUsed': true,
                    'usedBy': user!.uid,
                    'usedAt': FieldValue.serverTimestamp(),
                  });
                  transaction.update(
                    FirebaseFirestore.instance.collection('users').doc(user!.uid),
                    {
                      'isPremium': true,
                      'credits': 9999,
                      'premiumSource': 'trainer_license',
                      'premiumGrantedBy': data['createdBy'],
                    },
                  );
                });

                _hapticService.triggerSelection();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Licence activée ! Accès illimité débloqué."),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Erreur: $e"),
                    backgroundColor: Colors.red,
                  ));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmPurchase(String label, String displayPrice) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Confirmer l'achat"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(displayPrice, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Confirmer l'achat"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _buyItem(String type, int price, String label, int creditAmount, String displayPrice) async {
    if (user == null) return;

    if (price >= 40) {
      final confirmed = await _confirmPurchase(label, displayPrice);
      if (!confirmed) return;
    }

    _hapticService.triggerSelection();
    setState(() => _loadingItems.add(type));

    try {
      bool success = await PurchaseService.purchaseProduct("bnssa_$type");

      if (!success) {
        if (mounted) setState(() => _loadingItems.remove(type));
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(user!.uid);

      if (type.startsWith('credits_')) {
        batch.update(userRef, {'credits': FieldValue.increment(creditAmount)});
      } else if (type == 'pack_premium') {
        batch.update(userRef, {'isPremium': true, 'credits': 9999});
      } else if (type.startsWith('pack_group_')) {
        int quantity = int.parse(type.split('_')[2]);
        for (int i = 0; i < quantity; i++) {
          DocumentReference newCodeRef = firestore.collection('license_codes').doc();
          batch.set(newCodeRef, {
            'code': PurchaseService.generateRandomCode(),
            'createdBy': user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': null,
            'isUsed': false,
            'type': 'pack_reussite',
          });
        }
      }

      await batch.commit();
      _hapticService.triggerSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Achat réussi !"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingItems.remove(type));
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
                _buildLicenseBanner(isDark),
                const SizedBox(height: 25),

                _sectionHeader("Abonnements & Packs", Icons.workspace_premium, Colors.amber[700]!, textColor),
                const SizedBox(height: 15),

                _buildPackCard(
                  type: 'pack_premium',
                  title: "PACK RÉUSSITE",
                  price: "9,99 €",
                  isPopular: true,
                  color: Colors.amber[700]!,
                  features: const [
                    "Examens Blancs ILLIMITÉS",
                    "Tout débloqué (Thèmes, Quiz)",
                    "Crédits illimités (À vie)",
                  ],
                  onTap: () => _buyItem('pack_premium', 10, "Pack Réussite", 0, "9,99 €"),
                  isDark: isDark,
                ),
                const SizedBox(height: 15),

                const TrainerPackCard(),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),

                _sectionHeader("Recharger des Crédits", Icons.bolt, Colors.blue[600]!, textColor),
                const SizedBox(height: 15),

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
                            Text("Regarder une pub (+5 crédits)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Spacer(),
                        Text("GRATUIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _buildCreditCardMini(
                        "20 crédits", "1,99 €", Colors.blue[400]!, "≈ 0,10 €/crédit",
                        'credits_20', () => _buyItem('credits_20', 2, "20 crédits", 20, "1,99 €"),
                        cardColor, isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCreditCardMini(
                        "50 crédits", "3,99 €", Colors.blue[600]!, "≈ 0,08 €/crédit",
                        'credits_50', () => _buyItem('credits_50', 4, "50 crédits", 50, "3,99 €"),
                        cardColor, isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCreditCardMini(
                        "100 crédits", "6,99 €", Colors.blue[800]!, "≈ 0,07 €/crédit",
                        'credits_100', () => _buyItem('credits_100', 7, "100 crédits", 100, "6,99 €"),
                        cardColor, isDark,
                        isBestValue: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),

                _sectionHeader("Licences supplémentaires", Icons.card_giftcard, Colors.purple.shade300, textColor),
                const SizedBox(height: 5),
                const Text(
                  "Celles-ci n'expirent jamais (achat définitif).",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 15),

                _buildBulkLicenseCard("Licence Unitaire", "9,99 €", "1 code à offrir", Icons.person, Colors.purple, 'pack_group_1', () => _buyItem('pack_group_1', 10, "Licence Unitaire", 0, "9,99 €"), isDark),
                const SizedBox(height: 10),
                _buildBulkLicenseCard("Pack Groupe (5)", "39,99 €", "7,99 € / licence", Icons.group, Colors.indigo, 'pack_group_5', () => _buyItem('pack_group_5', 40, "Pack Groupe (5 licences)", 0, "39,99 €"), isDark),
                const SizedBox(height: 10),
                _buildBulkLicenseCard("Pack Club (10)", "69,99 €", "6,99 € / licence", Icons.school, Colors.deepPurple, 'pack_group_10', () => _buyItem('pack_group_10', 70, "Pack Club (10 licences)", 0, "69,99 €"), isDark),

                const SizedBox(height: 50),
              ],
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildLicenseBanner(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _redeemCode,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.vpn_key, color: Colors.blue[700], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "J'ai un Code Licence",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Élève ? Entrez le code de votre formateur",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.blue[400] : Colors.blue[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color iconColor, Color textColor) {
    return Row(children: [
      Icon(icon, color: iconColor, size: 20),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
    ]);
  }

  Widget _buildCreditCardMini(
    String amount,
    String price,
    Color color,
    String pricePerCredit,
    String loadingKey,
    VoidCallback onTap,
    Color cardColor,
    bool isDark, {
    bool isBestValue = false,
  }) {
    final isLoading = _isItemLoading(loadingKey);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isBestValue ? color.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.2),
                  width: isBestValue ? 1.5 : 1,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  isLoading
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                      : Icon(Icons.bolt, color: color),
                  const SizedBox(height: 5),
                  Text(
                    amount,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Text(pricePerCredit, style: TextStyle(fontSize: 10, color: Colors.grey[500]), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isBestValue)
          Positioned(
            top: -9,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: const Text("TOP VALEUR", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBulkLicenseCard(
    String title,
    String price,
    String subtitle,
    IconData icon,
    Color color,
    String loadingKey,
    VoidCallback onTap,
    bool isDark,
  ) {
    final isLoading = _isItemLoading(loadingKey);
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
          onTap: isLoading ? null : onTap,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLoading ? color.withValues(alpha: 0.5) : color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackCard({
    required String type,
    required String title,
    required String price,
    required bool isPopular,
    required Color color,
    required List<String> features,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final isLoading = _isItemLoading(type);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isPopular ? Border.all(color: color, width: 2) : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
          ),
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
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: isPopular ? color : Colors.green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    ]),
                  )),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading ? null : onTap,
                  child: isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("CHOISIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: -10,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Text("POPULAIRE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}
