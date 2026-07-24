part of 'main.dart';

class DelightSwipeCard extends StatelessWidget {
  const DelightSwipeCard({
    super.key,
    required this.question,
    required this.offset,
    required this.locked,
    required this.onUpdate,
    required this.onEnd,
  });

  final Question question;
  final Offset offset;
  final bool locked;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final intensity = (offset.dx.abs() / 120).clamp(0.0, 1.0);
    final sideColor = offset.dx < 0 ? const Color(0xFF53C3A3) : const Color(0xFFE87878);
    final neutral = const Color(0xFF444C5B);
    final rotation = offset.dx / 1250;

    return GestureDetector(
      onHorizontalDragUpdate: locked ? null : (details) => onUpdate(details.delta.dx),
      onHorizontalDragEnd: locked ? null : (_) => onEnd(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: offset.dx),
        duration: offset == Offset.zero ? const Duration(milliseconds: 360) : Duration.zero,
        curve: Curves.elasticOut,
        builder: (context, animatedDx, child) {
          return Transform.translate(
            offset: Offset(animatedDx, 0),
            child: Transform.rotate(
              angle: rotation,
              child: child,
            ),
          );
        },
        child: RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: min(MediaQuery.sizeOf(context).width - 36, 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: intensity > .1 ? sideColor : neutral, width: 1.5 + intensity),
              gradient: const LinearGradient(
                colors: [Color(0xFF2B3140), Color(0xFF191C24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(const Color(0x55000000), sideColor.withValues(alpha: .28), intensity)!,
                  blurRadius: 34 + intensity * 20,
                  offset: Offset(offset.dx / 18, 18 + intensity * 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: offset.dx < 0 ? 0 : null,
                  right: offset.dx >= 0 ? 0 : null,
                  child: Opacity(
                    opacity: intensity,
                    child: Transform.rotate(
                      angle: offset.dx < 0 ? -.12 : .12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(color: sideColor, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(offset.dx < 0 ? '借方' : '貸方', style: TextStyle(color: sideColor, fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('この勘定科目を置く側は？', style: TextStyle(color: Color(0xFFA9B0BF))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(question.account, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('← 借方', style: TextStyle(color: Color(0xFFA9B0BF))),
                        Text('貸方 →', style: TextStyle(color: Color(0xFFA9B0BF))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
