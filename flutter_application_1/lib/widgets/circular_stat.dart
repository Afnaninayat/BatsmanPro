import 'package:flutter/material.dart';

class CircularStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const CircularStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: 0.75,
                strokeWidth: 8,
                color: color,
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
