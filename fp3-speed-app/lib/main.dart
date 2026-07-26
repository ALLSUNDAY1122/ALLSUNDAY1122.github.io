import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'progress_store.dart';
import 'purchase_store.dart';
import 'quiz_scoring.dart';
import 'question_bank.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  );
  final ProgressStore progressStore = await ProgressStore.load();
  final PurchaseStore purchaseStore = await PurchaseStore.load();
  runApp(
    Fp3SpeedApp(
      progressStore: progressStore,
      purchaseStore: purchaseStore,
    ),
  );
}

class Fp3SpeedApp extends StatelessWidget {
  const Fp3SpeedApp({
    super.key,
    required this.progressStore,
    required this.purchaseStore,
  });

  final ProgressStore progressStore;
  final PurchaseStore purchaseStore;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF265DFF),
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FP3 SPEED',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FC),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      home: HomeScreen(
        store: progressStore,
        purchaseStore: purchaseStore,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.purchaseStore,
  });

  final ProgressStore store;
  final PurchaseStore purchaseStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Map<String, IconData> _domainIcons = <String, IconData>{
    'ライフプラン': Icons.event_note_rounded,
    'リスク管理': Icons.shield_rounded,
    '金融資産運用': Icons.show_chart_rounded,
    'タックス': Icons.receipt_long_rounded,
    '不動産': Icons.apartment_rounded,
    '相続': Icons.family_restroom_rounded,
  };

  List<Question> get _availableQuestions =>
      accessibleQuestions(widget.purchaseStore.isPremium);

  @override
  void initState() {
    super.initState();
    widget.purchaseStore.addListener(_refreshPurchaseState);
  }

  void _refreshPurchaseState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.purchaseStore.removeListener(_refreshPurchaseState);
    super.dispose();
  }

  Future<void> _openQuiz(
    String title,
    List<Question> source, {
    int? limit,
  }) async {
    if (source.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対象の問題はありません。')),
      );
      return;
    }

    final List<Question> shuffled = List<Question>.of(source)..shuffle();
    final List<Question> questions =
        limit == null ? shuffled : shuffled.take(limit).toList();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => QuizScreen(
          title: title,
          questions: questions,
          store: widget.store,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PaywallScreen(
          purchaseStore: widget.purchaseStore,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ProgressStore store = widget.store;
    final PurchaseStore purchases = widget.purchaseStore;
    final List<Question> available = _availableQuestions;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'FP3 SPEED',
                            style: TextStyle(
                              fontSize: 29,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '15秒で1問。FP3級だけを反射で覚える。',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '学習データ',
                      onPressed: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => StatsScreen(
                              store: store,
                              questions: available,
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.insights_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _StatusCard(store: store)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _PremiumCard(
                  isPremium: purchases.isPremium,
                  priceLabel: purchases.priceLabel,
                  onTap: _openPaywall,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => _openQuiz(
                        'スピード10問',
                        available,
                        limit: 10,
                      ),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('スピード10問を開始'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ModeButton(
                            icon: Icons.fiber_new_rounded,
                            label: '未出題',
                            count: store.unseenCount(available),
                            onTap: () => _openQuiz(
                              '未出題',
                              store.unseenQuestions(available),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeButton(
                            icon: Icons.replay_circle_filled_rounded,
                            label: '苦手復習',
                            count: store.reviewCount(available),
                            onTap: () => _openQuiz(
                              '苦手復習',
                              store.reviewQuestions(available),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '6分野',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final String domain = fpDomains[index];
                    final List<Question> domainQuestions = available
                        .where((Question q) => q.domain == domain)
                        .toList();
                    return _DomainCard(
                      domain: domain,
                      icon: _domainIcons[domain]!,
                      answered: store.domainAnswered(domain, available),
                      available: domainQuestions.length,
                      fullTotal: fullQuestionsPerDomain,
                      accuracy: store.domainAccuracy(domain, available),
                      isPremium: purchases.isPremium,
                      onTap: () => _openQuiz(domain, domainQuestions),
                    );
                  },
                  childCount: fpDomains.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.02,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              sliver: SliverToBoxAdapter(
                child: Text(
                  purchases.isPremium
                      ? '全600問・各分野100問／法令基準日 2026年4月1日\nFP2級は別アプリとして提供します。'
                      : '無料120問・各分野20問／買い切りで全600問\nFP2級の問題はこのアプリに含みません。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8A94A6),
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.isPremium,
    required this.priceLabel,
    required this.onTap,
  });

  final bool isPremium;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPremium ? const Color(0xFFEAF8EF) : const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: isPremium
                    ? const Color(0xFFCDEED8)
                    : const Color(0xFFFFE7B0),
                child: Icon(
                  isPremium ? Icons.verified_rounded : Icons.lock_open_rounded,
                  color: isPremium
                      ? const Color(0xFF14804A)
                      : const Color(0xFF9A6700),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isPremium ? '全600問 解放済み' : '120問 → 600問へ解放',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPremium ? '追加料金なしで全分野を利用できます' : '買い切り・月額課金なし　$priceLabel',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1B3FA7), Color(0xFF265DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          _StatusItem(
            label: '連続',
            value: '${store.streak}日',
            icon: Icons.local_fire_department_rounded,
          ),
          _divider(),
          _StatusItem(
            label: '今日',
            value: '${store.todayAnswered}問',
            icon: Icons.today_rounded,
          ),
          _divider(),
          _StatusItem(
            label: '正答率',
            value: '${(store.accuracy * 100).round()}%',
            icon: Icons.track_changes_rounded,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 48,
        color: Colors.white.withValues(alpha: 0.25),
      );
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({
    required this.domain,
    required this.icon,
    required this.answered,
    required this.available,
    required this.fullTotal,
    required this.accuracy,
    required this.isPremium,
    required this.onTap,
  });

  final String domain;
  final IconData icon;
  final int answered;
  final int available;
  final int fullTotal;
  final double accuracy;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (!isPremium)
                    const Icon(
                      Icons.lock_rounded,
                      size: 17,
                      color: Color(0xFF98A2B3),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                domain,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: available == 0 ? 0 : answered / available,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 7),
              Text(
                isPremium
                    ? '$answered/$fullTotal　正答率 ${(accuracy * 100).round()}%'
                    : '$answered/$available利用　全$fullTotal問',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.purchaseStore});

  final PurchaseStore purchaseStore;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    widget.purchaseStore.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.purchaseStore.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PurchaseStore store = widget.purchaseStore;
    return Scaffold(
      appBar: AppBar(title: const Text('全問題パック')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF1B3FA7), Color(0xFF265DFF)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                children: <Widget>[
                  Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 54),
                  SizedBox(height: 14),
                  Text(
                    '120問から600問へ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '6分野それぞれ20問から100問へ増加',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _BenefitRow(
              icon: Icons.add_circle_outline_rounded,
              title: '追加480問',
              body: '短文の○×問題を全分野へ均等追加',
            ),
            const _BenefitRow(
              icon: Icons.all_inclusive_rounded,
              title: '買い切り',
              body: '月額課金・自動更新なし',
            ),
            const _BenefitRow(
              icon: Icons.offline_bolt_rounded,
              title: '全問オフライン',
              body: '購入確認後は通信なしで学習可能',
            ),
            const _BenefitRow(
              icon: Icons.school_rounded,
              title: 'FP3級専用',
              body: 'FP2級は別アプリとして分離',
            ),
            const SizedBox(height: 18),
            if (store.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  store.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD93843),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (store.statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  store.statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF14804A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (store.isPremium)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('全600問 解放済み'),
              )
            else
              FilledButton.icon(
                onPressed: store.purchasePending || store.isLoading
                    ? null
                    : store.buyFullUnlock,
                icon: store.purchasePending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: Text(
                  store.isLoading
                      ? '価格を確認中'
                      : '全600問を解放　${store.priceLabel}',
                ),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: store.isRestoring || store.purchasePending || store.isLoading
                  ? null
                  : store.restorePurchases,
              child: Text(store.isRestoring ? '復元中…' : '購入を復元'),
            ),
            const Text(
              '価格はApp Storeに表示される金額が適用されます。購入前に確認画面が表示されます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A94A6),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF265DFF)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.store,
  });

  final String title;
  final List<Question> questions;
  final ProgressStore store;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const int _questionMilliseconds = 15000;
  static const Duration _feedbackDuration = Duration(milliseconds: 700);
  static const double _swipeThreshold = 36;
  static const double _flickDistance = 24;
  static const double _flickVelocity = 600;

  Timer? _timer;
  DateTime? _deadline;
  int _index = 0;
  int _correct = 0;
  int _timeouts = 0;
  double _remaining = 1;
  double _dragX = 0;
  bool _dragging = false;
  bool _locked = false;
  bool? _selected;
  bool? _lastCorrect;
  bool _finished = false;
  final QuizSessionScore _sessionScore = QuizSessionScore();
  final List<Question> _wrongQuestions = <Question>[];

  Question get _question => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _deadline = DateTime.now().add(
      const Duration(milliseconds: _questionMilliseconds),
    );
    _remaining = 1;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (Timer timer) {
      if (!mounted || _locked || _finished) {
        return;
      }
      final int left =
          _deadline!.difference(DateTime.now()).inMilliseconds.clamp(
                0,
                _questionMilliseconds,
              ).toInt();
      setState(() {
        _remaining = left / _questionMilliseconds;
      });
      if (left <= 0) {
        _submit(null);
      }
    });
  }

  Future<void> _submit(bool? selected) async {
    if (_locked || _finished) {
      return;
    }
    _locked = true;
    _timer?.cancel();

    final bool isCorrect = selected == _question.answer;
    _sessionScore.register(
      isCorrect: isCorrect,
      remainingFraction: _remaining,
    );
    if (selected == null) {
      _timeouts += 1;
    }
    if (isCorrect) {
      _correct += 1;
      HapticFeedback.lightImpact();
    } else {
      _wrongQuestions.add(_question);
      HapticFeedback.mediumImpact();
    }
    await widget.store.recordAnswer(_question, isCorrect);

    if (!mounted) {
      return;
    }
    setState(() {
      _selected = selected;
      _lastCorrect = isCorrect;
      _remaining = 0;
      _dragX = 0;
      _dragging = false;
    });

    await Future<void>.delayed(_feedbackDuration);
    if (!mounted) {
      return;
    }
    _advance();
  }

  void _advance() {
    if (_index + 1 >= widget.questions.length) {
      _timer?.cancel();
      setState(() {
        _finished = true;
        _locked = false;
      });
      return;
    }
    setState(() {
      _index += 1;
      _selected = null;
      _lastCorrect = null;
      _locked = false;
      _dragX = 0;
      _dragging = false;
    });
    _startTimer();
  }


  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_locked || _finished) return;
    setState(() {
      _dragging = true;
      _dragX = (_dragX + details.delta.dx).clamp(-140.0, 140.0).toDouble();
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_locked || _finished) return;
    final double releasedAt = _dragX;
    final double velocity = details.primaryVelocity ?? 0;
    final bool quickFlick = releasedAt.abs() >= _flickDistance &&
        velocity.abs() >= _flickVelocity;
    if (releasedAt >= _swipeThreshold || (quickFlick && releasedAt > 0)) {
      setState(() {
        _dragging = false;
        _dragX = 0;
      });
      _submit(true);
      return;
    }
    if (releasedAt <= -_swipeThreshold || (quickFlick && releasedAt < 0)) {
      setState(() {
        _dragging = false;
        _dragX = 0;
      });
      _submit(false);
      return;
    }
    setState(() {
      _dragging = false;
      _dragX = 0;
    });
  }

  void _onHorizontalDragCancel() {
    if (_locked || _finished) return;
    setState(() {
      _dragging = false;
      _dragX = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _ResultView(
        title: widget.title,
        correct: _correct,
        total: widget.questions.length,
        timeouts: _timeouts,
        score: _sessionScore.score,
        bestCombo: _sessionScore.bestCombo,
        wrongQuestions: _wrongQuestions,
        store: widget.store,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _sessionScore.combo > 1
                              ? '${_sessionScore.combo} COMBO ・ ${_sessionScore.score} pt'
                              : '${_sessionScore.score} pt',
                          style: TextStyle(
                            color: _sessionScore.combo > 1
                                ? const Color(0xFFE07900)
                                : const Color(0xFF8A94A6),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${_index + 1}/${widget.questions.length}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _remaining,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE6EAF2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remaining < 0.33
                        ? const Color(0xFFE5484D)
                        : const Color(0xFF265DFF),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onHorizontalDragCancel: _onHorizontalDragCancel,
                  child: AnimatedRotation(
                    turns: _dragX / 7000,
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      transform: Matrix4.translationValues(_dragX, 0, 0),
                      child: Stack(
                      children: <Widget>[
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            key: ValueKey<String>(_question.id),
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF3FF),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        _question.domain,
                                        style: const TextStyle(
                                          color: Color(0xFF265DFF),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _question.topic,
                                      style: const TextStyle(
                                        color: Color(0xFF8A94A6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Text(
                                  'この文章は正しい？',
                                  style: TextStyle(
                                    color: Color(0xFF8A94A6),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _question.statement,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    height: 1.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Spacer(),
                                if (_lastCorrect != null)
                                  _FeedbackBox(
                                    correct: _lastCorrect!,
                                    selected: _selected,
                                    question: _question,
                                  )
                                else
                                  const Text(
                                    'タップ、または左右スワイプで回答',
                                    style: TextStyle(
                                      color: Color(0xFF8A94A6),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!_locked && _dragX.abs() > 12)
                          Positioned(
                            top: 22,
                            left: _dragX > 0 ? 22 : null,
                            right: _dragX < 0 ? 22 : null,
                            child: _SwipeBadge(isTrue: _dragX > 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '右スワイプ＝○　左スワイプ＝×',
                style: TextStyle(
                  color: Color(0xFF8A94A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _AnswerButton(
                      label: '○',
                      caption: '正しい',
                      color: const Color(0xFF14804A),
                      onTap: _locked ? null : () => _submit(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnswerButton(
                      label: '×',
                      caption: '誤り',
                      color: const Color(0xFFD93843),
                      onTap: _locked ? null : () => _submit(false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SwipeBadge extends StatelessWidget {
  const _SwipeBadge({required this.isTrue});

  final bool isTrue;

  @override
  Widget build(BuildContext context) {
    final Color color =
        isTrue ? const Color(0xFF14804A) : const Color(0xFFD93843);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isTrue ? '○ 正しい' : '× 誤り',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 38,
                height: 0.9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({
    required this.correct,
    required this.selected,
    required this.question,
  });

  final bool correct;
  final bool? selected;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final Color color =
        correct ? const Color(0xFF14804A) : const Color(0xFFD93843);
    final String title = correct
        ? '正解'
        : selected == null
            ? '時間切れ'
            : '不正解';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '$title　答えは${question.answer ? '○' : '×'}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            question.explanation,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.title,
    required this.correct,
    required this.total,
    required this.timeouts,
    required this.score,
    required this.bestCombo,
    required this.wrongQuestions,
    required this.store,
  });

  final String title;
  final int correct;
  final int total;
  final int timeouts;
  final int score;
  final int bestCombo;
  final List<Question> wrongQuestions;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final int percentage = (correct / total * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Container(
                width: 98,
                height: 98,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFF265DFF),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '完了',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              Text(
                '$correct / $total',
                style: const TextStyle(
                  fontSize: 56,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF265DFF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正答率 $percentage%　時間切れ $timeouts問',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$score pt　最高 $bestCombo COMBO',
                style: const TextStyle(
                  color: Color(0xFFE07900),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (wrongQuestions.isNotEmpty) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement<void, void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => QuizScreen(
                          title: '今回のミス',
                          questions: List<Question>.of(wrongQuestions)
                            ..shuffle(),
                          store: store,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('今回のミス ${wrongQuestions.length}問を復習'),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ホームへ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.store,
    required this.questions,
  });

  final ProgressStore store;
  final List<Question> questions;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final ProgressStore store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('学習データ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: '総回答',
                  value: '${store.totalAnswers}問',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: '総正解',
                  value: '${store.totalCorrect}問',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: '最長連続',
                  value: '${store.longestStreak}日',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            '分野別',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...fpDomains.map((String domain) {
            final double accuracy = store.domainAccuracy(domain, widget.questions);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          domain,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${(accuracy * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: accuracy,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final bool? approved = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('学習データを削除'),
                  content: const Text('回答履歴と連続学習日数をすべて削除します。'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('削除'),
                    ),
                  ],
                ),
              );
              if (approved == true) {
                await store.resetAll();
                if (mounted) {
                  setState(() {});
                }
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('学習データを初期化'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
