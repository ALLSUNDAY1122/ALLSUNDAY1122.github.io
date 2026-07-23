part of 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = StatsStore();
  List<Question> _questions = const [];
  LearningStats _stats = const LearningStats();
  GradeFilter _filter = GradeFilter.grade3;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      QuestionRepository.load(),
      _store.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _questions = results[0] as List<Question>;
      _stats = results[1] as LearningStats;
      _loading = false;
    });
  }

  Future<void> _start(GameMode mode) async {
    if (_questions.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: mode,
          filter: _filter,
          questions: _questions,
          initialStats: _stats,
          store: _store,
        ),
      ),
    );
    final latest = await _store.load();
    if (mounted) setState(() => _stats = latest);
  }

  Future<void> _resetStats() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学習記録を削除しますか？'),
        content: const Text('回答履歴、正答率、自己ベストを削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (approved != true) return;
    await _store.clear();
    if (mounted) setState(() => _stats = const LearningStats());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredCount = _questions.where((q) => _filter.accepts(q.grade)).length;
    final weakRows = _weakCategories();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _AppHeader(),
                  const SizedBox(height: 20),
                  _HeroStats(stats: _stats),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: '出題範囲',
                    trailing: '$filteredCount問収録',
                    child: SegmentedButton<GradeFilter>(
                      segments: GradeFilter.values
                          .map((grade) => ButtonSegment(value: grade, label: Text(grade.label)))
                          .toList(),
                      selected: {_filter},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) => setState(() => _filter = value.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ModeButton(
                    icon: Icons.all_inclusive,
                    title: 'スコアアタック',
                    subtitle: '3回ミスするまで。連続正解で得点アップ。',
                    onTap: () => _start(GameMode.score),
                  ),
                  _ModeButton(
                    icon: Icons.timer_outlined,
                    title: 'タイムアタック',
                    subtitle: '60秒で何問正解できるかに挑戦。',
                    onTap: () => _start(GameMode.time),
                  ),
                  _ModeButton(
                    icon: Icons.trending_down,
                    title: '苦手出題',
                    subtitle: '誤答率が高い問題を優先して10問。',
                    onTap: () => _start(GameMode.weak),
                  ),
                  _ModeButton(
                    icon: Icons.today_outlined,
                    title: 'デイリー10問',
                    subtitle: '日替わり固定セットで学習を習慣化。',
                    onTap: () => _start(GameMode.daily),
                  ),
                  const SizedBox(height: 4),
                  _SectionCard(
                    title: '苦手論点',
                    action: TextButton(onPressed: _resetStats, child: const Text('記録をリセット')),
                    child: weakRows.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('回答すると論点別の正答率が表示されます。'),
                          )
                        : Column(children: weakRows),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '試作版 v0.1.0　問題は独自作成であり、公式問題ではありません。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFA9B0BF), fontSize: 12),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _weakCategories() {
    final aggregates = <String, (int attempts, int correct)>{};
    for (final question in _questions) {
      final stat = _stats.questionStats[question.id];
      if (stat == null || stat.attempts == 0) continue;
      final previous = aggregates[question.category] ?? (0, 0);
      aggregates[question.category] = (previous.$1 + stat.attempts, previous.$2 + stat.correct);
    }
    final sorted = aggregates.entries.toList()
      ..sort((a, b) => (a.value.$2 / a.value.$1).compareTo(b.value.$2 / b.value.$1));

    return sorted.take(5).map((entry) {
      final rate = entry.value.$2 / entry.value.$1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${entry.value.$2}/${entry.value.$1}問・${(rate * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(value: rate, minHeight: 8, borderRadius: BorderRadius.circular(99)),
          ],
        ),
      );
    }).toList();
  }
}
