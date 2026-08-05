import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/data/models/parent/parent_child_model.dart';
import '../../features/data/repositories/parent_repository.dart';
import 'auth_provider.dart';

class SelectedChildState {
  final bool isLoading;
  final List<ParentChildModel> children;
  final ParentChildModel? selected;
  final String? errorMessage;

  SelectedChildState({
    this.isLoading = false,
    this.children = const [],
    this.selected,
    this.errorMessage,
  });

  SelectedChildState copyWith({
    bool? isLoading,
    List<ParentChildModel>? children,
    ParentChildModel? selected,
    String? errorMessage,
  }) {
    return SelectedChildState(
      isLoading: isLoading ?? this.isLoading,
      children: children ?? this.children,
      selected: selected ?? this.selected,
      errorMessage: errorMessage,
    );
  }
}

class SelectedChildNotifier extends Notifier<SelectedChildState> {
  final _repo = ParentRepository();

  @override
  SelectedChildState build() => SelectedChildState();

  Future<void> load() async {
    final parentId = ref.read(authProvider).user?.parentId;
    if (parentId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final children = await _repo.getChildren(parentId);
      state = SelectedChildState(
        isLoading: false,
        children: children,
        selected: children.isNotEmpty ? children.first : null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل بيانات الأبناء',
      );
    }
  }

  void select(ParentChildModel child) {
    state = state.copyWith(selected: child);
  }
}

final selectedChildProvider =
    NotifierProvider<SelectedChildNotifier, SelectedChildState>(() {
  return SelectedChildNotifier();
});
