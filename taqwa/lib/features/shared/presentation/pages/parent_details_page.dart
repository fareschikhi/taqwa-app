import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/telegram.dart';
import '../../../data/models/parent/parent_model.dart';
import '../../../data/repositories/parent_repository.dart';
import '../widgets/linked_student_tile.dart';
import '../widgets/profile_detail_widgets.dart';
import 'parent_form_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// A parent's profile: contact details and linked students. Shared by the
/// admin and the manager parents lists, which open it by tapping a card.
///
/// Pops `true` when the parent was edited from here, so the list behind it
/// knows to reload.
class ParentDetailsPage extends StatefulWidget {
  const ParentDetailsPage({
    super.key,
    required this.parent,
    this.canEdit = false,
  });

  /// The row from the list, rendered straight away. GET /parents returns the
  /// same include as GET /parents/:id, so there is nothing missing to wait
  /// for; the page only re-fetches on pull-to-refresh or after an edit.
  final ParentModel parent;

  /// Whether the header shows the edit button that opens [ParentFormPage].
  final bool canEdit;

  @override
  State<ParentDetailsPage> createState() => _ParentDetailsPageState();
}

class _ParentDetailsPageState extends State<ParentDetailsPage> {
  final _repo = ParentRepository();
  late ParentModel _parent = widget.parent;
  bool _changed = false;

  Future<void> _reload() async {
    final id = _parent.id;
    if (id == null) return;
    try {
      final fresh = await _repo.getParent(id);
      if (mounted) setState(() => _parent = fresh);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(ParentRepository.errorMessage(e))),
      );
    }
  }

  Future<void> _openEdit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ParentFormPage(parent: _parent)),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _parent.children;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ProfileDetailHeader(
                  title: 'ملف ولي الأمر',
                  name: _parent.fullName,
                  avatar: _parent.avatar,
                  isActive: _parent.isActive ?? true,
                  onEdit: widget.canEdit ? _openEdit : null,
                ),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailSectionCard(
                        title: 'معلومات التواصل',
                        children: [
                          DetailInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'رقم الهاتف',
                            value: _parent.phone,
                            isLtr: true,
                          ),
                          // Staff usually reach a parent on Telegram, so the
                          // number opens a chat directly instead of being
                          // copied by hand.
                          if (telegramUri(_parent.phone) != null) ...[
                            SizedBox(height: 12.h),
                            TelegramButton(phone: _parent.phone),
                          ],
                          SizedBox(height: 12.h),
                          DetailInfoRow(
                            icon: Icons.email_outlined,
                            label: 'البريد الإلكتروني',
                            value: _parent.email,
                            isLtr: true,
                          ),
                          SizedBox(height: 12.h),
                          DetailInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'العنوان',
                            value: _parent.address,
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      DetailSectionCard(
                        title: 'الأبناء (${students.length})',
                        children: [
                          if (students.isEmpty)
                            AppText(
                              'لا يوجد طلاب مرتبطون بولي الأمر هذا.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            )
                          else
                            for (final student in students) ...[
                              LinkedStudentTile(student: student),
                              if (student != students.last)
                                SizedBox(height: 8.h),
                            ],
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
