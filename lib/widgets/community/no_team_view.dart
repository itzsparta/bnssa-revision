import 'package:flutter/material.dart';

class NoTeamView extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  const NoTeamView({
    super.key,
    required this.isDark,
    required this.controller,
    required this.isLoading,
    required this.onJoin,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final Color textCol = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: const Column(children: [
              Icon(Icons.shield, size: 60, color: Colors.white),
              SizedBox(height: 15),
              Text("Rejoins la bataille !",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 10),
              Text("Seul on va plus vite,\nEnsemble on va plus loin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: controller,
            style: TextStyle(color: textCol),
            decoration: InputDecoration(
              hintText: "Code du Clan (ex: MNS24)",
              prefixIcon: const Icon(Icons.vpn_key, color: Colors.blue),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white))
                : const Text("REJOINDRE UN CLAN",
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: onCreate,
            child: const Text("Ou créer mon propre clan",
                style: TextStyle(decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}
