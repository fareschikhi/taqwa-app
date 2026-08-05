import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notifications = [
    _Notif(
      title: 'حضور مسجّل بنجاح',
      body: 'تم تسجيل حضور حلقة النور بتاريخ 11/06/2026.',
      time: 'منذ 5 دقائق',
      icon: Icons.how_to_reg,
      bgColor: AppColors.primaryContainer,
      iconColor: AppColors.onPrimaryContainer,
      isRead: false,
    ),
    _Notif(
      title: 'ملاحظة جديدة من المعلم',
      body: 'أضاف الشيخ أحمد ملاحظة على أداء عمر في جلسة اليوم.',
      time: 'منذ ساعة',
      icon: Icons.edit_note,
      bgColor: AppColors.secondaryContainer,
      iconColor: AppColors.onSecondaryContainer,
      isRead: false,
    ),
    _Notif(
      title: 'تقييم جديد',
      body: 'تم إضافة تقييم شهري لطلاب حلقة الفرقان.',
      time: 'منذ 3 ساعات',
      icon: Icons.star_outline,
      bgColor: AppColors.tertiaryContainer,
      iconColor: AppColors.onTertiaryContainer,
      isRead: true,
    ),
    _Notif(
      title: 'إنجاز جديد لعمر',
      body: 'أتمّ عمر حفظ الجزء التاسع عشر — مبروك!',
      time: 'أمس',
      icon: Icons.emoji_events,
      bgColor: const Color(0xFFFFF9C4),
      iconColor: AppColors.warning,
      isRead: true,
    ),
    _Notif(
      title: 'تذكير: موعد الاختبار الشهري',
      body: 'سيُعقد الاختبار الشهري للطلاب يوم الخميس القادم بعد صلاة العصر.',
      time: 'منذ يومين',
      icon: Icons.campaign,
      bgColor: AppColors.surfaceVariant,
      iconColor: AppColors.onSurfaceVariant,
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(children: [
                      if (unreadCount > 0)
                        GestureDetector(
                          onTap: () => setState(() {
                            for (final n in _notifications) { n.isRead = true; }
                          }),
                          child: Text('تحديد الكل كمقروء',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.primary)),
                        ),
                      const Spacer(),
                      if (unreadCount > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                          ),
                          child: Text('$unreadCount جديد',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.onError)),
                        ),
                      SizedBox(width: 8.w),
                      Text('الإشعارات',
                          style: AppTextStyles.headlineLgMobile.copyWith(color: AppColors.onSurface)),
                    ]),
                    SizedBox(height: 4.h),
                    Text('$unreadCount إشعارات غير مقروءة',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (_, i) {
                  final n = _notifications[i];
                  return GestureDetector(
                    onTap: () => setState(() => n.isRead = true),
                    child: AnimatedContainer(
                      duration: AppConstants.animFast,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: n.isRead
                            ? AppColors.surfaceContainerLowest
                            : AppColors.primaryContainer.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                        border: Border.all(
                          color: n.isRead ? AppColors.outlineVariant : AppColors.primaryContainer,
                        ),
                        boxShadow: const [BoxShadow(
                          color: Color.fromRGBO(18, 52, 59, 0.04), blurRadius: 12, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(children: [
                            SizedBox(height: 2.h),
                            if (!n.isRead)
                              Container(
                                width: 8.w, height: 8.w,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary, shape: BoxShape.circle),
                              ),
                          ]),
                          SizedBox(width: n.isRead ? 0 : 8.w),
                          const Spacer(),
                          Expanded(
                            flex: 9,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(children: [
                                  Text(n.time,
                                      style: AppTextStyles.caption.copyWith(color: AppColors.outline)),
                                  const Spacer(),
                                  Text(n.title,
                                      style: AppTextStyles.labelMdBold.copyWith(
                                          color: n.isRead ? AppColors.onSurface : AppColors.primary)),
                                ]),
                                SizedBox(height: 4.h),
                                Text(n.body,
                                    style: AppTextStyles.labelSm.copyWith(
                                        color: AppColors.onSurfaceVariant, height: 1.5),
                                    textAlign: TextAlign.end),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Container(
                            width: 40.w, height: 40.w,
                            decoration: BoxDecoration(color: n.bgColor, shape: BoxShape.circle),
                            child: Icon(n.icon, color: n.iconColor, size: 20.w),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _Notif {
  _Notif({required this.title, required this.body, required this.time,
    required this.icon, required this.bgColor, required this.iconColor,
    required this.isRead});
  final String title, body, time;
  final IconData icon;
  final Color bgColor, iconColor;
  bool isRead;
}

