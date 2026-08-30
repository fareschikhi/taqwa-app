import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import 'student_details_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class StudentListPage extends ConsumerStatefulWidget {
  const StudentListPage({super.key});

  @override
  ConsumerState<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends ConsumerState<StudentListPage> {
  int _filterIndex = 0;
  final _searchController = TextEditingController();
  final _repo = TeacherRepository();
  final _scrollController = ScrollController();

  List<TeacherStudentModel> _students = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const _limit = 20;

  int? get _teacherId => ref.read(authProvider).user?.teacherId;

  bool? get _isActiveFilter {
    if (_filterIndex == 1) return true;
    if (_filterIndex == 2) return false;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadStudents(reset: true),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadStudents();
    }
  }

  DateTime? _lastSearch;
  void _onSearchChanged(String q) {
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_lastSearch == now) _loadStudents(reset: true);
    });
  }

  Future<void> _loadStudents({bool reset = false}) async {
    if (_isLoading) return;
    if (!reset && !_hasMore) return;
    final tid = _teacherId;
    if (tid == null) return;

    setState(() {
      _isLoading = true;
    });
    final page = reset ? 1 : _currentPage;
    try {
      final result = await _repo.getStudents(
        teacherId: tid,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        page: page,
        limit: _limit,
        isActive: _isActiveFilter,
      );
      setState(() {
        if (reset) {
          _students = result.data;
        } else {
          _students = [..._students, ...result.data];
        }
        _currentPage = page + 1;
        _hasMore = result.data.length == _limit;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user?.teacherId != null && _students.isEmpty && !_isLoading) {
        _loadStudents(reset: true);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const Spacer(),
                      AppText(
                        'تقوى',
                        style: AppTextStyles.headlineMd.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  AppText(
                    'طلابي',
                    style: AppTextStyles.headlineLgMobile.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  AppText(
                    'متابعة تقدم وأداء طلابك.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SearchBarWidget(
                    hint: 'ابحث باسم الطالب...',
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                  SizedBox(height: 12.h),
                  FilterChipGroup(
                    filters: [
                      'الكل (${_students.length})',
                      'نشطون',
                      'غير نشطون',
                    ],
                    onChanged: (i) {
                      setState(() => _filterIndex = i);
                      _loadStudents(reset: true);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: _isLoading && _students.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _loadStudents(reset: true),
                      child: _students.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: 300.h,
                                alignment: Alignment.center,
                                child: AppText(
                                  'لا يوجد طلاب',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              controller: _scrollController,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              itemCount: _students.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (context, index) =>
                                  SizedBox(height: 12.h),
                              itemBuilder: (_, i) {
                                if (i == _students.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final student = _students[i];
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentDetailsPage(
                                        student: student,
                                      ),
                                    ),
                                  ),
                                  child: _StudentListTile(student: student),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentListTile extends StatelessWidget {
  const _StudentListTile({required this.student});
  final TeacherStudentModel student;

  @override
  Widget build(BuildContext context) {
    final initial = student.fullName.isNotEmpty ? student.fullName[0] : '?';
    return Container(
      padding: EdgeInsets.all(16.w),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PercRow(percent: 0, color: AppColors.primary, label: 'حفظ'),
              SizedBox(height: 4.h),
              _PercRow(percent: 0, color: AppColors.secondary, label: 'حضور'),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                student.fullName,
                style: AppTextStyles.bodyMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 4.h),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color:
                      (student.isActive ? AppColors.primary : AppColors.error)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: AppText(
                  student.isActive ? 'نشط' : 'غير نشط',
                  style: AppTextStyles.labelSm.copyWith(
                    color: student.isActive
                        ? AppColors.primary
                        : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          AvatarWidget(
            avatarUrl: student.avatar,
            size: 44.w,
            fallback: AppText(
              initial,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PercRow extends StatelessWidget {
  const _PercRow({
    required this.percent,
    required this.color,
    required this.label,
  });
  final double percent;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          '${(percent * 100).round()}%',
          style: AppTextStyles.labelSm.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 4.w),
        AppText(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
