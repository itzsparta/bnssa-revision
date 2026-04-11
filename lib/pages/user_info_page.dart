import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/page_transition.dart';
import 'home_page.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();
  bool _isLoading = false;

  void _saveInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. On prépare les données
      Map<String, dynamic> userData = {
        'lastName': _nomController.text.trim().toUpperCase(),
        'firstName': _prenomController.text.trim(), // Première lettre majuscule ? Optionnel
        'pseudo': _pseudoController.text.trim(),
        'profile_completed': true,
        // On ne remet PAS 'credits' ici pour ne pas écraser s'il en a déjà gagné
      };

      // 2. On écrit dans Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true)); // Merge permet de ne pas effacer le reste

      // 3. LA CORRECTION DU BUG "ASYNC GAP"
      // On vérifie si la page est toujours affichée avant de naviguer
      if (!mounted) return;

      // 4. On redirige vers l'accueil
      Navigator.pushReplacement(context, SlideRightRoute(page: const HomePage()));

    } catch (e) {
      // Sécurité aussi ici pour l'affichage du message d'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur de sauvegarde : $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // FOND DÉGRADÉ (Même que Login)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin, size: 60, color: Colors.cyanAccent),
                          const SizedBox(height: 20),
                          const Text(
                            "Faisons connaissance",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Ces informations permettront à votre formateur de vous identifier.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 30),

                          _buildTextField(_nomController, "Nom", Icons.person, (val) => val!.isEmpty ? "Nom requis" : null),
                          const SizedBox(height: 15),
                          _buildTextField(_prenomController, "Prénom", Icons.person_outline, (val) => val!.isEmpty ? "Prénom requis" : null),
                          const SizedBox(height: 15),
                          _buildTextField(_pseudoController, "Pseudo (App)", Icons.alternate_email, (val) => val!.isEmpty ? "Pseudo requis" : null),

                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: _isLoading ? null : _saveInfo,
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.black)
                                  : const Text("C'EST PARTI !", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, String? Function(String?) validator) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.cyanAccent.withValues(alpha: 0.8)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.cyanAccent)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}