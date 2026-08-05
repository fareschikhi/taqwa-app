import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/memorization_entry_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/attendance_chip.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/teacher_student_model.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  final Map<int, AttendanceStatus> _attendance = {}; // studentId -> status
  final Set<int> _memorizedStudentIds = {};
  bool _isLoading = true;
  final Set<int> _savingStudentIds = {};

  List<TeacherStudentModel> _students = [];
  final _repo = TeacherRepository();

  int? get _teacherId => ref.read(authProvider).user?.teacherId;

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int get _checkedCount =>
      _attendance.values.where((s) => s != AttendanceStatus.unset).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final tid = _teacherId;
    if (tid == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getStudents(teacherId: tid, limit: 100),
        _repo.getAttendanceByDate(_todayStr),
        _repo.getMemorizationByDate(_todayStr), // NEW
      ]);

      final studentList = (results[0] as StudentListResponse).data;
      final existingRecords = results[1] as List<Map<String, dynamic>>;
      final memorizationRecords =
          results[2] as List<Map<String, dynamic>>; // NEW

      final existingMap = <int, String>{};
      for (final record in existingRecords) {
        final sId = (record['studentId'] as num?)?.toInt();
        final st = record['status'] as String?;
        if (sId != null && st != null) existingMap[sId] = st;
      }

      final memorizedIds =
          memorizationRecords // NEW
              .map((r) => (r['studentId'] as num?)?.toInt())
              .whereType<int>()
              .toSet();

      setState(() {
        _students = studentList;
        _memorizedStudentIds
          ..clear()
          ..addAll(memorizedIds); // NEW
        for (final s in studentList) {
          final existing = existingMap[s.id];
          _attendance[s.id] = existing != null
              ? _mapStatus(existing)
              : AttendanceStatus.unset;
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _openMemorizationSheet(TeacherStudentModel student) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemorizationEntrySheet(student: student),
    );
    if (saved == true) {
      setState(() => _memorizedStudentIds.add(student.id));
    }
  }

  AttendanceStatus _mapStatus(String s) {
    switch (s.toUpperCase()) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LATE':
        return AttendanceStatus.late;
      default:
        return AttendanceStatus.unset;
    }
  }

  String _statusToString(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return 'PRESENT';
      case AttendanceStatus.absent:
        return 'ABSENT';
      case AttendanceStatus.late:
        return 'LATE';
      case AttendanceStatus.unset:
        return 'PRESENT'; // default fallback
    }
  }

  Future<void> _markAttendance(int studentId, AttendanceStatus status) async {
    final previous = _attendance[studentId];
    setState(() {
      _attendance[studentId] = status; // optimistic
      _savingStudentIds.add(studentId);
    });

    try {
      await _repo.upsertAttendance(
        studentId: studentId,
        date: _todayStr,
        status: _statusToString(status),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _attendance[studentId] = previous ?? AttendanceStatus.unset,
        ); // rollback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل حفظ الحضور',
              style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStudentIds.remove(studentId));
    }
  }

  void _onChipTap(int studentId, AttendanceStatus tapped) {
    if (_attendance[studentId] == tapped) {
      return;
    } // already saved as this, skip network call
    _markAttendance(studentId, tapped);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user?.teacherId != null && _students.isEmpty && !_isLoading) {
        _loadData();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildProgress(),
                    Expanded(
                      child: _students.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: 300.h,
                                alignment: Alignment.center,
                                child: Text(
                                  'لا يوجد طلاب مسجلون',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                              itemCount: _students.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(height: 10.h),
                              itemBuilder: (_, i) {
                                final student = _students[i];
                                return _StudentAttendanceTile(
                                  name: student.fullName,
                                  avatarUrl: student.avatar,
                                  index: i + 1,
                                  status:
                                      _attendance[student.id] ??
                                      AttendanceStatus.unset,
                                  isSaving: _savingStudentIds.contains(
                                    student.id,
                                  ),
                                  hasMemorization: _memorizedStudentIds
                                      .contains(student.id),
                                  onSelectStatus: (s) =>
                                      _onChipTap(student.id, s),
                                  onOpenMemorization: () =>
                                      _openMemorizationSheet(student),
                                );
                              },
                            ),
                    ),
                    // _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
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
              Text(
                'تقوى',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'تسجيل الحضور',
                    style: AppTextStyles.headlineLgMobile.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    ' ${DateTime.now().day}/${DateTime.now().month}',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final total = _students.length;
    final uncheckedCount = total - _checkedCount;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_checkedCount / $total',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                _checkedCount < total
                    ? 'غير محدد $uncheckedCount'
                    : 'تم تحديد الكل',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: LinearProgressIndicator(
              value: total > 0 ? _checkedCount / total : 0,
              minHeight: 10.h,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildSaveButton() {
  //   return Container(
  //     padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
  //     decoration: const BoxDecoration(
  //       color: AppColors.surfaceContainerLowest,
  //       boxShadow: [
  //         BoxShadow(
  //           color: Color.fromRGBO(18, 52, 59, 0.04),
  //           blurRadius: 20,
  //           offset: Offset(0, -4),
  //         ),
  //       ],
  //     ),
  //     child: SafeArea(
  //       top: false,
  //       child: AppButton(
  //         label: 'حفظ التحضير',
  //         variant: AppButtonVariant.gradient,
  //         icon: Icons.save_outlined,
  //         isLoading: _isSaving,
  //         onPressed: _saveAttendance,
  //       ),
  //     ),
  //   );
  // }
}

class _StudentAttendanceTile extends StatelessWidget {
  const _StudentAttendanceTile({
    required this.name,
    this.avatarUrl,
    required this.index,
    required this.status,
    required this.isSaving,
    required this.hasMemorization,
    required this.onSelectStatus,
    required this.onOpenMemorization,
  });
  final String name;
  final String? avatarUrl;
  final int index;
  final AttendanceStatus status;
  final bool isSaving;
  final bool hasMemorization;
  final ValueChanged<AttendanceStatus> onSelectStatus;
  final VoidCallback onOpenMemorization;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: hasMemorization
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: hasMemorization
                    ? AppColors.primary
                    : AppColors.inputBorder,
                width: hasMemorization ? 1.2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onOpenMemorization,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        if (hasMemorization)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(
                                color: AppColors
                                    .present, // reuse your existing green token
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceContainerLowest,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'عرض',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: hasMemorization
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                name,
                style: AppTextStyles.bodyMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AttendanceChip(
                    label: 'غائب',
                    status: status,
                    myStatus: AttendanceStatus.absent,
                    onTap: () {
                      if (!isSaving) onSelectStatus(AttendanceStatus.absent);
                    },
                  ),
                  SizedBox(width: 6.w),
                  AttendanceChip(
                    label: 'حاضر',
                    status: status,
                    myStatus: AttendanceStatus.present,
                    onTap: () {
                      if (!isSaving) onSelectStatus(AttendanceStatus.present);
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(width: 18.w),

          AvatarWidget(
            avatarUrl: avatarUrl,
            size: 64.w,
            backgroundColor: AppColors.surfaceContainerHigh,
            fallback: Text(
              '$index',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _borderColor {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.present.withValues(alpha: 0.3);
      case AttendanceStatus.absent:
        return AppColors.absent.withValues(alpha: 0.3);
      case AttendanceStatus.late:
        return AppColors.late.withValues(alpha: 0.3);
      case AttendanceStatus.unset:
        return AppColors.outlineVariant;
    }
  }
}
