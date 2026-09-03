import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pvp_insights/data/pvp_insights_repository.dart';
import 'package:yudha_mobile/features/pvp_insights/domain/pvp_insights.dart';

class PvpInsightsState {
  const PvpInsightsState({
    required this.loading,
    required this.window,
    required this.mode,
    this.dashboard,
    this.error,
  });

  factory PvpInsightsState.initial() => const PvpInsightsState(
    loading: true,
    window: PvpInsightsWindow.thirtyDays,
    mode: PvpInsightsMode.all,
  );

  final bool loading;
  final PvpInsightsWindow window;
  final PvpInsightsMode mode;
  final PvpInsightsDashboard? dashboard;
  final String? error;

  PvpInsightsState copyWith({
    bool? loading,
    PvpInsightsWindow? window,
    PvpInsightsMode? mode,
    PvpInsightsDashboard? dashboard,
    String? error,
    bool clearError = false,
  }) => PvpInsightsState(
    loading: loading ?? this.loading,
    window: window ?? this.window,
    mode: mode ?? this.mode,
    dashboard: dashboard ?? this.dashboard,
    error: clearError ? null : error ?? this.error,
  );
}

class PvpInsightsController extends StateNotifier<PvpInsightsState> {
  PvpInsightsController(this._repository) : super(PvpInsightsState.initial()) {
    load();
  }

  final PvpInsightsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final dashboard = await _repository.fetch(
        window: state.window,
        mode: state.mode,
      );
      state = state.copyWith(
        loading: false,
        dashboard: dashboard,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'PvP Insights belum dapat dimuat. Coba lagi.',
      );
    }
  }

  Future<void> setWindow(PvpInsightsWindow value) async {
    state = state.copyWith(window: value);
    await load();
  }

  Future<void> setMode(PvpInsightsMode value) async {
    state = state.copyWith(mode: value);
    await load();
  }
}
