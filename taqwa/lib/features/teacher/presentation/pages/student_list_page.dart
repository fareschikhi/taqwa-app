import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/fine_balance.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../data/models/halaqa/halaqa_model.dart';
import '../../../data/repositories/fine_repository.dart';
import '../../../data/repositories/halaqa_repository.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../shared/presentation/pages/student_details_page.dart';
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
  final _halaqaRepo = HalaqaRepository();
  final _fineRepo = FineRepository();
  final _scrollController = ScrollController();

  List<TeacherStudentModel> _students = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const _limit = 20;

  // Each student's own halaqa, resolved once so the roster can tell an
  // adult student from a child one — `GET /students` nests only `id`, `name`
  // and `level` for the halaqa, not `isAdult`.
  final Map<int, HalaqaModel> _studentHalaqa = {};

  // Balances already fetched, keyed by student id — `GET /fines/halaqa/:id`
  // answers for a whole halaqa at once, so this fills in as each adult
  // halaqa on the roster is resolved rather than one call per student.
  final Map<int, int> _balances = {};
  final Set<int> _fetchedFineHalaqas = {};

  bool _isAdultStudent(int studentId) =>
      _studentHalaqa[studentId]?.isAdult ?? false;

  int? get _teacherId => ref.read(authProvider).user?.teacherId;

  bool? get _isActiveFilter {
    if (_filterIndex == 1) return true;
    if (_filterIndex == 2) return false;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents(reset: true);
      _loadHalaqas();
    });
    _scrollController.addListener(_onScroll);
  }

  Map<int, HalaqaModel> _halaqasById = {};

  /// Fetched once — a teacher's halaqas do not change while he browses his
  /// roster — so every page of students can resolve `isAdult` against the
  /// same map instead of a lookup per page.
  Future<void> _loadHalaqas() async {
    try {
      final halaqas = await _halaqaRepo.getAllHalaqas();
      if (!mounted) return;
      _halaqasById = {for (final h in halaqas) h.id: h};
      _resolveStudentHalaqas();
      await _loadFineBalances();
    } catch (_) {
      // A balance chip is a nice-to-have next to the roster itself; failing
      // to resolve which halaqas are adults' just leaves the chips off.
    }
  }

  /// Matches each loaded student to his halaqa so [_isAdultStudent] has an
  /// answer. Safe to re-run after every page of students arrives — it only
  /// ever adds entries, and a student already resolved is skipped.
  void _resolveStudentHalaqas() {
    if (_halaqasById.isEmpty) return;
    setState(() {
      for (final s in _students) {
        if (_studentHalaqa.containsKey(s.id)) continue;
        final halaqa = s.halaqaId == null ? null : _halaqasById[s.halaqaId];
        if (halaqa != null) _studentHalaqa[s.id] = halaqa;
      }
    });
  }

  /// Pulls the balance for every adult halaqa represented on the roster that
  /// has not been fetched yet. `GET /fines/halaqa/:id` answers for a whole
  /// halaqa in one call, so this fetches per halaqa rather than per student.
  Future<void> _loadFineBalances() async {
    final halaqaIds = _students
        .map((s) => s.halaqaId)
        .whereType<int>()
        .where((id) => _halaqasById[id]?.isAdult ?? false)
        .where((id) => !_fetchedFineHalaqas.contains(id))
        .toSet();
    for (final id in halaqaIds) {
      _fetchedFineHalaqas.add(id);
      try {
        final balances = await _fineRepo.forHalaqa(id);
        if (!mounted) return;
        setState(() => _balances.addAll(balances));
      } catch (_) {
        // One halaqa's balances failing to load must not stall the rest of
        // the roster — a retry can pick it up on the next refresh.
        _fetchedFineHalaqas.remove(id);
      }
    }
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
      // The halaqas may already be cached from a previous load; a fresh page
      // of students still needs matching against them and their balances
      // fetched, so both run again rather than only from `_loadHalaqas`.
      _resolveStudentHalaqas();
      await _loadFineBalances();
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
                                        studentId: student.id,
                                        fullName: student.fullName,
                                        avatar: student.avatar,
                                        halaqaId: student.halaqaId,
                                      ),
                                    ),
                                  ),
                                  child: _StudentListTile(
                                    student: student,
                                    // Null both when he is a child (never
                                    // fined) and when his halaqa's balance
                                    // has not resolved yet — either way, no
                                    // chip is the honest answer.
                                    balance: _isAdultStudent(student.id)
                                        ? _balances[student.id]
                                        : null,
                                  ),
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
  const _StudentListTile({required this.student, this.balance});
  final TeacherStudentModel student;
  final int? balance;

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
              if (balance != null) ...[
                SizedBox(height: 6.h),
                _FineBalanceChip(balance: balance!),
              ],
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

/// What an adult student owes, on his card in the roster. Only rendered for
/// an adult student whose halaqa balance has already resolved — a child
/// never accrues a fine, so his card never gets one of these at all.
class _FineBalanceChip extends StatelessWidget {
  const _FineBalanceChip({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    final displayed = displayedBalance(balance);
    final cleared = displayed == 0;
    final color = cleared ? AppColors.primary : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: AppText(
        formatFine(displayed),
        style: AppTextStyles.labelMd.copyWith(color: color),
      ),
    );
  }
}
