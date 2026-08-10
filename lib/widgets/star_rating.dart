import 'package:flutter/material.dart';

/// Звёздный рейтинг. В интерактивном режиме при нажатии проигрывается
/// каскадная анимация «волной» с подпрыгиванием звёзд.
class StarRating extends StatefulWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<double>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _animatingUpTo = 0; // до какой звезды играть анимацию

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(int starValue) {
    setState(() => _animatingUpTo = starValue);
    widget.onRatingChanged?.call(starValue.toDouble());
    _controller.forward(from: 0);
  }

  // Каскадное подпрыгивание слева направо для звезды с индексом [index].
  double _starScale(int index) {
    final start = (index * 0.12).clamp(0.0, 0.6);
    const span = 0.4;
    final t = _controller.value;
    if (t < start || t > start + span) return 1.0;
    final local = (t - start) / span; // 0..1
    final bump = 1.0 - (2 * local - 1).abs(); // треугольник 0..1..0
    return 1.0 + 0.6 * bump;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;
        if (widget.rating >= starValue) {
          icon = Icons.star_rounded;
        } else if (widget.rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        final star = Icon(icon, color: Colors.amber, size: widget.size);
        return GestureDetector(
          onTap: widget.interactive ? () => _handleTap(starValue) : null,
          child: widget.interactive
              ? AnimatedBuilder(
                  animation: _controller,
                  child: star,
                  builder: (context, ch) {
                    final scale =
                        starValue <= _animatingUpTo ? _starScale(index) : 1.0;
                    return Transform.scale(scale: scale, child: ch);
                  },
                )
              : star,
        );
      }),
    );
  }
}
