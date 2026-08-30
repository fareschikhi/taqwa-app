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
import '../../../../core/widgets/confirm_duplicate_memorization_dialog.dart';
import '../../../../core/utils/memorization_duplicates.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/fine_balance.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/repositories/halaqa_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/models/halaqa/halaqa_model.dart';
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

  /// The "لم يحفظ" toggle, present only for adult students — a child never
  /// accrues a fine, so his id never enters this map. It changes on its own,
  /// independently of the status chip, which is exactly why the pending
  /// comparison in attendance_draft.dart has to consider it too.
  final Map<int, bool> _missed = {};

  /// What the server last confirmed for the toggle, mirroring
  /// [_savedAttendance]'s role for the status chip.
  final Map<int, bool> _savedMissed = {};

  final Set<int> _memorizedStudentIds = {};

  // What is already on file for today, per student. The ids alone would say
  // that a repeat is happening; the rows let the warning name the work.
  final Map<int, List<Map<String, dynamic>>> _todayMemorization = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final Set<int> _savingStudentIds = {};

  List<TeacherStudentModel> _students = [];
  final _repo = TeacherRepository();
  final _halaqaRepo = HalaqaRepository();

  /// Each student's own halaqa, resolved once when the roster loads. A
  /// student's row from `GET /students` nests only `id`, `name` and `level`
  /// for his halaqa — not the fine fields — so this holds the full
  /// [HalaqaModel] (fetched separately) for whichever id he belongs to. A
  /// student with no entry here is treated as a child: never fined, and the
  /// toggle never renders for him.
  final Map<int, HalaqaModel> _studentHalaqa = {};

  bool _isAdultStudent(int studentId) =>
      _studentHalaqa[studentId]?.isAdult ?? false;

  int _missedMemorizationFeeFor(int studentId) =>
      _studentHalaqa[studentId]?.missedMemorizationFee ?? 0;

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

  Set<int> get _pendingIds => pendingAttendanceIds(
    draft: _attendance,
    saved: _savedAttendance,
    missedDraft: _missed,
    missedSaved: _savedMissed,
  );

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
        _halaqaRepo.getAllHalaqas(),
      ]);

      final studentList = (results[0] as StudentListResponse).data;
      final existingRecords = results[1] as List<Map<String, dynamic>>;
      final memorizationRecords =
          results[2] as List<Map<String, dynamic>>; // NEW
      final halaqas = results[3] as List<HalaqaModel>;
      final halaqasById = {for (final h in halaqas) h.id: h};

      final existingMap = <int, String>{};
      // The toggle a student's Attendance row carried the last time it was
      // written. A student with no row at all has neither, which is exactly
      // why both maps are read together below rather than one implying "no
      // row means false" — that would be a coincidence of the default, not a
      // rule this code should lean on.
      final existingMissedMap = <int, bool>{};
      for (final record in existingRecords) {
        final sId = (record['studentId'] as num?)?.toInt();
        final st = record['status'] as String?;
        if (sId != null && st != null) existingMap[sId] = st;
        final missed = record['missedMemorization'] as bool?;
        if (sId != null && missed != null) existingMissedMap[sId] = missed;
      }

      final memorizedByStudent = memorizationByStudent(memorizationRecords);

      // Pull-to-refresh runs on a screen the teacher may have half-marked, and
      // an unsaved chip exists nowhere else. Refreshing therefore updates what
      // the server is known to hold without overwriting those chips.
      final stillPending = _pendingIds;

      setState(() {
        _students = studentList;
        _studentHalaqa.clear();
        for (final s in studentList) {
          final halaqa = s.halaqaId == null ? null : halaqasById[s.halaqaId];
          if (halaqa != null) _studentHalaqa[s.id] = halaqa;
        }
        _memorizedStudentIds
          ..clear()
          ..addAll(memorizedByStudent.keys);
        _todayMemorization
          ..clear()
          ..addAll(memorizedByStudent);
        _savedAttendance.clear();
        _savedMissed.clear();
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
          // A child never accrues a fine, so his id never enters either
          // toggle map — that absence is what keeps the switch off his card
          // and the key off his batch record.
          if (_isAdultStudent(s.id)) {
            final existingMissed = existingMissedMap[s.id] ?? false;
            _savedMissed[s.id] = existingMissed;
            if (!stillPending.contains(s.id)) {
              _missed[s.id] = existingMissed;
            }
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
    // Entries accumulate rather than replace, so a second one for the same day
    // is added silently. That is ordinary for حفظ followed by مراجعة and a
    // mistake for a teacher who forgot, so it is confirmed rather than blocked.
    final alreadyToday = _todayMemorization[student.id] ?? const [];
    if (alreadyToday.isNotEmpty) {
      final proceed = await ConfirmDuplicateMemorizationDialog.show(
        context,
        studentName: student.fullName,
        existing: alreadyToday.map(memorizationSummary).toList(),
      );
      if (!proceed || !mounted) return;
    }

    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemorizationEntrySheet(student: student),
    );
    if (created != null) {
      setState(() {
        _memorizedStudentIds.add(student.id);
        _todayMemorization.putIfAbsent(student.id, () => []).add(created);
      });
    }
  }

  /// Writes one student's chip ahead of the batch. Returns false only when the
  /// write was attempted and failed, which is the case where opening the sheet
  /// would invite a save the server is bound to reject.
  Future<bool> _saveOne(int studentId) async {
    final status = _attendance[studentId];
    final apiStatus = status == null ? null : attendanceStatusToApi(status);
    if (status == null || apiStatus == null) return true;

    // Built through the shared payload helper — for a batch of one, with
    // `saved: {}` so this student is always included — rather than a
    // hand-rolled map, so the toggle rides along exactly as it would in a
    // full save. Hand-rolling it here a second time is how it would have
    // been silently dropped from this path alone.
    final record = attendanceBatchPayload(
      draft: {studentId: status},
      saved: const {},
      date: _todayStr,
      missedDraft: _missed,
    ).first;
    final missed = record['missedMemorization'] as bool?;

    setState(() => _savingStudentIds.add(studentId));
    try {
      await _repo.upsertAttendance(
        studentId: studentId,
        date: _todayStr,
        status: apiStatus,
        missedMemorization: missed,
      );
      if (mounted) {
        setState(() {
          _savedAttendance[studentId] = status;
          if (missed != null) _savedMissed[studentId] = missed;
        });
      }
      await _flushQueue();
      return true;
    } catch (_) {
      await _enqueue([record]);
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
      missedDraft: _missed,
      missedSaved: _savedMissed,
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
          if (record.containsKey('missedMemorization')) {
            _savedMissed[id] = record['missedMemorization'] as bool;
          }
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
          final status = attendanceStatusFromApi(record['status'] as String);
          _savedAttendance[id] = status;
          // The chips too: a flush on mount runs after the roster loaded
          // without these rows, so without this the teacher sees an empty
          // board and marks the halaqa a second time.
          _attendance[id] = status;
          // Same reasoning for the toggle: a queued record that carried it
          // must land in both maps, or the flush would leave that student
          // looking pending forever despite the server now holding his mark.
          if (record.containsKey('missedMemorization')) {
            final missed = record['missedMemorization'] as bool;
            _savedMissed[id] = missed;
            _missed[id] = missed;
          }
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
        _todayMemorization.remove(student.id);
        // An absent student is already charged for the absence; leaving a
        // stale "لم يحفظ" on him would bill the same fact twice, which is
        // exactly what the server also refuses. The switch itself is about
        // to become disabled, but the value behind it must not linger true.
        _missed.remove(student.id);
      }
    });
  }

  /// Only ever called for an adult student, since the switch does not render
  /// for anyone else.
  void _onToggleMissed(int studentId, bool value) {
    setState(() => _missed[studentId] = value);
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
                                    isAdult: _isAdultStudent(student.id),
                                    missedMemorizationFee:
                                        _missedMemorizationFeeFor(student.id),
                                    missed: _missed[student.id] ?? false,
                                    onSelectStatus: (s) =>
                                        _onChipTap(student, s),
                                    onOpenMemorization: () =>
                                        _openMemorizationSheet(student),
                                    onToggleMissed: (v) =>
                                        _onToggleMissed(student.id, v),
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
    required this.isAdult,
    required this.missedMemorizationFee,
    required this.missed,
    required this.onSelectStatus,
    required this.onOpenMemorization,
    required this.onToggleMissed,
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

  /// Whether this student belongs to an adults' halaqa. A child never
  /// accrues a fine, so the toggle does not render for him at all.
  final bool isAdult;

  /// What toggling the switch on will charge — shown beside it so the
  /// teacher sees the cost before she taps, not after.
  final int missedMemorizationFee;

  /// The current value of the "لم يحفظ" toggle.
  final bool missed;
  final ValueChanged<AttendanceStatus> onSelectStatus;
  final VoidCallback onOpenMemorization;
  final ValueChanged<bool> onToggleMissed;

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
              // A child never accrues a fine, so this row does not exist for
              // him at all — not even disabled — rather than showing a
              // switch that could never do anything.
              if (isAdult) ...[
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppText(
                      formatFine(missedMemorizationFee),
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    AppText(
                      'لم يحفظ',
                      style: AppTextStyles.labelSm.copyWith(
                        color: canMemorize
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: missed,
                        activeThumbColor: AppColors.error,
                        // Absent is already charged for the absence; charging
                        // the same day twice for a missed recitation would
                        // double-bill a student who never even sat down, and
                        // the server refuses this pairing too.
                        onChanged: canMemorize && !isSaving
                            ? onToggleMissed
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
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
