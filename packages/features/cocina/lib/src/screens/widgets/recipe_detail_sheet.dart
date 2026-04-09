import 'package:flutter/material.dart';

/// Simple chip used across recipe detail views.
class DetailChip extends StatelessWidget {
  final String label;
  const DetailChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}

/// Star rating widget for recipe reviews.
class StarRating extends StatelessWidget {
  final int? rating;
  final double size;
  final void Function(int?)? onRatingChanged;

  const StarRating({
    this.rating,
    this.size = 24,
    this.onRatingChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = rating != null && starValue <= rating!;
        return GestureDetector(
          onTap: onRatingChanged != null
              ? () => onRatingChanged!(starValue)
              : null,
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            size: size,
            color: isFilled ? const Color(0xFFFFB300) : Colors.white38,
          ),
        );
      }),
    );
  }
}

/// Step number indicator for recipe instructions.
class StepNumber extends StatelessWidget {
  final int step;
  final double size;

  const StepNumber(this.step, {this.size = 24, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF00C896),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
