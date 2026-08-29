import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/memorization_entry_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/attendance_draft.dart';
import '../../../../core/utils/attendance_queue.dart';
import '../../../data/local/attendance_queue_store.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/attendance_chip.dart';
import '../../../../core/widgets/confirm_discard_attendance_dialog.dart';
import '../../../../core/widgets/confirm_discard_memorization_dialog.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage>
    with WidgetsBindingObserver {
  /// What the chips show. The teacher marks the whole halaqa here and it is
  /// written in one batch, so a tap costs nothing and stays undoable.
  final Map<int, AttendanceStatus> _attendance = {}; // studentId -> status

  /// What the server last confirmed, so a save only sends what actually
  /// changed and a failed write does not leave the two silently disagreeing.
  final Map<int, AttendanceStatus> _savedAttendance = {};

  final Set<int> _memorizedStudentIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final Set<int> _savingStudentIds = {};

  List<TeacherStudentModel> _students = [];
  final _repo = TeacherRepository();

  final _queueStore = AttendanceQueueStore();

  /// Marks the server has not taken yet. Mirrors what is on disk, so the
  /// banner can render without an await.
  List<Map<String, dynamic>> _queued = [];

  int? get _teacherId => ref.read(authProvider).user?.teacherId;

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int get _checkedCount =>
      _attendance.values.where((s) => s != AttendanceStatus.unset).length;

  Set<int> get _pendingIds =>
      pendingAttendanceIds(draft: _attendance, saved: _savedAttendance);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// TeacherShell keeps its pages in an IndexedStack, so initState fires once
  /// per launch rather than per tab switch. This covers the teacher who
  /// backgrounds the app until signal returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flushQueue();
  }

  Future<void> _loadData() async {
    final tid = _teacherId;
    if (tid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final stored = await _queueStore.read(tid);
    if (mounted) setState(() => _queued = stored);

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

      // Pull-to-refresh runs on a screen the teacher may have half-marked, and
      // an unsaved chip exists nowhere else. Refreshing therefore updates what
      // the server is known to hold without overwriting those chips.
      final stillPending = _pendingIds;

      setState(() {
        _students = studentList;
        _memorizedStudentIds
          ..clear()
          ..addAll(memorizedIds); // NEW
        _savedAttendance.clear();
        for (final s in studentList) {
          final existing = attendanceStatusFromApi(existingMap[s.id]);
          // A student with no row yet has nothing saved, and `unset` is not a
          // state the server can hold — leaving it out of the saved map is
          // what makes the first tap register as a pending change.
          if (existing != AttendanceStatus.unset) {
            _savedAttendance[s.id] = existing;
          }
          if (!stillPending.contains(s.id)) {
            _attendance[s.id] = existing;
          }
        }
        _isLoading = false;
      });
      // Runs after the roster is on screen, so a teacher who reopens the app
      // with signal sees held marks go out without touching anything.
      await _flushQueue();
    } catch (_) {
      // Without this an empty screen reads as "this halaqa has no students".
      setState(() => _isLoading = false);
      _showSnack('تعذّر تحميل قائمة الطلاب', isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          message,
          style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: isError ? AppColors.error : AppColors.present,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ),
    );
  }

  void _openMemorizationSheet(TeacherStudentModel student) async {
    // The server refuses recitation for an absent student, and it can only
    // judge that against rows it has actually received. A chip still sitting
    // in the draft would have it rule on a stale row — or none at all — so
    // this one student's attendance is written before the sheet opens.
    if (_pendingIds.contains(student.id)) {
      final reconciled = await _saveOne(student.id);
      if (!reconciled) return;
    }

    if (!mounted) return;
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

  /// Writes one student's chip ahead of the batch. Returns false only when the
  /// write was attempted and failed, which is the case where opening the sheet
  /// would invite a save the server is bound to reject.
  Future<bool> _saveOne(int studentId) async {
    final status = _attendance[studentId];
    final apiStatus = status == null ? null : attendanceStatusToApi(status);
    if (status == null || apiStatus == null) return true;

    setState(() => _savingStudentIds.add(studentId));
    try {
      await _repo.upsertAttendance(
        studentId: studentId,
        date: _todayStr,
        status: apiStatus,
      );
      if (mounted) setState(() => _savedAttendance[studentId] = status);
      await _flushQueue();
      return true;
    } catch (_) {
      await _enqueue([
        {'studentId': studentId, 'date': _todayStr, 'status': apiStatus},
      ]);
      _showSnack('لا يوجد اتصال، سيتم حفظ الحضور تلقائياً', isError: true);
      // Still false: the server has not taken this mark, so the caller must
      // not open the memorization sheet on top of it.
      return false;
    } finally {
      if (mounted) setState(() => _savingStudentIds.remove(studentId));
    }
  }

  Future<void> _saveAttendance() async {
    final payload = attendanceBatchPayload(
      draft: _attendance,
      saved: _savedAttendance,
      date: _todayStr,
    );
    if (payload.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _repo.submitAttendanceBatch(payload);
      if (!mounted) return;
      setState(() {
        // Only what the server took is promoted, so a chip changed while the
        // request was in flight stays pending instead of looking saved.
        for (final record in payload) {
          final id = record['studentId'] as int;
          _savedAttendance[id] = attendanceStatusFromApi(
            record['status'] as String,
          );
        }
      });
      _showSnack('تم حفظ حضور ${payload.length} طالب', isError: false);
      // The connection is evidently back, so drain anything held earlier.
      await _flushQueue();
    } catch (_) {
      await _enqueue(payload);
      // The marks are on disk now, so this is a delay rather than a loss.
      _showSnack('لا يوجد اتصال، سيتم حفظ الحضور تلقائياً', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Shown only while marks are waiting, so a working connection costs the
  /// teacher no screen space.
  Widget _buildPendingBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isSaving ? null : _flushQueue,
            child: AppText(
              'إعادة المحاولة',
              style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.cloud_off_outlined,
            size: 18.w,
            color: AppColors.onSurfaceVariant,
          ),
          SizedBox(width: 8.w),
          AppText(
            '${_queued.length} حضور بانتظار الحفظ',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Folds records into the stored queue, last write winning per student and
  /// date, and mirrors the result into state for the banner.
  Future<void> _enqueue(List<Map<String, dynamic>> records) async {
    final teacherId = _teacherId;
    if (teacherId == null) return;

    final merged = mergeQueued(_queued, records);
    await _queueStore.write(teacherId, merged);
    if (mounted) setState(() => _queued = merged);
  }

  /// Sends everything waiting. All-or-nothing: the batch endpoint does not
  /// report partial success, so a failure leaves the queue for the next try.
  Future<void> _flushQueue() async {
    final teacherId = _teacherId;
    if (teacherId == null || _queued.isEmpty || _isSaving) return;

    final sending = List<Map<String, dynamic>>.from(_queued);
    setState(() => _isSaving = true);
    try {
      await _repo.submitAttendanceBatch(sending);
      await _queueStore.clear(teacherId);
      if (!mounted) return;
      setState(() {
        _queued = [];
        for (final record in sending) {
          final id = record['studentId'] as int;
          _savedAttendance[id] = attendanceStatusFromApi(
            record['status'] as String,
          );
        }
      });
      _showSnack('تم حفظ ${sending.length} حضور مؤجل', isError: false);
    } catch (_) {
      // Silent: this runs unprompted on mount and resume, and a teacher who
      // is still offline does not need telling twice.
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onChipTap(
    TeacherStudentModel student,
    AttendanceStatus tapped,
  ) async {
    if (_attendance[student.id] == tapped) return;

    // Going absent discards recitation the teacher already entered. The write
    // only happens on save, but the badge disappears the moment the chip is
    // tapped, so the warning belongs here rather than at save time.
    if (tapped == AttendanceStatus.absent &&
        _memorizedStudentIds.contains(student.id)) {
      final confirmed = await ConfirmDiscardMemorizationDialog.show(
        context,
        studentName: student.fullName,
      );
      if (!confirmed) return;
    }

    setState(() {
      _attendance[student.id] = tapped;
      if (tapped == AttendanceStatus.absent) {
        _memorizedStudentIds.remove(student.id);
      }
    });
  }

  /// Backing out of the shell would drop chips that were never written, and a
  /// marked-but-unsaved row looks exactly like a saved one on screen.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final pending = _pendingIds.length;
    if (pending == 0) return;

    final discard = await ConfirmDiscardAttendanceDialog.show(
      context,
      pendingCount: pending,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user?.teacherId != null && _students.isEmpty && !_isLoading) {
        _loadData();
      }
    });

    return PopScope(
      canPop: _pendingIds.isEmpty,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
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
                      if (_queued.isNotEmpty) _buildPendingBanner(),
                      Expanded(
                        child: _students.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Container(
                                  height: 300.h,
                                  alignment: Alignment.center,
                                  child: AppText(
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
                                    isPending: _pendingIds.contains(student.id),
                                    hasMemorization: _memorizedStudentIds
                                        .contains(student.id),
                                    onSelectStatus: (s) =>
                                        _onChipTap(student, s),
                                    onOpenMemorization: () =>
                                        _openMemorizationSheet(student),
                                  );
                                },
                              ),
                      ),
                      _buildSaveButton(),
                    ],
                  ),
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
              AppText(
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
                  AppText(
                    'تسجيل الحضور',
                    style: AppTextStyles.headlineLgMobile.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  AppText(
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
              AppText(
                '$_checkedCount / $total',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
              AppText(
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

  Widget _buildSaveButton() {
    final pending = _pendingIds.length;
    // Nothing to write means nothing to press. The bar stays out of the way
    // rather than offering a button that would do nothing.
    if (pending == 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          label: 'حفظ التحضير ($pending)',
          variant: AppButtonVariant.gradient,
          icon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _saveAttendance,
        ),
      ),
    );
  }
}

class _StudentAttendanceTile extends StatelessWidget {
  const _StudentAttendanceTile({
    required this.name,
    this.avatarUrl,
    required this.index,
    required this.status,
    required this.isSaving,
    required this.isPending,
    required this.hasMemorization,
    required this.onSelectStatus,
    required this.onOpenMemorization,
  });
  final String name;
  final String? avatarUrl;
  final int index;
  final AttendanceStatus status;
  final bool isSaving;

  /// Marked on screen but not yet written. A chip looks identical either way,
  /// so without this the teacher cannot tell the two apart.
  final bool isPending;
  final bool hasMemorization;
  final ValueChanged<AttendanceStatus> onSelectStatus;
  final VoidCallback onOpenMemorization;

  @override
  Widget build(BuildContext context) {
    final canMemorize = status != AttendanceStatus.absent;
    final memorizationAccent = canMemorize
        ? AppColors.primary
        : AppColors.outlineVariant;
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
              color: hasMemorization && canMemorize
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: hasMemorization && canMemorize
                    ? AppColors.primary
                    : AppColors.inputBorder,
                width: hasMemorization && canMemorize ? 1.2 : 1,
              ),
            ),
            child: InkWell(
              onTap: canMemorize ? onOpenMemorization : null,
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
                          color: memorizationAccent,
                        ),
                        if (hasMemorization && canMemorize)
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
                    AppText(
                      'عرض',
                      style: AppTextStyles.labelSm.copyWith(
                        color: memorizationAccent,
                        fontWeight: hasMemorization && canMemorize
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPending) ...[
                    Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: const BoxDecoration(
                        color: AppColors.late,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                  ],
                  AppText(
                    name,
                    style: AppTextStyles.bodyMdBold.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
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
            fallback: AppText(
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
