import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/utils/search_text.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import '../constants/app_constants.dart';
import '../constants/surahs.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Picks any number of surahs for one recitation — a child who recites
/// الإخلاص، الفلق and الناس in one go is one entry, not three.
///
/// Built like [UserSelectorField]: the field opens a searchable panel in
/// place. Unlike it, the panel stays open while surahs are ticked, since the
/// teacher usually ticks more than one; «تم» closes it. The selection is
/// controlled and always handed back in mushaf order. An empty selection is
/// a valid answer: the entry then records only its amount.
class SurahMultiSelectField extends StatefulWidget {
  const SurahMultiSelectField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.hint = 'بدون تحديد السورة',
    this.enabled = true,
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  final String hint;
  final bool enabled;

  @override
  State<SurahMultiSelectField> createState() => _SurahMultiSelectFieldState();
}

class _SurahMultiSelectFieldState extends State<SurahMultiSelectField> {
  final _searchController = TextEditingController();
  bool _isOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> get _results => kSurahs
      .where(
        (s) => matchesSearch(_searchController.text, [s.name, '${s.number}']),
      )
      .toList();

  void _toggle(int number) {
    final next = {...widget.selected};
    if (!next.remove(number)) next.add(number);
    widget.onChanged(next.toList()..sort());
  }

  void _close() => setState(() {
    _isOpen = false;
    _searchController.clear();
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildField(),
        if (_isOpen && widget.enabled) ...[
          SizedBox(height: 8.h),
          _buildPanel(),
        ],
      ],
    );
  }

  Widget _buildField() {
    final names = [
      for (final n in widget.selected) surahNameOf(n) ?? '$n',
    ].join('، ');
    final hasSelection = widget.selected.isNotEmpty;

    return Semantics(
      button: true,
      label: hasSelection ? 'السور المختارة: $names' : widget.hint,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        onTap: widget.enabled
            ? () => _isOpen ? _close() : setState(() => _isOpen = true)
            : null,
        child: Container(
          constraints: BoxConstraints(minHeight: 48.h),
          padding: EdgeInsets.only(left: 4.w, right: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: _isOpen
                  ? AppColors.inputFocusBorder
                  : AppColors.inputBorder,
              width: _isOpen ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (hasSelection && widget.enabled)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'إزالة السور',
                  color: AppColors.onSurfaceVariant,
                  onPressed: () => widget.onChanged(const []),
                )
              else
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Icon(
                    _isOpen ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.onSurfaceVariant,
                    size: 22.w,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: AppText(
                    hasSelection ? names : widget.hint,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: hasSelection
                        ? AppTextStyles.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          )
                        : AppTextStyles.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
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

  Widget _buildPanel() {
    final results = _results;
    final count = widget.selected.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: EdgeInsets.all(8.w),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة أو رقمها',
              hintStyle: AppTextStyles.labelMd.copyWith(
                color: AppColors.inputPlaceholder,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.onSurfaceVariant,
                size: 20.w,
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.inputFocusBorder,
                  width: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 240.h),
            child: results.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: AppText(
                      'لا توجد سورة بهذا الاسم',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    itemBuilder: (_, i) => _buildRow(results[i]),
                  ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              TextButton(
                onPressed: _close,
                child: AppText(
                  'تم',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: AppText(
                  count == 0 ? 'لم تُحدَّد سورة' : 'السور المحددة: $count',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A tick at the reading start, the name, and the surah's pages, so the
  /// teacher sees what the counter will add up. The whole row toggles.
  Widget _buildRow(Surah surah) {
    final ticked = widget.selected.contains(surah.number);
    final pages = surah.startPage == surah.endPage
        ? 'ص ${surah.startPage}'
        : 'ص ${surah.startPage}–${surah.endPage}';

    return Semantics(
      checked: ticked,
      label: 'سورة ${surah.name}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _toggle(surah.number),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          padding: EdgeInsets.only(left: 10.w),
          decoration: BoxDecoration(
            color: ticked ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          child: Row(
            children: [
              AppText(
                pages,
                textDirection: TextDirection.rtl,
                style: AppTextStyles.labelMd.copyWith(
                  color: ticked
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: AppText(
                  surah.name,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: ticked
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurface,
                  ),
                ),
              ),
              Checkbox(
                value: ticked,
                activeColor: AppColors.primary,
                onChanged: (_) => _toggle(surah.number),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
