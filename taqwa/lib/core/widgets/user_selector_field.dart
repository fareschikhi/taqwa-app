import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'avatar_widget.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// A person that can be picked in a [UserSelectorField].
///
/// Deliberately just an id, a name and an avatar: the selector is shared by
/// student, teacher and parent pickers, so anything role-specific belongs in
/// the caller, not here.
class UserOption {
  const UserOption({required this.id, required this.fullName, this.avatar});

  final int id;
  final String fullName;
  final String? avatar;

  /// Builds an option from the `{ id, user: { fullName, avatar } }` shape the
  /// API returns for students, teachers and parents.
  factory UserOption.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return UserOption(
      id: json['id'] as int,
      fullName: user?['fullName'] as String? ?? 'غير معروف',
      avatar: user?['avatar'] as String?,
    );
  }
}

/// Searchable person picker showing each candidate's avatar and full name.
///
/// The selection is controlled: pass [selectedId] and update it from
/// [onSelected].
class UserSelectorField extends StatefulWidget {
  const UserSelectorField({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.label,
    this.hint = 'ابحث واختر',
    this.searchHint = 'ابحث بالاسم',
    this.emptyText = 'لا توجد نتائج',
    this.enabled = true,
    this.maxPanelHeight,
  });

  final List<UserOption> options;
  final int? selectedId;
  final ValueChanged<UserOption> onSelected;
  final String? label;
  final String hint;
  final String searchHint;
  final String emptyText;
  final bool enabled;

  /// Height cap for the results list. Defaults to 200.h.
  final double? maxPanelHeight;

  @override
  State<UserSelectorField> createState() => _UserSelectorFieldState();
}

class _UserSelectorFieldState extends State<UserSelectorField> {
  final _searchController = TextEditingController();
  bool _isOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UserSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Close and reset when the caller clears the selection (e.g. after a form
    // submit), so the panel doesn't linger with a stale query.
    if (widget.selectedId == null && oldWidget.selectedId != null) {
      _searchController.clear();
      _isOpen = false;
    }
  }

  UserOption? get _selected {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final o in widget.options) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<UserOption> get _results {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.fullName.toLowerCase().contains(q))
        .toList();
  }

  Widget _avatar(UserOption option, double size) {
    final initial = option.fullName.trim().isNotEmpty
        ? option.fullName.trim()[0]
        : '؟';
    return AvatarWidget(
      avatarUrl: option.avatar,
      size: size,
      fallback: AppText(
        initial,
        style: AppTextStyles.labelMd.copyWith(
          color: AppColors.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AppText(
            widget.label!,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 6.h),
        ],
        _buildField(),
        if (_isOpen && widget.enabled) ...[
          SizedBox(height: 8.h),
          _buildPanel(),
        ],
      ],
    );
  }

  Widget _buildField() {
    final selected = _selected;

    return GestureDetector(
      onTap: widget.enabled ? () => setState(() => _isOpen = !_isOpen) : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: widget.enabled
              ? AppColors.surfaceContainerLowest
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: _isOpen ? AppColors.inputFocusBorder : AppColors.inputBorder,
            width: _isOpen ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isOpen ? Icons.expand_less : Icons.expand_more,
              color: AppColors.onSurfaceVariant,
              size: 22.w,
            ),
            Expanded(
              child: AppText(
                selected?.fullName ?? widget.hint,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd.copyWith(
                  color: selected == null
                      ? AppColors.inputPlaceholder
                      : AppColors.onSurface,
                ),
              ),
            ),
            if (selected != null) ...[
              SizedBox(width: 10.w),
              _avatar(selected, 32.w),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final results = _results;

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
            autofocus: true,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: widget.searchHint,
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
            constraints: BoxConstraints(
              maxHeight: widget.maxPanelHeight ?? 200.h,
            ),
            child: results.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: AppText(
                      widget.emptyText,
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
        ],
      ),
    );
  }

  Widget _buildRow(UserOption option) {
    final isSelected = option.id == widget.selectedId;

    return InkWell(
      onTap: () {
        setState(() {
          _isOpen = false;
          _searchController.clear();
        });
        widget.onSelected(option);
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                option.fullName,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd.copyWith(
                  color: isSelected
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurface,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            _avatar(option, 36.w),
          ],
        ),
      ),
    );
  }
}
