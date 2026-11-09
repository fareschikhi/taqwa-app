import 'package:flutter/material.dart';
import 'package:taqwa/core/utils/search_text.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../data/models/parent/parent_child_model.dart';
import 'linked_student_tile.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Searchable multi-picker for a parent's children: a search box over
/// [candidates], with the picked students listed below it.
///
/// The selection is controlled: the caller owns [selected] and updates it
/// from [onAdd] / [onRemove].
class ChildrenPicker extends StatefulWidget {
  const ChildrenPicker({
    super.key,
    required this.candidates,
    required this.selected,
    required this.onAdd,
    required this.onRemove,
    this.parentId,
    this.isLoading = false,
    this.loadFailed = false,
    this.onRetry,
  });

  /// Every child student that may be picked.
  final List<ParentChildModel> candidates;
  final List<ParentChildModel> selected;
  final ValueChanged<ParentChildModel> onAdd;
  final ValueChanged<ParentChildModel> onRemove;

  /// The parent being edited, so a student already his is not flagged as
  /// held by another parent. Null when creating.
  final int? parentId;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback? onRetry;

  @override
  State<ChildrenPicker> createState() => _ChildrenPickerState();
}

class _ChildrenPickerState extends State<ChildrenPicker> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isOpen =>
      _focusNode.hasFocus || _searchController.text.trim().isNotEmpty;

  List<ParentChildModel> get _results {
    final q = _searchController.text;
    return widget.candidates
        .where((c) => !widget.selected.any((s) => s.id == c.id))
        .where((c) => matchesSearch(q, [c.fullName]))
        .toList();
  }

  bool _heldByAnotherParent(ParentChildModel s) =>
      s.parentId != null && s.parentId != widget.parentId;

  void _add(ParentChildModel student) {
    _searchController.clear();
    _focusNode.unfocus();
    widget.onAdd(student);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBox(),
        if (widget.loadFailed) ...[
          SizedBox(height: 8.h),
          _buildLoadError(),
        ] else if (_isOpen && !widget.isLoading) ...[
          SizedBox(height: 8.h),
          _buildResults(),
        ],
        SizedBox(height: 12.h),
        if (widget.selected.isEmpty)
          AppText(
            'لم يتم اختيار أي طالب بعد.',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          )
        else
          for (final student in widget.selected) ...[
            LinkedStudentTile(
              student: student,
              onRemove: () => widget.onRemove(student),
            ),
            if (student != widget.selected.last) SizedBox(height: 8.h),
          ],
      ],
    );
  }

  Widget _buildSearchBox() {
    final focused = _focusNode.hasFocus;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: focused ? AppColors.inputFocusBorder : AppColors.inputBorder,
          width: focused ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'مسح البحث',
              onPressed: () => setState(_searchController.clear),
              icon: Icon(
                Icons.close,
                color: AppColors.onSurfaceVariant,
                size: 18.w,
              ),
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              enabled: !widget.isLoading && !widget.loadFailed,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: (_) => setState(() {}),
              style: AppTextStyles.bodyMd,
              decoration: InputDecoration(
                hintText: widget.isLoading
                    ? 'جارٍ تحميل الطلاب...'
                    : 'ابحث عن طالب بالاسم...',
                hintStyle: AppTextStyles.labelMd.copyWith(
                  color: AppColors.inputPlaceholder,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 14.h,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: widget.isLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.search, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              child: AppText(
                'إعادة المحاولة',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
              ),
            ),
          Expanded(
            child: AppText(
              'تعذر تحميل قائمة الطلاب.',
              textAlign: TextAlign.right,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Icon(Icons.error_outline, color: AppColors.error, size: 18.w),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = _results;

    return Container(
      constraints: BoxConstraints(maxHeight: 240.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: results.isEmpty
          ? Padding(
              padding: EdgeInsets.all(14.w),
              child: AppText(
                _searchController.text.trim().isEmpty
                    ? 'لا يوجد طلاب متاحون'
                    : 'لا يوجد طلاب مطابقون',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(vertical: 4.h),
              itemCount: results.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.outlineVariant),
              itemBuilder: (_, i) => _buildResultRow(results[i]),
            ),
    );
  }

  Widget _buildResultRow(ParentChildModel student) {
    final heldElsewhere = _heldByAnotherParent(student);

    return InkWell(
      onTap: () => _add(student),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            AvatarWidget(
              avatarUrl: student.avatar,
              size: 36.w,
              fallback: AppText(
                student.fullName.isNotEmpty ? student.fullName[0] : '؟',
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    student.fullName,
                    style: AppTextStyles.labelMdBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  AppText(
                    heldElsewhere
                        ? 'مرتبط بولي أمر آخر — سيُنقل إلى هذا الحساب'
                        : (student.halaqaName ?? 'بدون حلقة'),
                    style: AppTextStyles.labelSm.copyWith(
                      color: heldElsewhere
                          ? AppColors.error
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
              size: 22.w,
            ),
          ],
        ),
      ),
    );
  }
}
