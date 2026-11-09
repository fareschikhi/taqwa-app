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
import '../../../../core/widgets/late_fee_dialog.dart';
import '../../../../core/utils/memorization_duplicates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/selected_halaqa_provider.dart';
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

  /// What the sheet held the moment it finished loading: the server's own
  /// rows, with present filled in for every student it had none for.
  ///
  /// Saving is measured against [_savedAttendance], because an untouched
  /// default still has to reach the server. Backing out is measured against
  /// this instead — walking away from defaults loses nothing, since the next
  /// open rebuilds them, so only a mark the teacher moved by hand is worth
  /// warning about.
  final Map<int, AttendanceStatus> _initialAttendance = {};

  final Set<int> _memorizedStudentIds = {};

  // What is already on file for today, per student. The ids alone would say
  // that a repeat is happening; the rows let the warning name the work.
  final Map<int, List<Map<String, dynamic>>> _todayMemorization = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final Set<int> _savingStudentIds = {};

  /// Every student of every halaqa the teacher has. The sheet loads, caches
  /// and queues for all of them, so marks made in one halaqa are still there
  /// after a look at another; what is shown and saved is [_students].
  List<TeacherStudentModel> _roster = [];

  /// The students of the halaqa picked in the shell's switcher — the only
  /// ones listed, counted and sent by the save button.
  List<TeacherStudentModel> get _students {
    final selected = ref.read(selectedHalaqaProvider).selected;
    return _roster
        .where((s) => inSelectedHalaqa(s.halaqaId, selected))
        .toList();
  }

  final _repo = TeacherRepository();
  final _halaqaRepo = HalaqaRepository();

  /// Each student's own halaqa, resolved once when the roster loads. A
  /// student's row from `GET /students` nests only `id`, `name` and `level`
  /// for his halaqa — not the fine fields — so this holds the full
  /// [HalaqaModel] (fetched separately) for whichever id he belongs to. A
  /// student with no entry here is treated as a child: never fined.
  final Map<int, HalaqaModel> _studentHalaqa = {};

  bool _isAdultStudent(int studentId) =>
      _studentHalaqa[studentId]?.isAdult ?? false;

  int _lateFeeFor(int studentId) => _studentHalaqa[studentId]?.lateFee ?? 0;

  /// Late amounts the teacher picked in the fee dialog that the server has
  /// not taken yet (studentId -> DA). Cleared per student once a save carries
  /// it, so a later re-save without a new choice leaves the charge alone.
  final Map<int, int> _lateFees = {};

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

  /// Unsaved marks in the halaqa on screen. Another halaqa's marks wait for
  /// the teacher to switch back to it rather than riding along unseen.
  Set<int> get _pendingIds {
    final visible = _students.map((s) => s.id).toSet();
    return pendingAttendanceIds(
      draft: _attendance,
      saved: _savedAttendance,
      lateFees: _lateFees,
    ).where(visible.contains).toSet();
  }

  /// Students the teacher has moved away from what the sheet loaded with.
  /// The same comparison as [_pendingIds], run against the baseline instead
  /// of the server, so defaults nobody touched do not count as work to lose.
  /// Unlike it, this spans every halaqa: leaving the shell loses them all.
  Set<int> get _handEditedIds => pendingAttendanceIds(
    draft: _attendance,
    saved: _initialAttendance,
    lateFees: _lateFees,
  );

  /// Forgets the fees a successful save carried — but only where the teacher
  /// has not picked another one while the request was out.
  void _clearSentLateFees(List<Map<String, dynamic>> sent) {
    for (final record in sent) {
      final id = record['studentId'] as int;
      final fee = record['lateFee'];
      if (fee != null && _lateFees[id] == fee) _lateFees.remove(id);
    }
  }

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
      if (_roster.isEmpty) _isLoading = true;
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
        _roster.isEmpty
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
    for (final record in existingRecords) {
      final sId = (record['studentId'] as num?)?.toInt();
      final st = record['status'] as String?;
      if (sId != null && st != null) existingMap[sId] = st;
    }

    final memorizedByStudent = memorizationByStudent(memorizationRecords);

    // Pull-to-refresh runs on a screen the teacher may have half-marked, and
    // an unsaved chip exists nowhere else. Refreshing therefore updates what
    // the server is known to hold without overwriting those chips.
    final stillPending = _pendingIds;

    setState(() {
      _roster = studentList;
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
      }
      // Held marks belong on the chips, not only in the banner. Reopened
      // offline, the sheet would otherwise show the old rows, and a save
      // from there would queue present for everyone over what was held.
      // They stay pending, because the server has not taken them.
      for (final record in _queued) {
        final id = record['studentId'] as int;
        if (record['date'] != today || stillPending.contains(id)) continue;
        _attendance[id] = attendanceStatusFromApi(record['status'] as String);
        final fee = record['lateFee'];
        if (fee is int) _lateFees[id] = fee;
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

    final next = _nextToRecite(after: student);
    final result = await showModalBottomSheet<MemorizationEntryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemorizationEntrySheet(
        student: student,
        nextStudentName: next?.fullName,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _memorizedStudentIds.add(student.id);
      _todayMemorization.putIfAbsent(student.id, () => []).add(result.record);
    });
    // The teacher is working down the halaqa, so the next sheet opens in
    // place of the list rather than making her find and tap the next row.
    if (result.next && next != null) _openMemorizationSheet(next);
  }

  /// Students still waiting to recite: here today, with nothing on file yet.
  bool _awaitsRecitation(TeacherStudentModel s) =>
      _attendance[s.id]?.isAway != true &&
      !_memorizedStudentIds.contains(s.id);

  /// The first student after [after] — or from the top, without it — still
  /// waiting to recite, in the order the list shows them. Null at the end.
  TeacherStudentModel? _nextToRecite({TeacherStudentModel? after}) {
    final list = _students;
    final from = after == null
        ? 0
        : list.indexWhere((s) => s.id == after.id) + 1;
    for (final s in list.skip(from)) {
      if (_awaitsRecitation(s)) return s;
    }
    return null;
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

    final record = attendanceBatchPayload(
      draft: {studentId: status},
      saved: const {},
      date: _todayStr,
      lateFees: _lateFees,
    ).first;

    setState(() => _savingStudentIds.add(studentId));
    try {
      await _repo.upsertAttendance(
        studentId: studentId,
        date: _todayStr,
        status: apiStatus,
        lateFee: record['lateFee'] as int?,
      );
      if (mounted) {
        setState(() {
          _savedAttendance[studentId] = status;
          _clearSentLateFees([record]);
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
    // Only the halaqa on screen is saved; [_pendingIds] says why.
    final visible = _students.map((s) => s.id).toSet();
    final payload = attendanceBatchPayload(
      draft: {
        for (final e in _attendance.entries)
          if (visible.contains(e.key)) e.key: e.value,
      },
      saved: _savedAttendance,
      date: _todayStr,
      lateFees: _lateFees,
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
        }
        _clearSentLateFees(payload);
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
        }
        _clearSentLateFees(sending);
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

    // Going absent or excused discards recitation the teacher already
    // entered. The write only happens on save, but the badge disappears the
    // moment the chip is tapped, so the warning belongs here rather than at
    // save time.
    if (tapped.isAway && _memorizedStudentIds.contains(student.id)) {
      final confirmed = await ConfirmDiscardMemorizationDialog.show(
        context,
        studentName: student.fullName,
        markLabel: tapped == AttendanceStatus.excused ? 'كصاحب عذر' : 'كغائب',
      );
      if (!confirmed) return;
    }

    // Lateness costs what the teacher says it costs, not a flat rate: five
    // minutes and an hour are not the same offence. Only adult halaqas are
    // fined at all, so a child goes straight to late with no question.
    int? lateFee;
    if (!mounted) return;
    if (tapped == AttendanceStatus.late && _isAdultStudent(student.id)) {
      lateFee = await LateFeeDialog.show(
        context,
        title: student.fullName,
        defaultFee: _lateFeeFor(student.id),
      );
      // Backing out of the dialog means "not late after all".
      if (lateFee == null || !mounted) return;
    }

    setState(() {
      _attendance[student.id] = tapped;
      if (lateFee != null) {
        _lateFees[student.id] = lateFee;
      } else {
        _lateFees.remove(student.id);
      }
      if (tapped.isAway) {
        _memorizedStudentIds.remove(student.id);
        _todayMemorization.remove(student.id);
      }
    });
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
      if (next.user?.teacherId != null && _roster.isEmpty && !_isLoading) {
        _loadData();
      }
    });
    // A switch needs no fetch — the whole roster is already here — only a
    // redraw of [_students].
    ref.watch(selectedHalaqaProvider.select((s) => s.selected?.id));

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
                            : _buildTable(),
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

  /// What is already recorded today, in one line for the student's card —
  /// the latest entry, with a count when there is more than one.
  String? _todaySummaryOf(int studentId) {
    final entries = _todayMemorization[studentId];
    if (entries == null || entries.isEmpty) return null;
    final latest = memorizationSummary(entries.last);
    return entries.length > 1 ? '$latest (+${entries.length - 1})' : latest;
  }

  Widget _buildProgress() {
    final total = _students.length;
    final unsavedCount = total - _savedCount;
    final here = _students
        .where((s) => _attendance[s.id]?.isAway != true)
        .length;
    final recited = here - _students.where(_awaitsRecitation).length;
    final firstToRecite = _nextToRecite();
    final allRecited = here > 0 && recited == here;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recitation leads the page: one button that walks the teacher
          // through everyone still waiting, sheet after sheet, with the
          // attendance table below it for the exceptions.
          if (firstToRecite != null)
            AppButton(
              label: 'تسجيل العرض ($recited / $here)',
              variant: AppButtonVariant.gradient,
              icon: Icons.menu_book_outlined,
              onPressed: () => _openMemorizationSheet(firstToRecite),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.present.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: AppColors.present.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(
                    allRecited
                        ? 'تم تسجيل عرض الحاضرين'
                        : 'لا يوجد حاضرون للعرض',
                    style: AppTextStyles.labelMdBold.copyWith(
                      color: allRecited
                          ? AppColors.present
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (allRecited) ...[
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18.w,
                      color: AppColors.present,
                    ),
                  ],
                ],
              ),
            ),
          SizedBox(height: 12.h),
          Row(
            children: [
              AppText(
                '$_savedCount / $total',
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  child: LinearProgressIndicator(
                    value: total > 0 ? _savedCount / total : 0,
                    minHeight: 8.h,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              AppText(
                _savedCount < total ? 'غير محفوظ $unsavedCount' : 'تم حفظ الكل',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One fee shared by every visible student it applies to, or null when it
  /// is free or differs between them ("all halaqas" view) — a header can
  /// only print one price without lying about the others.
  String? _sharedFee(int Function(int studentId) feeOf) {
    final fees = _students
        .where((s) => _isAdultStudent(s.id))
        .map((s) => feeOf(s.id))
        .toSet();
    if (fees.length != 1 || fees.first <= 0) return null;
    return formatFine(fees.first);
  }

  /// Marks every student on screen with [status] from the column header.
  ///
  /// Going absent wipes recitation already entered, which the single-row tap
  /// confirms per student. Asking once per student in bulk would be a wall of
  /// dialogs, so those students are left as they are and the teacher is told.
  ///
  /// Marking late asks for one fee for the whole group, applied to the adult
  /// students who were not late already — a student marked late earlier keeps
  /// the amount chosen for him.
  Future<void> _markAll(AttendanceStatus status) async {
    int? lateFee;
    if (status == AttendanceStatus.late) {
      final newlyLateAdults = _students
          .where(
            (s) =>
                !_savingStudentIds.contains(s.id) &&
                _attendance[s.id] != AttendanceStatus.late &&
                _isAdultStudent(s.id),
          )
          .toList();
      if (newlyLateAdults.isNotEmpty) {
        lateFee = await LateFeeDialog.show(
          context,
          title: newlyLateAdults.length == 1
              ? newlyLateAdults.first.fullName
              : 'تحديد ${newlyLateAdults.length} طالب كمتأخرين',
          defaultFee: _lateFeeFor(newlyLateAdults.first.id),
        );
        if (lateFee == null || !mounted) return;
      }
    }

    var skipped = 0;
    setState(() {
      for (final s in _students) {
        if (_savingStudentIds.contains(s.id)) continue;
        if (status.isAway) {
          if (_memorizedStudentIds.contains(s.id)) {
            if (_attendance[s.id] != status) skipped++;
            continue;
          }
        }
        if (status == AttendanceStatus.late) {
          if (_attendance[s.id] != AttendanceStatus.late &&
              lateFee != null &&
              _isAdultStudent(s.id)) {
            _lateFees[s.id] = lateFee;
          }
        } else {
          _lateFees.remove(s.id);
        }
        _attendance[s.id] = status;
      }
    });
    if (skipped > 0) {
      _showSnack(
        'لم يُغيَّر $skipped طالب لديهم عرض مسجّل اليوم',
        isError: true,
      );
    }
  }

  Widget _buildTable() {
    final students = _students;
    final pending = _pendingIds;

    bool allAre(AttendanceStatus status) =>
        students.every((s) => _attendance[s.id] == status);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          children: [
            _AttendanceHeaderRow(
              lateFee: _sharedFee(_lateFeeFor),
              allAre: allAre,
              onMarkAll: _markAll,
            ),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: students.length,
                itemBuilder: (_, i) {
                  final student = students[i];
                  final status =
                      _attendance[student.id] ?? AttendanceStatus.unset;
                  return _AttendanceTableRow(
                    name: student.fullName,
                    status: status,
                    isLast: i == students.length - 1,
                    isSaving: _savingStudentIds.contains(student.id),
                    isPending: pending.contains(student.id),
                    todaySummary: _todaySummaryOf(student.id),
                    onSelectStatus: (s) => _onChipTap(student, s),
                    onOpenMemorization: () => _openMemorizationSheet(student),
                  );
                },
              ),
            ),
          ],
        ),
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

/// Width of every mark column. With four marks, 44 keeps each circle a full
/// touch target while leaving the name column room for two-word names on a
/// 360-wide phone.
double get _markColumnWidth => 44.w;

/// The status columns, laid out left to right. The app lays rows out LTR, so
/// present is listed last to sit right next to the name for an Arabic reader.
const _markColumns = [
  (AttendanceStatus.excused, 'عذر'),
  (AttendanceStatus.late, 'متأخر'),
  (AttendanceStatus.absent, 'غائب'),
  (AttendanceStatus.present, 'حاضر'),
];

/// The table's header: a label per column, and under each status a circle
/// that marks the whole halaqa at once.
class _AttendanceHeaderRow extends StatelessWidget {
  const _AttendanceHeaderRow({
    required this.lateFee,
    required this.allAre,
    required this.onMarkAll,
  });

  final String? lateFee;
  final bool Function(AttendanceStatus status) allAre;
  final ValueChanged<AttendanceStatus> onMarkAll;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: AppColors.onPrimary.withValues(alpha: 0.25),
    );
    return Container(
      color: AppColors.primary,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (status, label) in _markColumns)
              _HeaderCell(
                label: label,
                subLabel: status == AttendanceStatus.late ? lateFee : null,
                divider: divider,
                child: _MarkCircle(
                  selected: allAre(status),
                  fill: AppColors.onPrimary,
                  ink: AppColors.primary,
                  border: AppColors.onPrimary,
                  semanticLabel: 'تحديد الكل $label',
                  onTap: () => onMarkAll(status),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppText(
                    'اسم الطالب',
                    style: AppTextStyles.bodyMdBold.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.divider,
    this.subLabel,
    this.child,
  });

  final String label;
  final String? subLabel;
  final BorderSide divider;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _markColumnWidth,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(border: Border(right: divider)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMdBold.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          if (subLabel != null)
            AppText(
              subLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          if (child != null) ...[SizedBox(height: 6.h), child!],
        ],
      ),
    );
  }
}

/// One student's line: a mark circle per status and the name — which opens
/// his recitation sheet.
class _AttendanceTableRow extends StatelessWidget {
  const _AttendanceTableRow({
    required this.name,
    required this.status,
    required this.isLast,
    required this.isSaving,
    required this.isPending,
    required this.onSelectStatus,
    required this.onOpenMemorization,
    this.todaySummary,
  });

  final String name;
  final AttendanceStatus status;
  final bool isLast;
  final bool isSaving;

  /// Marked on screen but not yet written; a circle looks identical either
  /// way, so the dot by the name is the only tell.
  final bool isPending;
  final String? todaySummary;

  final ValueChanged<AttendanceStatus> onSelectStatus;
  final VoidCallback onOpenMemorization;

  @override
  Widget build(BuildContext context) {
    const divider = BorderSide(color: AppColors.outlineVariant, width: 0.6);
    final canMemorize = !status.isAway;
    final enabled = !isSaving;

    Widget cell(Widget? child) => Container(
      width: _markColumnWidth,
      alignment: Alignment.center,
      decoration: const BoxDecoration(border: Border(right: divider)),
      child: child,
    );

    return Container(
      constraints: BoxConstraints(minHeight: 56.h),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: divider),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (itemStatus, label) in _markColumns)
              cell(
                isSaving && status == itemStatus
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : _MarkCircle(
                        selected: status == itemStatus,
                        fill: attendanceColors(itemStatus).fill,
                        ink: attendanceColors(itemStatus).ink,
                        border: AppColors.outlineVariant,
                        enabled: enabled,
                        semanticLabel: '$name: $label',
                        onTap: () => onSelectStatus(itemStatus),
                      ),
              ),
            Expanded(child: _buildNameCell(canMemorize)),
          ],
        ),
      ),
    );
  }

  /// The name, today's recitation once there is any, and this student's own
  /// عرض button — for the teacher who wants one student rather than the
  /// walk-through the button at the top runs. An absent student has nothing
  /// to recite and the server refuses it, so his button goes rather than
  /// sitting greyed.
  Widget _buildNameCell(bool canMemorize) {
    final recited = todaySummary != null && canMemorize;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
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
          ),
          if (recited) ...[
            SizedBox(height: 2.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: AppText(
                    todaySummary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.present,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.check_circle_rounded,
                  size: 14.w,
                  color: AppColors.present,
                ),
              ],
            ),
          ],
          if (canMemorize) ...[
            SizedBox(height: 6.h),
            _ReciteButton(
              recited: recited,
              studentName: name,
              enabled: !isSaving,
              onTap: onOpenMemorization,
            ),
          ],
        ],
      ),
    );
  }
}

