import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';

/// How a management page lays out its cards: one wide card per row, or a
/// grid of compact ones.
enum ListLayout { list, grid }

/// Remembers each page's layout on this phone, so the admin's choice is still
/// there the next time the page opens. Per page, because someone may want
/// students in a grid and parents in a list.
class ListLayoutStore {
  const ListLayoutStore._();

  static String keyFor(String page) => 'list_layout_$page';

  /// Falls back to [ListLayout.list], the layout every page had before the
  /// choice existed, when nothing is stored or storage can't be read.
  static Future<ListLayout> read(String page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(page));
      return ListLayout.values.firstWhere(
        (l) => l.name == raw,
        orElse: () => ListLayout.list,
      );
    } catch (_) {
      return ListLayout.list;
    }
  }

  static Future<void> write(String page, ListLayout layout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(page), layout.name);
    } catch (_) {
      // Losing the choice only means the page opens as a list next time.
    }
  }
}

/// Two-button switch between [ListLayout.list] and [ListLayout.grid], sized
/// to sit beside the search bar.
class ListLayoutToggle extends StatelessWidget {
  const ListLayoutToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ListLayout value;
  final ValueChanged<ListLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(ListLayout.grid, Icons.grid_view_rounded, 'عرض شبكي'),
          SizedBox(width: 4.w),
          _button(ListLayout.list, Icons.view_agenda_outlined, 'عرض قائمة'),
        ],
      ),
    );
  }

  Widget _button(ListLayout layout, IconData icon, String label) {
    final selected = value == layout;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
            onTap: selected ? null : () => onChanged(layout),
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Icon(
                icon,
                size: 20.w,
                color: selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon-only action button for a grid card, where a labelled button would
/// not fit. Meant to sit in an [Expanded] so a card's actions share its width.
class GridCardAction extends StatelessWidget {
  const GridCardAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
    this.background,
    this.border,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            color: background,
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Icon(icon, size: 18.w, color: color),
        ),
      ),
    );
  }
}

/// Cards per row for a grid [width] wide: two on a phone, more on a tablet.
int cardGridColumns(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// One row of a card grid. Cards in a row share the tallest one's height, and
/// the row fills from the right to match the app's Arabic reading order. A
/// short last row keeps empty slots so its cards stay the same width.
class CardGridRow extends StatelessWidget {
  const CardGridRow({
    super.key,
    required this.columns,
    required this.children,
  });

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) SizedBox(width: 12.w),
            Expanded(
              child: i < children.length ? children[i] : const SizedBox(),
            ),
          ],
        ],
      ),
    );
  }
}

/// A non-scrolling grid of [children], for a grid that lives inside another
/// scroll view, such as a halaqa section.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = cardGridColumns(constraints.maxWidth);
        return Column(
          children: [
            for (var i = 0; i < children.length; i += columns)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: CardGridRow(
                  columns: columns,
                  children: children.sublist(
                    i,
                    (i + columns).clamp(0, children.length),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
