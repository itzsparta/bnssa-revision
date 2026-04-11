import 'package:flutter/material.dart';

class ExamResultDetailsPage extends StatelessWidget {
  final Map<String, dynamic> examData;

  const ExamResultDetailsPage({super.key, required this.examData});

  @override
  Widget build(BuildContext context) {
    List<dynamic> details = examData['details'] ?? [];
    int score = examData['score'];
    int total = examData['total'];

    return Scaffold(
      appBar: AppBar(
        title: Text("Copie : $score/$total"),
        backgroundColor: (examData['passed'] ?? false) ? Colors.green : Colors.orange,
      ),
      body: details.isEmpty
          ? const Center(child: Text("Détails non disponibles pour cet examen."))
          : ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: details.length,
        itemBuilder: (context, index) {
          var q = details[index];
          bool isCorrect = q['isCorrect'] ?? false;
          String questionText = q['questionText'] ?? "Question inconnue";
          String userAnswer = q['userAnswer'] ?? "-";
          String correctAnswer = q['correctAnswer'] ?? "-";
          String explanation = q['explanation'] ?? "";

          return Card(
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(
                side: BorderSide(color: isCorrect ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(12)
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Question ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  if (!isCorrect) ...[
                    _buildBadge("Votre réponse", userAnswer, Colors.red),
                    const SizedBox(height: 5),
                  ],
                  _buildBadge(isCorrect ? "Votre réponse" : "Bonne réponse", isCorrect ? userAnswer : correctAnswer, Colors.green),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text("💡 $explanation", style: TextStyle(color: Colors.blue[800], fontStyle: FontStyle.italic)),
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(String label, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label : ", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }
}