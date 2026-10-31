import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bananaguard_ai/core/constants.dart';
import 'package:bananaguard_ai/providers/history_provider.dart';
import 'package:bananaguard_ai/widgets/condition_card.dart';
import 'package:bananaguard_ai/widgets/empty_state.dart';
import 'package:bananaguard_ai/widgets/animated_toast.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  final List<String> _filters = ['All', 'Disease', 'Defect', 'Healthy'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyState = ref.watch(historyProvider);
    final filteredScans = historyState.filteredScans;

    final lang = Localizations.localeOf(context).languageCode;
    String title = 'Scan History';
    String searchHint = 'Search condition or variety...';
    String allText = 'All';
    String diseaseText = 'Disease';
    String defectText = 'Defect';
    String healthyText = 'Healthy';
    String emptyTitle = 'No Scans Found';
    String emptyMessage = 'You have not scanned any bananas yet or matching this filter.';
    String deleteTitle = 'Delete Scan';
    String deleteConfirm = 'Are you sure you want to remove this scan from history?';
    String cancelText = 'Cancel';
    String deleteText = 'Delete';
    String scanRemovedText = 'Scan removed';

    if (lang == 'si') {
      title = 'ස්කෑන් ඉතිහාසය';
      searchHint = 'තත්ත්වය හෝ ප්‍රභේදය සොයන්න...';
      allText = 'සියල්ල';
      diseaseText = 'රෝග';
      defectText = 'හානි';
      healthyText = 'නීරෝගී';
      emptyTitle = 'ස්කෑන් වාර්තා හමු නොවීය';
      emptyMessage = 'ඔබ තවමත් කෙසෙල් පරීක්ෂාවක් සිදු කර නැත.';
      deleteTitle = 'වාර්තාව මකන්න';
      deleteConfirm = 'මෙම වාර්තාව ඉතිහාසයෙන් ඉවත් කිරීමට ඔබට විශ්වාසද?';
      cancelText = 'අවලංගු කරන්න';
      deleteText = 'මකන්න';
      scanRemovedText = 'වාර්තාව ඉවත් කරන ලදී';
    } else if (lang == 'ta') {
      title = 'ஸ்கேன் வரலாறு';
      searchHint = 'நிலை அல்லது வகையைத் தேடுங்கள்...';
      allText = 'அனைத்தும்';
      diseaseText = 'நோய்';
      defectText = 'குறைபாடு';
      healthyText = 'ஆரோக்கியமானது';
      emptyTitle = 'ஸ்கேன்கள் எதுவும் கிடைக்கவில்லை';
      emptyMessage = 'நீங்கள் இன்னும் எந்த வாழைப்பழத்தையும் ஸ்கேன் செய்யவில்லை.';
      deleteTitle = 'ஸ்கேனை நீக்கு';
      deleteConfirm = 'வரலாற்றில் இருந்து இந்த ஸ்கேனை நீக்க நிச்சயமாக விரும்புகிறீர்களா?';
      cancelText = 'ரத்து செய்';
      deleteText = 'நீக்கு';
      scanRemovedText = 'ஸ்கேன் நீக்கப்பட்டது';
    }

    String getFilterLabel(String key) {
      switch (key) {
        case 'Disease':
          return diseaseText;
        case 'Defect':
          return defectText;
        case 'Healthy':
          return healthyText;
        case 'All':
        default:
          return allText;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(historyProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  ref.read(historyProvider.notifier).setSearchQuery(val);
                },
              ),
            ),

            // Filter Chips (All, Disease, Defect, Healthy)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = historyState.selectedFilter == filter;

                  return ChoiceChip(
                    label: Text(getFilterLabel(filter)),
                    selected: isSelected,
                    selectedColor: AppConstants.primaryGreen,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(historyProvider.notifier).setFilter(filter);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // List of scans with swipe-to-delete
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(historyProvider.notifier).loadHistory(),
                child: historyState.isLoading && historyState.scans.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppConstants.primaryGreen),
                      )
                    : filteredScans.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: Center(
                                  child: EmptyStateWidget(
                                    icon: Icons.history_rounded,
                                    title: emptyTitle,
                                    message: historyState.searchQuery.isNotEmpty
                                        ? '$emptyMessage ("${historyState.searchQuery}")'
                                        : emptyMessage,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            itemCount: filteredScans.length,
                        itemBuilder: (context, index) {
                          final scan = filteredScans[index];

                          return Dismissible(
                            key: Key(scan.scanId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: AppConstants.severitySevere,
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(deleteTitle),
                                  content: Text(deleteConfirm),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(cancelText),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(deleteText, style: const TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) {
                              ref.read(historyProvider.notifier).deleteScan(scan.scanId);
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted) return;
                                showAnimatedToast(
                                  context,
                                  duration: const Duration(seconds: 4),
                                  bottomOffset: 16.0,
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          scanRemovedText,
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              });
                            },
                            child: ConditionCard(
                              scan: scan,
                              onTap: () => context.push('/scan-detail?id=${scan.scanId}'),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
