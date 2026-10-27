import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/memorization_entry_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/attendance_draft.dart';
import '../../../../core/utils/attendance_queue.dart';
import '../../../../core/utils/cache_then_server.dart';
import '../../../../core/utils/queue_retry_timer.dart';
import '../../../../core/utils/save_gate.dart';
import '../../../data/local/attendance_queue_store.dart';
import '../../../data/local/attendance_roster_cache.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/attendance_controls.dart';
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

  /// What the sheet held the moment it finished loading: the server's own
  /// rows, with present filled in for every student it had none for.
  ///
  /// Saving is measured against [_savedAttendance], because an untouched
  /// default still has to reach the server. Backing out is measured against
  /// this instead — walking away from defaults loses nothing, since the next
  /// open rebuilds them, so only a mark the teacher moved by hand is worth
  /// warning about.
  final Map<int, AttendanceStatus> _initialAttendance = {};
  final Map<int, bool> _initialMissed = {};

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

  int _lateFeeFor(int studentId) => _studentHalaqa[studentId]?.lateFee ?? 0;

  final _queueStore = AttendanceQueueStore();

  /// Marks the server has not taken yet. Mirrors what is on disk, so the
  /// banner can render without an await.
  List<Map<String, dynamic>> _queued = [];

  late final _retryTimer = QueueRetryTimer(onTick: _flushQueue);

  final _rosterCache = AttendanceRosterCache();

  /// When the sheet on screen was fetched, set only while it is the phone's
  /// copy rather than the server's latest answer.
  DateTime? _copySavedAt;

  /// The server is being asked for a fresh sheet.
  bool _isRefreshing = false;

  late final _saveGate = SaveGate(
    onChange: () {
      if (mounted) setState(() {});
    },
  );

  int? get _teacherId => ref.read(authProvider).user?.teacherId;

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// How many students the server has a row for today.
  ///
  /// This used to count marks the teacher had decided on, which stopped
  /// meaning anything once every student opens on present — it would have
  /// read as a full bar before she had done a thing. Saved-versus-total is
  /// the question that still has two answers.
  int get _savedCount =>
      _students.where((s) => _savedAttendance.containsKey(s.id)).length;

  Set<int> get _pendingIds => pendingAttendanceIds(
    draft: _attendance,
    saved: _savedAttendance,
    missedDraft: _missed,
    missedSaved: _savedMissed,
  );

  /// Students the teacher has moved away from what the sheet loaded with.
  /// The same comparison as [_pendingIds], run against the baseline instead
  /// of the server, so defaults nobody touched do not count as work to lose.
  Set<int> get _handEditedIds => pendingAttendanceIds(
    draft: _attendance,
    saved: _initialAttendance,
    missedDraft: _missed,
    missedSaved: _initialMissed,
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
    _retryTimer.dispose();
    _saveGate.dispose();
    super.dispose();
  }

  /// TeacherShell keeps its pages in an IndexedStack, so initState fires once
  /// per launch rather than per tab switch. This covers the teacher who
  /// backgrounds the app until signal returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flushQueue();
  }

  /// Draws the phone's copy at once, then the server's answer over it.
  ///
  /// [fromCache] is false for pull-to-refresh: the screen already holds the
  /// server's last answer, and drawing the older copy first would step back.
  Future<void> _loadData({bool fromCache = true}) async {
    final tid = _teacherId;
    if (tid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final stored = await _queueStore.read(tid);
    if (mounted) _setQueued(stored);

    final today = _todayStr;
    // The spinner is only for a screen with nothing on it yet. Otherwise the
    // list stays up and the refresh line says the server is being asked.
    setState(() {
      if (_students.isEmpty) _isLoading = true;
      _isRefreshing = true;
    });
    // A copy can be older than rows another device wrote since, so saves wait
    // for the server's answer — briefly, see SaveGate.
    if (fromCache) _saveGate.begin();
    try {
      await for (final update in cacheThenServer<AttendanceRoster>(
        readCache: () async =>
            fromCache ? await _rosterCache.read(tid, date: today) : null,
        fetch: () => _fetchRoster(tid, today),
        writeCache: (roster) => _rosterCache.write(
          tid,
          date: today,
          students: roster.students,
          halaqas: roster.halaqas,
          attendance: roster.attendance,
          memorization: roster.memorization,
        ),
      )) {
        if (!mounted) return;
        _applyRoster(update.value, today: today, fromCache: update.fromCache);
        if (!update.fromCache) _saveGate.end();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // An empty screen alone would read as "this halaqa has no students";
      // a list already up stays, and only the refresh attempt failed.
      _showSnack(
        _students.isEmpty
            ? 'تعذّر تحميل قائمة الطلاب'
            : 'تعذّر التحديث، لا يوجد اتصال',
        isError: true,
      );
    } finally {
      _saveGate.end();
      if (mounted) setState(() => _isRefreshing = false);
    }

    // Runs after the roster is on screen, so a teacher who reopens the app
    // with signal sees held marks go out without touching anything.
    if (mounted) await _flushQueue();
  }

  Future<AttendanceRoster> _fetchRoster(int teacherId, String date) async {
    final results = await Future.wait([
      _repo.getStudents(teacherId: teacherId, limit: 100),
      _repo.getAttendanceByDate(date),
      _repo.getMemorizationByDate(date),
      _halaqaRepo.getAllHalaqas(),
    ]);
    return AttendanceRoster(
      savedAt: DateTime.now(),
      students: (results[0] as StudentListResponse).data,
      attendance: results[1] as List<Map<String, dynamic>>,
      memorization: results[2] as List<Map<String, dynamic>>,
      halaqas: results[3] as List<HalaqaModel>,
    );
  }

  /// Puts one sheet on screen. Runs twice on a normal open — the copy, then
  /// the server — so it must never clobber what the teacher did in between.
  void _applyRoster(
    AttendanceRoster roster, {
    required String today,
    required bool fromCache,
  }) {
    final studentList = roster.students;
    final existingRecords = roster.attendance;
    final memorizationRecords = roster.memorization;
    final halaqasById = {for (final h in roster.halaqas) h.id: h};

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
      _initialAttendance.clear();
      _initialMissed.clear();
      _savedMissed.clear();
      for (final s in studentList) {
        final existing = attendanceStatusFromApi(existingMap[s.id]);
        // A student with no row yet has nothing saved, and `unset` is not a
        // state the server can hold — leaving it out of the saved map is
        // what makes the first tap register as a pending change.
        if (existing != AttendanceStatus.unset) {
          _savedAttendance[s.id] = existing;
        }
        // A student the server has no row for starts on present: the sheet
        // marks exceptions, so saving without touching him records him
        // present rather than recording nothing at all.
        final baseline = existing == AttendanceStatus.unset
            ? AttendanceStatus.present
            : existing;
        _initialAttendance[s.id] = baseline;
        if (!stillPending.contains(s.id)) {
          _attendance[s.id] = baseline;
        }
        // A child never accrues a fine, so his id never enters either
        // toggle map — that absence is what keeps the switch off his card
        // and the key off his batch record.
        if (_isAdultStudent(s.id)) {
          final existingMissed = existingMissedMap[s.id] ?? false;
          _savedMissed[s.id] = existingMissed;
          _initialMissed[s.id] = existingMissed;
          if (!stillPending.contains(s.id)) {
            _missed[s.id] = existingMissed;
          }
        }
      }
      // Held marks belong on the chips, not only in the banner. Reopened
      // offline, the sheet would otherwise show the old rows, and a save
      // from there would queue present for everyone over what was held.
      // They stay pending, because the server has not taken them.
      for (final record in _queued) {
        final id = record['studentId'] as int;
        if (record['date'] != today || stillPending.contains(id)) continue;
        _attendance[id] = attendanceStatusFromApi(record['status'] as String);
        if (record.containsKey('missedMemorization')) {
          _missed[id] = record['missedMemorization'] as bool;
        }
      }
      _copySavedAt = fromCache ? roster.savedAt : null;
      _isLoading = false;
    });
  }

  /// Every change to [_queued] goes through here, so the retry clock runs
  /// exactly while something is waiting.
  void _setQueued(List<Map<String, dynamic>> records) {
    setState(() => _queued = records);
    _retryTimer.sync(hasPending: records.isNotEmpty);
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
    // The chip may still be the phone's copy; the tile's spinner covers the
    // wait so the tap does not look ignored.
    if (_saveGate.waiting) {
      setState(() => _savingStudentIds.add(studentId));
      await _saveGate.ready;
      if (!mounted) return false;
      setState(() => _savingStudentIds.remove(studentId));
    }

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
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Measured after the wait, not before: the server's answer can change
    // what counts as already saved, and so what this save must send.
    await _saveGate.ready;
    if (!mounted) return;
    final payload = attendanceBatchPayload(
      draft: _attendance,
      saved: _savedAttendance,
      date: _todayStr,
      missedDraft: _missed,
      missedSaved: _savedMissed,
    );
    if (payload.isEmpty) {
      setState(() => _isSaving = false);
      return;
    }

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

  /// Says the list is the phone's copy: while the server is being asked, that
  /// it is refreshing; once asking failed, how old the copy is, so a student
  /// added since then is missing for a visible reason.
  Widget _buildCopyNotice() {
    final at = _copySavedAt!;
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppText(
            _isRefreshing
                ? 'جارٍ التحديث…'
                : 'لا يوجد اتصال · آخر تحديث ${at.day}/${at.month} ${two(at.hour)}:${two(at.minute)}',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(width: 8.w),
          _isRefreshing
              ? SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              : Icon(
                  Icons.wifi_off_rounded,
                  size: 18.w,
                  color: AppColors.onSurfaceVariant,
                ),
        ],
      ),
    );
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
    if (mounted) _setQueued(merged);
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
      _setQueued([]);
      setState(() {
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

  /// Backing out of the shell would drop marks that were never written, and
  /// a marked-but-unsaved row looks exactly like a saved one on screen.
  ///
  /// Counts hand edits, not everything unsaved: since the sheet opens with
  /// everyone defaulted to present, otherwise merely opening it and leaving
  /// would warn about the whole halaqa.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final pending = _handEditedIds.length;
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
      canPop: _handEditedIds.isEmpty,
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
                  onRefresh: () => _loadData(fromCache: false),
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildProgress(),
                      if (_copySavedAt != null) _buildCopyNotice(),
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
                                    lateFee: _lateFeeFor(student.id),
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
                'التقوى',
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
    final unsavedCount = total - _savedCount;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                '$_savedCount / $total',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
              AppText(
                _savedCount < total ? 'غير محفوظ $unsavedCount' : 'تم حفظ الكل',
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
              value: total > 0 ? _savedCount / total : 0,
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
    required this.lateFee,
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

  /// What marking this student late will charge. Shown on the chip itself so
  /// the cost is readable before the tap, the same reason the missed-recitation
  /// fee sits beside its switch.
  final int lateFee;

  /// The current value of the "لم يحفظ" toggle.
  final bool missed;

  /// The price to print on the late chip, or null when lateness is free —
  /// a child's halaqa, or an adults' one whose rate is still zero. A chip
  /// reading "0 دج" would imply a charge that never arrives.
  String? get _lateFeeLabel =>
      isAdult && lateFee > 0 ? formatFine(lateFee) : null;
  final ValueChanged<AttendanceStatus> onSelectStatus;
  final VoidCallback onOpenMemorization;
  final ValueChanged<bool> onToggleMissed;

  @override
  Widget build(BuildContext context) {
    final canMemorize = status != AttendanceStatus.absent;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: _statusColumnWidth, child: _buildStatusPicker()),
              SizedBox(width: 12.w),
              Expanded(child: _buildName()),
              SizedBox(width: 12.w),
              _buildAvatar(),
            ],
          ),
          SizedBox(height: 10.h),
          _buildRecitationRow(canMemorize),
        ],
      ),
    );
  }

  /// Wide enough for the dropdown's longest state — the late entry, whose fee
  /// sits under the label — plus the arrow. The menu it opens is laid out to
  /// the same width, so this has to satisfy both.
  double get _statusColumnWidth => 140.w;

  /// The three statuses, stacked down the left edge.
  Widget _buildStatusPicker() {
    return AttendanceDropdown(
      status: status,
      lateFeeLabel: _lateFeeLabel,
      enabled: !isSaving,
      onChanged: onSelectStatus,
    );
  }

  /// The student's name, ellipsised rather than allowed to overflow the gap
  /// between the chips and the avatar. The pending dot keeps its size.
  Widget _buildName() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
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
        Flexible(
          child: AppText(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: AppTextStyles.bodyMdBold.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return AvatarWidget(
      avatarUrl: avatarUrl,
      size: 64.w,
      backgroundColor: AppColors.surfaceContainerHigh,
      fallback: AppText(
        '$index',
        style: AppTextStyles.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  /// The two answers to "did he recite today?" side by side: open the sheet
  /// and record what he read, or mark that he did not and take the fine.
  ///
  /// A child never accrues a fine, so the toggle does not render for him at
  /// all — not even disabled — and the button takes the whole row instead.
  Widget _buildRecitationRow(bool canMemorize) {
    // IntrinsicHeight, not a bare stretch: the tile is a ListView child, so
    // its height is unbounded, and stretching against that asks the children
    // for an infinite height. This measures the taller control first, then
    // stretches both to it.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Equal halves. The fee sits on its own line rather than joined onto
          // the label, which is what lets the toggle live in half a row
          // without shrinking a money value to fit.
          Expanded(
            child: RecitationButton(
              icon: Icons.menu_book_outlined,
              label: 'تحديد العرض',
              color: canMemorize ? AppColors.primary : AppColors.outlineVariant,
              highlighted: hasMemorization && canMemorize,
              showBadge: hasMemorization && canMemorize,
              enabled: canMemorize,
              onTap: onOpenMemorization,
            ),
          ),
          if (isAdult) ...[
            SizedBox(width: 8.w),
            Expanded(
              child: RecitationButton(
                icon: Icons.menu_book_outlined,
                strikethrough: true,
                label: 'لم يحفظ',
                subLabel: _missedFeeLabel,
                color: AppColors.error,
                selected: missed,
                selectedInk: AppColors.onError,
                // Absent is already charged for the absence; charging the same
                // day twice for a missed recitation would double-bill a student
                // who never even sat down, and the server refuses this pairing
                // too.
                enabled: canMemorize && !isSaving,
                onTap: () => onToggleMissed(!missed),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// What not reciting costs, or null where the halaqa charges nothing for it
  /// — the toggle then reads as a plain "لم يحفظ" rather than claiming a
  /// price of zero.
  String? get _missedFeeLabel =>
      missedMemorizationFee > 0 ? formatFine(missedMemorizationFee) : null;

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
