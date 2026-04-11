import 'dart:ui'; // Nécessaire pour l'effet de flou (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // AJOUTÉ : Pour vérifier le profil
import 'package:flutter/services.dart';
import '../utils/page_transition.dart';
import 'home_page.dart';
import 'user_info_page.dart'; // AJOUTÉ : La page de formulaire

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  // Contrôleurs
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  // États
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isPhoneMode = false;
  String? _verificationId;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --- LOGIQUE D'AUTHENTIFICATION ---

  void _authenticateEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Veuillez remplir tous les champs");
      return;
    }
    setState(() => _isLoading = true);
    TextInput.finishAutofillContext();
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      _goToHome();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        _goToHome();
      }
    } catch (e) {
      _showError("Erreur Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startPhoneAuth() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      _showError("Numéro de téléphone invalide");
      return;
    }
    if (!phone.startsWith('+')) {
      phone = "+33${phone.startsWith('0') ? phone.substring(1) : phone}";
    }
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _goToHome();
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _handleAuthError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          _showSmsDialog();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) setState(() => _verificationId = verificationId);
      },
    );
  }

  void _verifySmsCode() async {
    if (_smsCodeController.text.isEmpty || _verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _smsCodeController.text.trim()
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pop(context);
      _goToHome();
    } catch (e) {
      _showError("Code incorrect");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSmsDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Code SMS", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Entrez le code à 6 chiffres reçu :", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              TextField(
                controller: _smsCodeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 5, color: Colors.white, fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isLoading = false);
                },
                child: const Text("Annuler", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: _verifySmsCode,
                child: const Text("Valider", style: TextStyle(color: Colors.white))
            )
          ],
        )
    );
  }

  void _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showError("Entrez votre email ci-dessus d'abord.");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email de réinitialisation envoyé !"), backgroundColor: Colors.green));
      }
    } catch (e) {
      _showError("Erreur: Impossible d'envoyer l'email.");
    }
  }

  // --- NOUVELLE FONCTION DE REDIRECTION INTELLIGENTE ---
  void _goToHome() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. On récupère le profil utilisateur dans Firestore
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!mounted) return;

    // 2. Vérification : Si pas de pseudo ou pas de nom -> Direction le formulaire
    if (!doc.exists || doc.data()?['pseudo'] == null || doc.data()?['lastName'] == null) {
      Navigator.pushReplacement(context, SlideRightRoute(page: const UserInfoPage()));
    } else {
      // Sinon -> Direction Accueil
      Navigator.pushReplacement(context, SlideRightRoute(page: const HomePage()));
    }
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _handleAuthError(FirebaseAuthException e) {
    String msg = "Erreur inconnue";
    if (e.code == 'user-not-found') { msg = "Compte introuvable."; }
    else if (e.code == 'wrong-password') { msg = "Mot de passe incorrect."; }
    else if (e.code == 'email-already-in-use') { msg = "Email déjà utilisé."; }
    else if (e.code == 'invalid-phone-number') { msg = "Numéro invalide."; }
    else if (e.code == 'invalid-credential') { msg = "Identifiants invalides."; }
    _showError(msg);
  }

  // --- UI (Design inchangé) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FOND DÉGRADÉ ANIMÉ
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Couleurs "Océan Profond"
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),

          // 2. FORMES DÉCORATIVES
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 10)
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.1), blurRadius: 60, spreadRadius: 10)
                ],
              ),
            ),
          ),

          // 3. CONTENU PRINCIPAL
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LOGO & TITRE
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.pool_rounded, size: 60, color: Colors.cyanAccent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isLogin ? "RAVI DE VOUS REVOIR !" : "REJOIGNEZ LA TEAM",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Préparez votre BNSSA comme un pro.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 40),

                    // CARTE GLASSMORPHISM
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          ),
                          child: Column(
                            children: [
                              // SWITCH EMAIL / PHONE
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
                                child: Row(
                                  children: [
                                    _buildSwitchTab("Email", !_isPhoneMode, () => setState(() => _isPhoneMode = false)),
                                    _buildSwitchTab("Téléphone", _isPhoneMode, () => setState(() => _isPhoneMode = true)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 25),

                              if (!_isPhoneMode) ...[
                                _buildTextField(_emailController, "Email", Icons.email_outlined, false),
                                const SizedBox(height: 15),
                                _buildTextField(
                                  _passwordController, "Mot de passe", Icons.lock_outline, true,
                                  isPassword: true,
                                  isVisible: _isPasswordVisible,
                                  onToggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                                if (_isLogin)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _forgotPassword,
                                      child: const Text("Mot de passe oublié ?", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                                    ),
                                  ),
                              ] else ...[
                                _buildTextField(_phoneController, "Numéro (ex: 0612345678)", Icons.phone_iphone, false, isPhone: true),
                                const SizedBox(height: 20),
                              ],

                              const SizedBox(height: 20),

                              // BOUTON PRINCIPAL
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black87,
                                    elevation: 10,
                                    shadowColor: Colors.cyanAccent.withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : (_isPhoneMode ? _startPhoneAuth : _authenticateEmail),
                                  child: _isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                      : Text(_isPhoneMode ? "ENVOYER LE CODE" : (_isLogin ? "SE CONNECTER" : "S'INSCRIRE"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // BOUTON GOOGLE
                    OutlinedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.g_mobiledata, size: 20, color: Colors.red),
                      ),
                      label: const Text("Continuer avec Google", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // LIEN INSCRIPTION
                    if (!_isPhoneMode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_isLogin ? "Pas encore de compte ?" : "Déjà un compte ?", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                          TextButton(
                            onPressed: () => setState(() => _isLogin = !_isLogin),
                            child: Text(_isLogin ? "Créer un compte" : "Se connecter", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS D'AIDE ---

  Widget _buildSwitchTab(String text, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(text, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isObscure, {bool isPassword = false, bool isVisible = false, VoidCallback? onToggleVisibility, bool isPhone = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !isVisible : false,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.cyanAccent.withValues(alpha: 0.8)),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
          onPressed: onToggleVisibility,
        )
            : null,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.cyanAccent),
        ),
      ),
    );
  }
}