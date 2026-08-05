import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/app_button.dart';
import 'create_parent_page.dart';
import '../admin_shell.dart';

class ParentsManagementPage extends StatefulWidget {
  const ParentsManagementPage({super.key});

  @override
  State<ParentsManagementPage> createState() => _ParentsManagementPageState();
}

class _ParentsManagementPageState extends State<ParentsManagementPage> {
  int _filterIndex = 0;
  final _searchController = TextEditingController();

  final _parents = [
    _Parent(
      name: 'خالد محمد العمري',
      phone: '+966 50 111 2233',
      students: 2,
      relation: 'أب',
      isActive: true,
    ),
    _Parent(
      name: 'سعد عبدالله الشمري',
      phone: '+966 55 444 5566',
      students: 1,
      relation: 'أب',
      isActive: true,
    ),
    _Parent(
      name: 'أحمد يوسف الغامدي',
      phone: '+966 54 777 8899',
      students: 3,
      relation: 'أب',
      isActive: false,
    ),
    _Parent(
      name: 'فاطمة علي الزهراني',
      phone: '+966 56 222 3344',
      students: 1,
      relation: 'أم',
      isActive: true,
    ),
  ];

  List<_Parent> get _filtered {
    final q = _searchController.text;
    var list = q.isEmpty
        ? _parents
        : _parents
              .where((p) => p.name.contains(q) || p.phone.contains(q))
              .toList();
    if (_filterIndex == 1) list = list.where((p) => p.isActive).toList();
    if (_filterIndex == 2) list = list.where((p) => !p.isActive).toList();
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => AdminShellScope.of(context)?.openMenu(),
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'تقوى',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'أولياء الأمور',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'متابعة التواصل مع أولياء أمور الطلاب.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    AppButton(
                      label: 'إضافة ولي أمر جديد',
                      variant: AppButtonVariant.gradient,
                      icon: Icons.person_add,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateParentPage(),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SearchBarWidget(
                      hint: 'ابحث عن ولي أمر...',
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: 12.h),
                    FilterChipGroup(
                      filters: ['الكل (${_parents.length})', 'نشط', 'غير نشط'],
                      onChanged: (i) => setState(() => _filterIndex = i),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _filtered.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: 300.h,
                          alignment: Alignment.center,
                          child: Text(
                            'لا يوجد أولياء أمور',
                            style: AppTextStyles.bodyMd
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) => SizedBox(height: 16.h),
                        itemBuilder: (_, i) => _ParentCard(parent: _filtered[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Parent {
  const _Parent({
    required this.name,
    required this.phone,
    required this.students,
    required this.relation,
    required this.isActive,
  });
  final String name, phone, relation;
  final int students;
  final bool isActive;
}

class _ParentCard extends StatelessWidget {
  const _ParentCard({required this.parent});
  final _Parent parent;

  @override
  Widget build(BuildContext context) {
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
      padding: EdgeInsets.all(20.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                      ),
                      child: Text(
                        parent.relation,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  parent.name,
                  style: AppTextStyles.bodyMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.end,
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      parent.phone,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${parent.students} طالب مرتبط',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    const Icon(Icons.group, size: 14, color: AppColors.primary),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SmallAction(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () {},
                    ),
                    SizedBox(width: 8.w),
                    _SmallAction(
                      icon: Icons.edit_outlined,
                      color: AppColors.onSurfaceVariant,
                      onTap: () {},
                    ),
                    SizedBox(width: 8.w),
                    _SmallAction(
                      icon: Icons.visibility_outlined,
                      color: AppColors.primary,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                parent.name.isNotEmpty ? parent.name[0] : '؟',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: color, size: 20.w),
  );
}
