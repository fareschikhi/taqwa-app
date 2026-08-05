import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../features/data/repositories/absence_justification_repository.dart';
import '../../../../features/data/models/absence_justification_model.dart';

class JustificationListPage extends ConsumerStatefulWidget {
  const JustificationListPage({super.key});

  @override
  ConsumerState<JustificationListPage> createState() =>
      _JustificationListPageState();
}

class _JustificationListPageState
    extends ConsumerState<JustificationListPage> {
  final _repo = AbsenceJustificationRepository();
  List<AbsenceJustificationModel> _justifications = [];
  bool _isLoading = true;
  int? _managerId;

  @override
  void initState() {
    super.initState();
    _loadJustifications();
  }

  Future<void> _loadJustifications() async {
    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.id;
      final dio = DioClient.instance;

      final managersRes = await dio.get(ApiEndpoints.managers);
      final allManagers = managersRes.data as List;
      final myManager = allManagers.firstWhere(
        (m) => m['user']?['id'] == userId,
        orElse: () => null,
      );
      if (myManager != null) {
        _managerId = myManager['id'];
      }

      final list = await _repo.getAllJustifications(
        managerId: _managerId,
      );

      if (mounted) {
        setState(() {
          _justifications = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadJustifications,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      'تقوى',
                      style: AppTextStyles.headlineMd.copyWith(
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'تبريرات الغياب',
                      style: AppTextStyles.headlineLgMobile
                          .copyWith(color: AppColors.onSurface),
                    ),
                    Text(
                      'سجل تبريرات الغياب للطلاب',
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : _justifications.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: 350.h,
                              alignment: Alignment.center,
                              child: _buildEmptyState(),
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: _justifications.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: 12.h),
                            itemBuilder: (_, i) =>
                                _JustificationCard(item: _justifications[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rule_outlined,
              size: 40.w,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد تبريرات بعد',
            style: AppTextStyles.headlineSm
                .copyWith(color: AppColors.onSurface),
          ),
          SizedBox(height: 8.h),
          Text(
            'ستظهر هنا تبريرات الغياب التي تضيفها',
            style: AppTextStyles.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _JustificationCard extends StatelessWidget {
  const _JustificationCard({required this.item});
  final AbsenceJustificationModel item;

  @override
  Widget build(BuildContext context) {
    final attendance =
        item.attendance ?? {};
    final dateStr = attendance['date'] as String? ?? '';
    final date = dateStr.isNotEmpty
        ? DateTime.tryParse(dateStr)
        : null;
    final formattedDate = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : 'غير محدد';

    final reasonColors = {
      'ILLNESS': AppColors.errorContainer,
      'OCCASION': AppColors.secondaryContainer,
      'OTHER': AppColors.tertiaryContainer,
    };
    final reasonFgColors = {
      'ILLNESS': AppColors.onErrorContainer,
      'OCCASION': AppColors.onSecondaryContainer,
      'OTHER': AppColors.onTertiaryContainer,
    };
    final bgColor =
        reasonColors[item.reasonType] ?? AppColors.tertiaryContainer;
    final fgColor =
        reasonFgColors[item.reasonType] ?? AppColors.onTertiaryContainer;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  item.reasonLabel,
                  style:
                      AppTextStyles.labelSm.copyWith(color: fgColor),
                ),
              ),
              Text(
                item.studentName,
                style: AppTextStyles.headlineSm
                    .copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'تاريخ الغياب',
                      style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    item.notes!,
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.right,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
