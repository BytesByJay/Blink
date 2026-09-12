import 'package:flutter/material.dart';

class CountdownRing extends StatelessWidget {
  final double progress;
  final String label;

  const CountdownRing({super.key, required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.tealAccent),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }
}
