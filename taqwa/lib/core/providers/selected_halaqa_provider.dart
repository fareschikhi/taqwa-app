import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/data/models/halaqa/halaqa_model.dart';
import '../../features/data/repositories/halaqa_repository.dart';

/// The halaqa a teacher is working in. A teacher with several halaqas sees
/// one at a time, the way a parent sees one child at a time; every tab of
/// the teacher shell reads [selected] and keeps to it.
class SelectedHalaqaState {
  final bool isLoading;
  final List<HalaqaModel> halaqas;

  /// Null only before the list loads, when it failed, or for a teacher with
  /// no halaqa at all — the tabs then show every student, as they did before
  /// the switcher existed.
  final HalaqaModel? selected;

  const SelectedHalaqaState({
    this.isLoading = false,
    this.halaqas = const [],
    this.selected,
  });
}

class SelectedHalaqaNotifier extends Notifier<SelectedHalaqaState> {
  final _repo = HalaqaRepository();

  /// Starts loading so the shell waits for the first answer instead of
  /// letting its tabs fetch every halaqa and then again for one.
  @override
  SelectedHalaqaState build() => const SelectedHalaqaState(isLoading: true);

  /// `GET /halaqas` returns only the teacher's own halaqas. Starts from
  /// nothing: the provider outlives a sign-out, and the previous teacher's
  /// halaqas must not show while the next one's load.
  Future<void> load() async {
    state = const SelectedHalaqaState(isLoading: true);
    try {
      final halaqas = await _repo.getAllHalaqas();
      state = SelectedHalaqaState(
        halaqas: halaqas,
        selected: halaqas.firstOrNull,
      );
    } catch (_) {
      // The switcher is a filter on top of screens that work without it, so
      // a failure leaves them on every halaqa rather than blocking the shell.
      state = const SelectedHalaqaState();
    }
  }

  void select(HalaqaModel halaqa) {
    state = SelectedHalaqaState(halaqas: state.halaqas, selected: halaqa);
  }
}

final selectedHalaqaProvider =
    NotifierProvider<SelectedHalaqaNotifier, SelectedHalaqaState>(
      SelectedHalaqaNotifier.new,
    );

/// Whether something in halaqa [halaqaId] belongs on screen: always when no
/// halaqa is selected, otherwise only for the selected one.
bool inSelectedHalaqa(int? halaqaId, HalaqaModel? selected) =>
    selected == null || halaqaId == selected.id;
