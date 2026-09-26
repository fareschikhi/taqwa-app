import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../data/models/parent/parent_child_model.dart';
import '../pages/student_details_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// One of a parent's linked students: photo, name and halaqa. Tapping it
/// opens that student's details page. Shared by the parent form and the
/// parent details page so both list the children the same way.
class LinkedStudentTile extends StatelessWidget {
  const LinkedStudentTile({super.key, required this.student});

  final ParentChildModel student;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentDetailsPage(
            studentId: student.id,
            fullName: student.fullName,
            avatar: student.avatar,
            halaqaId: student.halaqaId,
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          children: [
            AvatarWidget(
              avatarUrl: student.avatar,
              size: 40.w,
              fallback: AppText(
                student.fullName.isNotEmpty ? student.fullName[0] : '؟',
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
            SizedBox(width: 12.w),
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
                    student.halaqaName ?? 'بدون حلقة',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left,
              color: AppColors.onSurfaceVariant,
              size: 20.w,
            ),
          ],
        ),
      ),
    );
  }
}
