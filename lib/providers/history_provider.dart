import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/services/scan_service.dart';

class HistoryState {
  final List<ScanResultModel> scans;
  final bool isLoading;
  final String selectedFilter; // All, Disease, Defect, Healthy
  final String searchQuery;
  final String? errorMessage;

  HistoryState({
    this.scans = const [],
    this.isLoading = false,
    this.selectedFilter = 'All',
    this.searchQuery = '',
    this.errorMessage,
  });

  List<ScanResultModel> get filteredScans {
    return scans.where((scan) {
      // Type Filter
      if (selectedFilter != 'All') {
        if (selectedFilter.toLowerCase() != scan.condition.type.toLowerCase()) {
          return false;
        }
      }
      // Search Query Filter
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchEn = scan.condition.en.toLowerCase().contains(q);
        final matchSi = scan.condition.si.toLowerCase().contains(q);
        final matchVar = scan.variety?.en.toLowerCase().contains(q) ?? false;
        if (!matchEn && !matchSi && !matchVar) return false;
      }
      return true;
    }).toList();
  }

  List<ScanResultModel> get recentScans => scans.take(5).toList();

  HistoryState copyWith({
    List<ScanResultModel>? scans,
    bool? isLoading,
    String? selectedFilter,
    String? searchQuery,
    String? errorMessage,
  }) {
    return HistoryState(
      scans: scans ?? this.scans,
      isLoading: isLoading ?? this.isLoading,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(HistoryState()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await scanService.getScanHistory();
      state = state.copyWith(scans: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load scan history');
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> deleteScan(String scanId) async {
    final previousScans = state.scans;
    final updated = state.scans.where((s) => s.scanId != scanId).toList();
    state = state.copyWith(scans: updated);
    try {
      await scanService.deleteScan(scanId);
    } catch (_) {
      state = state.copyWith(scans: previousScans);
    }
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
