import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/data/models/parent/parent_child_model.dart';
import '../../features/data/models/user_model.dart';
import '../../features/data/repositories/parent_repository.dart';
import 'auth_provider.dart';

class SelectedStudentState {
  final bool isLoading;
  final List<ParentChildModel> students;
  final ParentChildModel? selected;
  final String? errorMessage;

  SelectedStudentState({
    this.isLoading = false,
    this.students = const [],
    this.selected,
    this.errorMessage,
  });

  SelectedStudentState copyWith({
    bool? isLoading,
    List<ParentChildModel>? students,
    ParentChildModel? selected,
    String? errorMessage,
  }) {
    return SelectedStudentState(
      isLoading: isLoading ?? this.isLoading,
      students: students ?? this.students,
      selected: selected ?? this.selected,
      errorMessage: errorMessage,
    );
  }
}

class SelectedStudentNotifier extends Notifier<SelectedStudentState> {
  final _repo = ParentRepository();

  @override
  SelectedStudentState build() => SelectedStudentState();

  Future<void> load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // An adult student is his own guardian: the list he switches between is
      // just himself, so the screens below can stay unaware of which role is
      // looking at them.
      final students = user.role == UserRole.adultStudent
          ? await _repo.getSelf(user.studentId!)
          : await _repo.getChildren(user.parentId!);

      state = SelectedStudentState(
        isLoading: false,
        students: students,
        selected: students.isNotEmpty ? students.first : null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل البيانات',
      );
    }
  }

  void select(ParentChildModel child) {
    state = state.copyWith(selected: child);
  }
}

final selectedStudentProvider =
    NotifierProvider<SelectedStudentNotifier, SelectedStudentState>(() {
  return SelectedStudentNotifier();
});
