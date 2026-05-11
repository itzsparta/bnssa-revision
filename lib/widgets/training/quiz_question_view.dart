import 'package:flutter/material.dart';

import '../../models/question.dart';
import 'answer_tile.dart';

class QuizQuestionView extends StatelessWidget {
  final Question question;
  final bool answered;
  final int? selectedOption;
  final bool isLastQuestion;
  final bool isDark;
  final void Function(int index)? onSelectOption;
  final VoidCallback onNext;

  const QuizQuestionView({
    super.key,
    required this.question,
    required this.answered,
    required this.selectedOption,
    required this.isLastQuestion,
    required this.isDark,
    required this.onSelectOption,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              question.themeName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ),

          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                question.imageUrl!,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Text(question.questionText,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.3)),
          const SizedBox(height: 25),

          ...List.generate(
            question.options.length,
            (index) => AnswerTile(
              index: index,
              text: question.options[index],
              correctIndex: question.correctAnswerIndex,
              isDark: isDark,
              isSelected: selectedOption == index,
              showResult: answered,
              onTap: answered ? null : () => onSelectOption?.call(index),
            ),
          ),

          const SizedBox(height: 20),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: answered ? 1.0 : 0.0,
            child: answered
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.lightbulb,
                                    size: 20, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text("L'explication du pro",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800])),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                question.explanation.isEmpty
                                    ? "Pas d'explication détaillée."
                                    : question.explanation,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    height: 1.4),
                              ),
                            ]),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selectedOption == question.correctAnswerIndex
                                    ? Colors.green
                                    : Colors.blueAccent,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: onNext,
                          child: Text(
                            isLastQuestion
                                ? "VOIR MON SCORE"
                                : "QUESTION SUIVANTE",
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
