import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/features/data/repositories/halaqa_repository.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'create_halaqa_page.dart';
import '../admin_shell.dart';

class HalaqasManagementPage extends StatefulWidget {
  const HalaqasManagementPage({super.key});

  @override
  State<HalaqasManagementPage> createState() => _HalaqasManagementPageState();
}

class _HalaqasManagementPageState extends State<HalaqasManagementPage> {
  final _searchController = TextEditingController();
  List<HalaqaModel> _halaqas = [];
  List<HalaqaModel> _filtered = [];
  bool _isLoading = true;
  final _halaqaRepo = HalaqaRepository();

  Future<void> _deleteHalaqa(int id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'حذف الحلقة',
      message: 'سيتم حذف الحلقة نهائياً. '
          'سيبقى الطلاب في النظام دون حلقة مسندة.',
    );
    if (!confirmed) return;
    try {
      await _halaqaRepo.deleteHalaqa(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الحلقة بنجاح')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HalaqaRepository.errorMessage(e))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _halaqaRepo.getAllHalaqas();
      if (mounted) {
        setState(() {
          _halaqas = list;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    _filtered = q.isEmpty
        ? _halaqas
        : _halaqas.where((h) {
            final name = h.name.toLowerCase();
            final teacherName = (h.teacherName ?? '').toLowerCase();
            return name.contains(q) || teacherName.contains(q);
          }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
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
                      'إدارة الحلقات',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'عرض الحلقات وحالاتها والمعلمين المسندين.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SearchBarWidget(
                      hint: 'ابحث عن حلقة أو معلم...',
                      controller: _searchController,
                      onChanged: (_) => setState(() => _applyFilter()),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary))
                    : _filtered.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: 300.h,
                              alignment: Alignment.center,
                              child: Text(
                                'لا توجد حلقات',
                                style: AppTextStyles.bodyMd
                                    .copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          )
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12.w,
                              mainAxisSpacing: 12.h,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _HalaqaCard(
                              halaqa: _filtered[i],
                              onDelete: () => _deleteHalaqa(_filtered[i].id),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_halaqa',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateHalaqaPage()),
        ).then((_) => _load()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.onPrimary),
        label: Text(
          'حلقة جديدة',
          style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
        ),
      ),
    );
  }
}

class _HalaqaCard extends StatelessWidget {
  const _HalaqaCard({required this.halaqa, required this.onDelete});
  final HalaqaModel halaqa;
  final VoidCallback onDelete;

  static const _levelIcons = {
    'متقدم': Icons.wb_sunny,
    'متوسط': Icons.auto_awesome,
    'مبتدئ': Icons.menu_book,
  };

  Color _levelColor(String level) {
    switch (level) {
      case 'متقدم':
        return AppColors.primary;
      case 'متوسط':
        return AppColors.secondary;
      default:
        return AppColors.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = halaqa.name;
    final level = halaqa.level ?? '';
    final teacherName = halaqa.teacherName ?? '';
    final studentCount = halaqa.studentCount;
    final icon = _levelIcons[level] ?? Icons.local_library;
    final levelColor = _levelColor(level);

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
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined),
                    iconSize: 18.w,
                    color: AppColors.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 18.w,
                    color: AppColors.error,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(icon, color: AppColors.onPrimary, size: 26.w),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            name,
            style: AppTextStyles.headlineSm
                .copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.end,
          ),
          SizedBox(height: 4.h),
          Text(
            teacherName.isNotEmpty ? teacherName : '—',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  level.isNotEmpty ? level : '—',
                  style: AppTextStyles.labelSm.copyWith(color: levelColor),
                ),
              ),
              Row(
                children: [
                  Text(
                    '$studentCount',
                    style: AppTextStyles.labelMdBold
                        .copyWith(color: AppColors.onSurface),
                  ),
                  SizedBox(width: 4.w),
                  const Icon(Icons.group,
                      size: 14, color: AppColors.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
