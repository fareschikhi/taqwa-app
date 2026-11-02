import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_fonts.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_logo.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'auth_gate.dart';

/// Opens every launch with the salawat, then hands over to [AuthGate].
///
/// The stored session is read while the intro is on screen rather than after
/// it, so the wait for the token is hidden behind the intro instead of added
/// to it. A tap anywhere skips straight on.
class StartupIntro extends ConsumerStatefulWidget {
  const StartupIntro({super.key});

  /// Entrance animation (1.8s) plus the time the finished screen is held (2.2s).
  static const Duration holdDuration = Duration(milliseconds: 4000);

  @override
  ConsumerState<StartupIntro> createState() => _StartupIntroState();
}

class _StartupIntroState extends ConsumerState<StartupIntro> {
  bool _done = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // Reading the provider builds the notifier, which starts the restore.
    ref.read(authProvider);
    _timer = Timer(StartupIntro.holdDuration, _finish);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _finish() {
    _timer.cancel();
    if (mounted && !_done) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _done
          ? const AuthGate()
          : IntroPage(key: const ValueKey('intro'), onSkip: _finish),
    );
  }
}

/// Replays the intro over [child] when the app comes back to the foreground
/// after being away for at least [awayThreshold].
///
/// It sits above the navigator rather than pushing a route, so whatever page
/// was open is still there, untouched, when the intro fades out. A quick trip
/// away — the photo picker, a glance at a notification — doesn't trigger it.
class ResumeIntro extends StatefulWidget {
  const ResumeIntro({super.key, required this.child});

  final Widget child;

  static const Duration awayThreshold = Duration(minutes: 5);

  @override
  State<ResumeIntro> createState() => _ResumeIntroState();
}

class _ResumeIntroState extends State<ResumeIntro> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;
  Timer? _timer;
  bool _showing = false;
  // A fresh key per replay so the entrance animation starts from the top.
  int _replay = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: _onShow,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null ||
        DateTime.now().difference(hiddenAt) < ResumeIntro.awayThreshold) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(StartupIntro.holdDuration, _finish);
    setState(() {
      _showing = true;
      _replay++;
    });
  }

  void _finish() {
    _timer?.cancel();
    if (mounted && _showing) setState(() => _showing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: _showing, child: widget.child),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _showing
              ? IntroPage(key: ValueKey('resume-$_replay'), onSkip: _finish)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class IntroPage extends StatefulWidget {
  const IntroPage({super.key, this.onSkip});

  final VoidCallback? onSkip;

  static const String salawat = 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ';
  static const String hadith =
      '«مَنْ صَلَّى عَلَيَّ وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ عَشْرًا»';
  static const String hadithSource = 'رواه مسلم';

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: show the finished screen without the entrance.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fades and lifts [child] in over the [begin]–[end] slice of the entrance.
  Widget _reveal(double begin, double end, Widget child) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Semantics(
        button: true,
        label: 'متابعة',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSkip,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ExcludeSemantics(child: _OrnamentBackground()),
              SafeArea(
                // Spacers place the content on a phone; on a short or
                // landscape screen it scrolls instead of overflowing.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _content()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      children: [
        const Spacer(flex: 3),
        _reveal(
          0,
          0.45,
          ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(
              CurvedAnimation(
                parent: _controller,
                curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
              ),
            ),
            child: _DomeHalo(child: AppLogo(height: 96.w)),
          ),
        ),
        SizedBox(height: 40.h),
        _reveal(
          0.25,
          0.7,
          AppText(
            IntroPage.salawat,
            textAlign: TextAlign.center,
            style: AppFonts.amiri(
              fontSize: 38.sp,
              fontWeight: FontWeight.w700,
              // Room above and below for shadda and tanween.
              height: 1.9,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        _OrnamentDivider(
          progress: CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
          ),
        ),
        SizedBox(height: 20.h),
        _reveal(
          0.6,
          1,
          Column(
            children: [
              AppText(
                IntroPage.hadith,
                textAlign: TextAlign.center,
                style: AppFonts.amiri(
                  fontSize: 19.sp,
                  height: 1.9,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              AppText(
                IntroPage.hadithSource,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 4),
        _reveal(
          0.7,
          1,
          AppText(
            'التقوى',
            style: AppTextStyles.bodyMdBold.copyWith(
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}

/// A soft mint glow behind the dome so it sits on light, not on flat paper.
class _DomeHalo extends StatelessWidget {
  const _DomeHalo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168.w,
      height: 168.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.35),
            AppColors.primaryContainer.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Two hairlines meeting at an eight-pointed star, drawn outward from the
/// centre as [progress] runs.
class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final line = Container(
          width: 72.w * t,
          height: 1.2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: AppColors.primaryContainer,
          ),
        );
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              line,
              SizedBox(width: 10.w),
              Transform.rotate(
                angle: (1 - t) * math.pi / 4,
                child: CustomPaint(
                  size: Size.square(18.w),
                  painter: _StarPainter(
                    color: AppColors.primary,
                    fill: AppColors.primaryContainer,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              line,
            ],
          ),
        );
      },
    );
  }
}

/// Faint eight-pointed stars in two opposite corners — the same motif as the
/// divider, large and quiet enough to read as texture.
class _OrnamentBackground extends StatelessWidget {
  const _OrnamentBackground();

  @override
  Widget build(BuildContext context) {
    final big = 260.w;
    final color = AppColors.primary.withValues(alpha: 0.05);
    final star = CustomPaint(
      size: Size.square(big),
      painter: _StarPainter(color: color, strokeWidth: 1.5, rings: 3),
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(top: -big * 0.35, right: -big * 0.35, child: star),
        Positioned(bottom: -big * 0.35, left: -big * 0.35, child: star),
      ],
    );
  }
}

/// An eight-pointed star (two overlapping squares) — the khatam found in
/// mosque tilework — optionally repeated as nested [rings].
class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.color,
    this.fill,
    this.strokeWidth = 1.4,
    this.rings = 1,
  });

  final Color color;
  final Color? fill;
  final double strokeWidth;
  final int rings;

  Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      // Alternate outer points and inner notches; the inner radius is where
      // the two squares' edges cross.
      final radius = i.isEven
          ? r
          : r * math.cos(math.pi / 4) / math.cos(math.pi / 8);
      final angle = -math.pi / 2 + i * math.pi / 8;
      final p = c + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    for (var ring = 0; ring < rings; ring++) {
      final r = size.shortestSide / 2 * (1 - ring / (rings + 0.5));
      final star = _star(c, r - strokeWidth);
      if (ring == 0 && fill != null) {
        canvas.drawPath(star, Paint()..color = fill!);
      }
      canvas.drawPath(star, stroke);
    }
    if (rings > 1) {
      canvas.drawCircle(c, size.shortestSide * 0.12, stroke);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.fill != fill || old.rings != rings;
}
