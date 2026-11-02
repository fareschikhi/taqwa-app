import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_text.dart';

/// A message cut to [maxLines], with `اقرأ المزيد` to open the rest.
///
/// The toggle only appears when the text really runs past [maxLines] at the
/// width it is given: a short note gets no button promising more that isn't
/// there. Once open, `عرض أقل` folds it back.
///
/// Overflow is read off the laid-out paragraph after the frame rather than
/// measured in a [LayoutBuilder], because the note timeline sits inside an
/// [IntrinsicHeight] and a [LayoutBuilder] cannot answer intrinsic sizes.
class ExpandableText extends StatefulWidget {
  const ExpandableText(
    this.text, {
    super.key,
    required this.maxLines,
    this.style,
    this.textAlign = TextAlign.end,
  });

  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  final _textKey = GlobalKey();
  bool _expanded = false;
  bool _overflows = false;

  @override
  void didUpdateWidget(ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An edited message is a new message: show it folded, measured afresh.
    if (oldWidget.text != widget.text) _expanded = false;
  }

  /// Reads whether the folded paragraph hit its line limit. Re-run after
  /// every folded build, so a new width (rotation, a resized pane) is seen.
  void _measure() {
    if (!mounted || _expanded) return;
    final paragraph = _textKey.currentContext?.findRenderObject();
    if (paragraph is! RenderParagraph) return;
    final overflows = paragraph.didExceedMaxLines;
    if (overflows != _overflows) setState(() => _overflows = overflows);
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.text,
          key: _textKey,
          style: widget.style,
          textAlign: widget.textAlign,
          textDirection: AppText.directionOf(widget.text),
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        if (_overflows)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              minimumSize: Size(0, 32.h),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
            child: AppText(
              _expanded ? 'عرض أقل' : 'اقرأ المزيد',
              style: AppTextStyles.labelMdBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
