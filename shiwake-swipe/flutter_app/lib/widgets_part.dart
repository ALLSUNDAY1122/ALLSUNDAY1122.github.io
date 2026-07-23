part of 'main.dart';

class _AppHeader extends StatelessWidget {
  const _AppHeader();
  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日商簿記 3級・2級', style: TextStyle(color: Color(0xFFF1B44C), fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 12)),
          SizedBox(height: 4),
          Text('仕訳スワイプ', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        ],
      );
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.stats});
  final LearningStats stats;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF353B48))),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('借方は左、貸方は右。', style: TextStyle(color: Color(0xFFF1B44C), fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('考える前に、手が動く。', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 10),
              const Text('取引と勘定科目を見て、置く側へスワイプ。短時間の反復で判断速度を鍛えます。', style: TextStyle(color: Color(0xFFA9B0BF), height: 1.6)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _ResultMetric(value: '${stats.total}', label: '総回答')),
                  Expanded(child: _ResultMetric(value: stats.total == 0 ? '—' : '${(stats.accuracy * 100).round()}%', label: '正答率')),
                  Expanded(child: _ResultMetric(value: '${stats.bestCombo}', label: '最高連続')),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing, this.action});
  final String title;
  final Widget child;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF353B48))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (trailing != null) Chip(label: Text(trailing!)),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF353B48))),
          child: ListTile(
            onTap: onTap,
            leading: CircleAvatar(backgroundColor: const Color(0xFF222631), child: Icon(icon, color: const Color(0xFFF1B44C))),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF191C24), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF353B48))),
        child: Column(
          children: [
            Text(label, maxLines: 1, style: const TextStyle(color: Color(0xFFA9B0BF), fontSize: 11)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(unit, style: const TextStyle(color: Color(0xFFA9B0BF), fontSize: 11)),
          ],
        ),
      );
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Color(0xFFA9B0BF), fontSize: 12)),
        ],
      );
}
