import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';
import '../services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final Question question;
  const ReportDialog({super.key, required this.question});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSending = false;
  final _reportService = ReportService();

  void _sendReport() async {
    if (_reasonController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _reportService.sendReport(
        questionId: widget.question.id,
        questionText: widget.question.questionText,
        userId: user?.uid,
        reason: _reasonController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Signalement envoyé. Merci !"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [Icon(Icons.flag, color: Colors.red), SizedBox(width: 10), Text("Signaler")]),
      content: TextField(
        controller: _reasonController,
        decoration: const InputDecoration(hintText: "Ex: Erreur dans la réponse..."),
        maxLines: 3,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: _isSending ? null : _sendReport,
          child: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Envoyer"),
        )
      ],
    );
  }
}