/// One student's own entry into the recitation sheet.
///
/// Outlined in primary while he has not recited, so a row still waiting
/// stands out; tinted green once something is on file, offering another
/// entry (مراجعة after حفظ) rather than reading as a call to action.
class _ReciteButton extends StatelessWidget {
  const _ReciteButton({
    required this.recited,
    required this.studentName,
    required this.enabled,
    required this.onTap,
  });

  final bool recited;
  final String studentName;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.outlineVariant
        : recited
        ? AppColors.present
        : AppColors.primary;
    final label = recited ? 'إضافة عرض' : 'عرض';
    final radius = BorderRadius.circular(AppConstants.radiusFull);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label: $studentName',
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: recited ? 0.1 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            // 36 tall plus the row's own padding keeps a comfortable target
            // without making every row as tall as a card.
            constraints: BoxConstraints(minHeight: 36.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AppText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMdBold.copyWith(color: color),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  recited ? Icons.add_rounded : Icons.menu_book_outlined,
                  size: 18.w,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round mark of one status: an empty ring until chosen, then filled in
/// the status's own colour with a check.
class _MarkCircle extends StatelessWidget {
  const _MarkCircle({
    required this.selected,
    required this.fill,
    required this.ink,
    required this.border,
    required this.semanticLabel,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final Color fill;
  final Color ink;
  final Color border;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = 28.w;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: enabled && !selected ? onTap : null,
        radius: 22.w,
        child: Padding(
          // Pads the 28 circle out to a 44 touch target.
          padding: EdgeInsets.all(8.w),
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? (enabled ? fill : AppColors.surfaceContainerHigh)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? (enabled ? fill : AppColors.surfaceContainerHigh)
                    : enabled
                    ? border
                    : border.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 18.w, color: ink)
                : null,
          ),
        ),
      ),
    );
  }
}
