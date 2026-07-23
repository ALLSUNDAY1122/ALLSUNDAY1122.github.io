part of 'main.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    required this.filter,
    required this.questions,
    required this.initialStats,
    required this.store,
  });

  final GameMode mode;
  final GradeFilter filter;
  final List<Question> questions;
  final LearningStats initialStats;
  final StatsStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<Question> _queue;
  late LearningStats _stats;
  Timer? _timer;
  Timer? _advanceTimer;
  int _index = 0;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _correct = 0;
  int _answered = 0;
  int _lives = 3;
  int _seconds = 60;
  bool _locked = false;
  bool _finished = false;
  bool? _lastCorrect;
  int _lastPoints = 0;
  Offset _dragOffset = Offset.zero;
  late DateTime _questionStartedAt;

  Question get _question => _queue[_index];

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    _queue = _buildQueue();
    _questionStartedAt = DateTime.now();
    if (widget.mode == GameMode.time) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _finished) return;
        setState(() => _seconds--);
        if (_seconds <= 0) _finish();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  List<Question> _buildQueue() {
    final pool = widget.questions.where((q) => widget.filter.accepts(q.grade)).toList();
    if (widget.mode == GameMode.daily) {
      final now = DateTime.now();
      final seed = now.year * 10000 + now.month * 100 + now.day + widget.filter.index * 100000000;
      pool.shuffle(Random(seed));
      return pool.take(10).toList();
    }
    if (widget.mode == GameMode.weak) {
      pool.sort((a, b) {
        final aw = _stats.questionStats[a.id]?.weakness ?? 0;
        final bw = _stats.questionStats[b.id]?.weakness ?? 0;
        return bw.compareTo(aw);
      });
      final practiced = pool.where((q) => (_stats.questionStats[q.id]?.attempts ?? 0) > 0).take(7);
      final unseen = pool.where((q) => (_stats.questionStats[q.id]?.attempts ?? 0) == 0).toList()..shuffle();
      return [...practiced, ...unseen].take(10).toList();
    }
    pool.shuffle();
    return pool;
  }

  void _answer(AnswerSide side) {
    if (_locked || _finished) return;
    final question = _question;
    final isCorrect = side == question.correctSide;
    final elapsed = DateTime.now().difference(_questionStartedAt).inMilliseconds;
    var points = 0;

    setState(() {
      _locked = true;
      _answered++;
      _lastCorrect = isCorrect;
      if (isCorrect) {
        _correct++;
        _combo++;
        _bestCombo = max(_bestCombo, _combo);
        points = 100 + max(0, 50 - elapsed ~/ 100) + min(_combo, 20) * 5;
        _score += points;
      } else {
        _combo = 0;
        if (widget.mode == GameMode.score) _lives--;
      }
      _lastPoints = points;
      _stats = _stats.record(questionId: question.id, isCorrect: isCorrect, combo: _combo);
    });

    unawaited(widget.store.save(_stats));
    if (isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    if (widget.mode == GameMode.time) {
      _advanceTimer = Timer(const Duration(milliseconds: 520), _advance);
    }
  }

  void _advance() {
    if (_finished) return;
    final finiteDone = (widget.mode == GameMode.weak || widget.mode == GameMode.daily) && _index + 1 >= _queue.length;
    final livesDone = widget.mode == GameMode.score && _lives <= 0;
    if (finiteDone || livesDone) {
      _finish();
      return;
    }

    setState(() {
      _index++;
      if (_index >= _queue.length) {
        _queue = _buildQueue();
        _index = 0;
      }
      _locked = false;
      _lastCorrect = null;
      _lastPoints = 0;
      _dragOffset = Offset.zero;
      _questionStartedAt = DateTime.now();
    });
  }

  void _finish() {
    if (_finished) return;
    _timer?.cancel();
    _advanceTimer?.cancel();
    final key = '${widget.mode.name}-${widget.filter.name}';
    _stats = _stats.withBestScore(key, _score);
    unawaited(widget.store.save(_stats));
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.mode.label)),
        body: SafeArea(
          child: _finished ? _buildResult() : _buildGame(),
        ),
      ),
    );
  }

  Widget _buildGame() {
    final question = _question;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Row(
          children: [
            Expanded(child: _StatusTile(label: 'スコア', value: '$_score', unit: '点')),
            const SizedBox(width: 8),
            Expanded(child: _StatusTile(label: 'コンボ', value: '$_combo', unit: '連続')),
            const SizedBox(width: 8),
            Expanded(child: _limitTile()),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _progressValue(), minHeight: 7, borderRadius: BorderRadius.circular(99)),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFF353B48))),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, children: [
                  Chip(label: Text('${question.grade}級')),
                  Chip(label: Text(question.category)),
                ]),
                const SizedBox(height: 8),
                Text(question.transaction, style: const TextStyle(fontSize: 17, height: 1.65, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 290,
          child: Center(
            child: GestureDetector(
              onHorizontalDragUpdate: _locked ? null : (details) => setState(() => _dragOffset += Offset(details.delta.dx, 0)),
              onHorizontalDragEnd: _locked
                  ? null
                  : (_) {
                      final dx = _dragOffset.dx;
                      setState(() => _dragOffset = Offset.zero);
                      if (dx <= -70) _answer(AnswerSide.debit);
                      if (dx >= 70) _answer(AnswerSide.credit);
                    },
              child: AnimatedContainer(
                duration: _dragOffset == Offset.zero ? const Duration(milliseconds: 180) : Duration.zero,
                transform: Matrix4.identity()
                  ..translate(_dragOffset.dx, 0.0)
                  ..rotateZ(_dragOffset.dx / 1400),
                width: min(MediaQuery.sizeOf(context).width - 36, 440),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _dragBorderColor(), width: 1.5),
                  gradient: const LinearGradient(colors: [Color(0xFF262B36), Color(0xFF191C24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 35, offset: Offset(0, 18))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('この勘定科目を置く側は？', style: TextStyle(color: Color(0xFFA9B0BF))),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(question.account, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900))),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('← 借方', style: TextStyle(color: Color(0xFFA9B0BF))), Text('貸方 →', style: TextStyle(color: Color(0xFFA9B0BF)))],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locked ? null : () => _answer(AnswerSide.debit),
                icon: const Icon(Icons.arrow_back),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('借方', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locked ? null : () => _answer(AnswerSide.credit),
                icon: const Icon(Icons.arrow_forward),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('貸方', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              ),
            ),
          ],
        ),
        if (_lastCorrect != null) ...[
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _lastCorrect! ? const Color(0xFF53C3A3) : const Color(0xFFEF6F6F)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(_lastCorrect! ? '正解' : '不正解', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
                    Text('+$_lastPoints'),
                  ]),
                  const SizedBox(height: 10),
                  Text(question.explanation, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF101217), borderRadius: BorderRadius.circular(12)),
                    child: Text(question.journal, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (widget.mode != GameMode.time) ...[
                    const SizedBox(height: 14),
                    FilledButton(onPressed: _advance, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: const Text('次の問題')),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    final accuracy = _answered == 0 ? 0 : (_correct / _answered * 100).round();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF353B48))),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Text('RESULT', style: TextStyle(color: Color(0xFFF1B44C), fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(widget.mode.label, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 18),
                Text('$_score', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, height: 1)),
                const Text('点', style: TextStyle(color: Color(0xFFA9B0BF))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _ResultMetric(value: '$_correct', label: '正解')),
                    Expanded(child: _ResultMetric(value: '$accuracy%', label: '正答率')),
                    Expanded(child: _ResultMetric(value: '$_bestCombo', label: '最大連続')),
                  ],
                ),
                const SizedBox(height: 22),
                Text(_resultMessage(accuracy), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFA9B0BF), height: 1.6)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () {
            setState(() {
              _queue = _buildQueue();
              _index = 0;
              _score = 0;
              _combo = 0;
              _bestCombo = 0;
              _correct = 0;
              _answered = 0;
              _lives = 3;
              _seconds = 60;
              _locked = false;
              _finished = false;
              _lastCorrect = null;
              _questionStartedAt = DateTime.now();
            });
            if (widget.mode == GameMode.time) {
              _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                if (!mounted || _finished) return;
                setState(() => _seconds--);
                if (_seconds <= 0) _finish();
              });
            }
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('同じモードでもう一度'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('ホームへ戻る')),
      ],
    );
  }

  Widget _limitTile() {
    if (widget.mode == GameMode.time) return _StatusTile(label: '残り時間', value: '$_seconds', unit: '秒');
    if (widget.mode == GameMode.score) return _StatusTile(label: 'ライフ', value: List<String>.filled(_lives, '♥').join(), unit: '');
    return _StatusTile(label: '問題', value: '${_index + 1}/${_queue.length}', unit: '');
  }

  double _progressValue() {
    if (widget.mode == GameMode.time) return (_seconds / 60).clamp(0.0, 1.0).toDouble();
    if (widget.mode == GameMode.score) return (_lives / 3).clamp(0.0, 1.0).toDouble();
    return (_index / _queue.length).clamp(0.0, 1.0).toDouble();
  }

  Color _dragBorderColor() {
    if (_dragOffset.dx <= -30) return const Color(0xFF53C3A3);
    if (_dragOffset.dx >= 30) return const Color(0xFFE87878);
    return const Color(0xFF444C5B);
  }

  String _resultMessage(int accuracy) {
    if (accuracy >= 90) return '判断は安定しています。正答率を保ったまま回答速度を上げましょう。';
    if (accuracy >= 70) return '基礎は固まっています。苦手出題で誤答した論点を反復しましょう。';
    return '左右を暗記せず、資産・負債・純資産・収益・費用の増減から判断しましょう。';
  }
}
