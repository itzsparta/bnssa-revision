import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Pour le presse-papiers
import 'package:intl/intl.dart'; // Pour formater la date
import 'shop_page.dart';
import '../utils/page_transition.dart';

class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Fonction pour copier le code
  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Code copié !"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Licences Élèves"),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: LicenseService().trainerLicensesStream(user?.uid ?? ''),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          // Calcul des codes valides
          int availableCount = docs.where((d) {
            var data = d.data() as Map<String, dynamic>;
            bool isUsed = data['isUsed'] ?? false;
            Timestamp? exp = data['expiresAt'];
            bool isExpired = exp != null && DateTime.now().isAfter(exp.toDate());
            return !isUsed && !isExpired;
          }).length;

          return Column(
            children: [
              // --- 1. EN-TÊTE ---
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("DISPONIBLES", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 5),
                        Text("$availableCount", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("Codes valides", style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.card_giftcard, color: Colors.white, size: 30),
                    )
                  ],
                ),
              ),

              // --- 2. BOUTON BOUTIQUE ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () => Navigator.push(context, SlideRightRoute(page: const ShopPage())),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                              child: const Icon(Icons.shopping_cart, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Besoin de plus ?", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                Text("Accéder à la boutique", style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
                              ],
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: textColor)
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("HISTORIQUE DES CODES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12, letterSpacing: 1.2))
                ),
              ),
              const SizedBox(height: 10),

              // --- 3. LISTE DES CODES (CORRIGÉE) ---
              Expanded(
                child: docs.isEmpty
                    ? Center(child: Text("Aucun code acheté.", style: TextStyle(color: Colors.grey[600])))
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isUsed = data['isUsed'] ?? false;
                    String code = data['code'] ?? '???';

                    // Gestion Date
                    Timestamp? expiresAt = data['expiresAt'];
                    bool isExpired = false;
                    String dateText = "";

                    if (expiresAt != null) {
                      DateTime expDate = expiresAt.toDate();
                      isExpired = DateTime.now().isAfter(expDate);
                      String formattedDate = DateFormat('dd/MM/yy').format(expDate);
                      dateText = isExpired ? "Expiré le $formattedDate" : "Valide -> $formattedDate";
                    } else {
                      dateText = "Permanent";
                    }

                    // État visuel
                    Color stateColor = Colors.green;
                    IconData stateIcon = Icons.vpn_key;
                    String statusText = "Disponible";

                    if (isUsed) {
                      stateColor = Colors.grey;
                      stateIcon = Icons.person;
                      statusText = "Utilisé";
                    } else if (isExpired) {
                      stateColor = Colors.red;
                      stateIcon = Icons.timelapse;
                      statusText = "Expiré";
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: stateColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle
                          ),
                          child: Icon(stateIcon, color: stateColor),
                        ),
                        // CORRECTION OVERFLOW ICI
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                code,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16, // Police légèrement réduite
                                    letterSpacing: 1.0,
                                    decoration: (isUsed || isExpired) ? TextDecoration.lineThrough : null,
                                    color: (isUsed || isExpired) ? Colors.grey : textColor
                                ),
                                overflow: TextOverflow.ellipsis, // Coupe si trop long
                              ),
                            ),
                            if (!isUsed && !isExpired)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                child: const Text("ACTIF", style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                              )
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusText, style: TextStyle(fontSize: 12, color: stateColor, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: (!isUsed && !isExpired)
                            ? IconButton(
                          icon: const Icon(Icons.copy, color: Colors.grey),
                          onPressed: () => _copyCode(code),
                        )
                            : null,
                        onTap: (!isUsed && !isExpired) ? () => _copyCode(code) : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}