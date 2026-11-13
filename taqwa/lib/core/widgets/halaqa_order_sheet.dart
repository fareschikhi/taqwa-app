import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/providers/halaqa_order_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// A halaqa as the order sheet lists it.
typedef HalaqaOrderItem = ({int id, String name});

/// What every grouped screen does on a header long press: shows [halaqas]
/// (in the order on screen) in the sheet and saves the result as the user's
/// order, which reorders every screen watching [halaqaOrderProvider].
Future<void> reorderHalaqas(
  BuildContext context,
  WidgetRef ref,
  List<HalaqaOrderItem> halaqas,
) async {
  final order = await HalaqaOrderSheet.show(context, halaqas);
  if (order == null) return;
  await ref.read(halaqaOrderProvider.notifier).save(order);
}

/// The halaqas of [groups] for the sheet, skipping the unassigned bucket.
/// Null when there are fewer than two, since one halaqa has nothing to swap
/// with; a screen passes that straight to [HalaqaGroupSection.onReorder].
List<HalaqaOrderItem>? reorderableHalaqas<T>(
  Iterable<T> groups, {
  required int? Function(T group) idOf,
  required String Function(T group) nameOf,
}) {
  final items = [
    for (final g in groups)
      if (idOf(g) case final int id) (id: id, name: nameOf(g)),
  ];
  return items.length < 2 ? null : items;
}

/// Lets the user drag halaqas into the order every grouped screen shows them
/// in. Lists halaqas only: the unassigned bucket always stays last.
class HalaqaOrderSheet extends StatefulWidget {
  const HalaqaOrderSheet({super.key, required this.halaqas});

  final List<HalaqaOrderItem> halaqas;

  /// Opens the sheet with [halaqas] in their current order; resolves to the
  /// new order of ids on save, or null when closed without saving.
  static Future<List<int>?> show(
    BuildContext context,
    List<HalaqaOrderItem> halaqas,
  ) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HalaqaOrderSheet(halaqas: halaqas),
    );
  }

  @override
  State<HalaqaOrderSheet> createState() => _HalaqaOrderSheetState();
}

class _HalaqaOrderSheetState extends State<HalaqaOrderSheet> {
  late final List<HalaqaOrderItem> _items = [...widget.halaqas];

  void _move(int from, int to) {
    setState(() => _items.insert(to, _items.removeAt(from)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(
                    () => _items.sort((a, b) => a.name.compareTo(b.name)),
                  ),
                  icon: Icon(Icons.sort_by_alpha, size: 18.w),
                  label: AppText('ترتيب أبجدي', style: AppTextStyles.labelSm),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppText(
                    'ترتيب الحلقات',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            AppText(
              'اسحب الحلقة من المقبض لتغيير مكانها. يُحفظ الترتيب على هذا الجهاز.',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 12.h),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorderItem: _move,
                itemBuilder: (_, i) => _HalaqaOrderRow(
                  key: ValueKey(_items[i].id),
                  index: i,
                  item: _items[i],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: 'حفظ الترتيب',
              variant: AppButtonVariant.gradient,
              icon: Icons.check,
              onPressed: () =>
                  Navigator.of(context).pop([for (final h in _items) h.id]),
            ),
            SizedBox(height: 8.h),
            AppButton(
              label: 'إلغاء',
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One halaqa in the sheet: its place number and name on the right, the drag
/// handle on the left. A long press anywhere on the row also starts a drag.
class _HalaqaOrderRow extends StatelessWidget {
  const _HalaqaOrderRow({super.key, required this.index, required this.item});

  final int index;
  final HalaqaOrderItem item;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  key: ValueKey('halaqa-order-handle-${item.id}'),
                  index: index,
                  child: Tooltip(
                    message: 'اسحب لتغيير الترتيب',
                    child: SizedBox(
                      width: 44.w,
                      height: 44.w,
                      child: Icon(
                        Icons.drag_indicator,
                        color: AppColors.onSurfaceVariant,
                        size: 22.w,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppText(
                    item.name,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMdBold.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 28.w,
                  height: 28.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusFull,
                    ),
                  ),
                  child: AppText(
                    '${index + 1}',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
