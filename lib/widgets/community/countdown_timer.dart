import 'package:flutter/material.dart';
import 'dart:async';

class CountdownTimer extends StatefulWidget {
  const CountdownTimer({super.key});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  String _timeUntilReset = "--:--:--";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final int daysUntilMonday = 8 - now.weekday;
    final DateTime nextReset = DateTime(now.year, now.month, now.day)
        .add(Duration(days: daysUntilMonday));
    final Duration diff = nextReset.difference(now);

    final String days = diff.inDays.toString();
    final String hours = (diff.inHours % 24).toString().padLeft(2, '0');
    final String minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');

    if (mounted) {
      setState(() => _timeUntilReset = "${days}j ${hours}h ${minutes}m");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "Reset dans $_timeUntilReset",
      style: const TextStyle(
          color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }
}
