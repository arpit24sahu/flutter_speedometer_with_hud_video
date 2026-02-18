import 'package:flutter/material.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import '../../di/injection_container.dart';
import 'badge_definitions.dart';
import 'badge_model.dart';
import 'badge_service.dart';

/// Bottom-sheet page that displays all badges in a 3-column grid.
///
/// Layout:
/// - 3-column grid
/// - Unlocked badges first (newest on top), locked badges after
/// - Positions index 1, 2, 4 (2nd, 3rd, 5th slots – 0-indexed) are populated last
/// - Stark contrast between unlocked / locked states
/// - Compact text, no render-overflow
class BadgeStatusPage extends StatelessWidget {
  const BadgeStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getIt<BadgeService>().initialize(),
      builder: (context, snapshot) {
        return ListenableBuilder(
          listenable: getIt<BadgeService>(),
          builder: (context, _) => _BadgeStatusContent(),
        );
      },
    );
  }
}

class _BadgeStatusContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final badgeService = getIt<BadgeService>();
    final allBadges = BadgeDefinitions.allBadges;
    final theme = Theme.of(context);

    // ── 1. Separate & sort ──
    final unlocked = <AppBadge>[];
    final locked = <AppBadge>[];

    for (var badge in allBadges) {
      if (badgeService.isBadgeUnlocked(badge.id)) {
        unlocked.add(badge);
      } else {
        locked.add(badge);
      }
    }

    unlocked.sort((a, b) {
      final dateA = badgeService.getBadgeUnlockDate(a.id);
      final dateB = badgeService.getBadgeUnlockDate(b.id);
      if (dateA != null && dateB != null) return dateB.compareTo(dateA);
      return 0;
    });

    locked.sort((a, b) => a.attainabilityScore.compareTo(b.attainabilityScore));

    final sortedList = [...unlocked, ...locked];
    final totalCount = sortedList.length;

    // ── 2. Special grid order: indices 1, 2, 4 are populated last ──
    final List<AppBadge?> displayList = List.filled(totalCount, null);
    const lastIndices = [1, 2, 4];
    final priorityIndices = <int>[];

    for (int i = 0; i < totalCount; i++) {
      if (!lastIndices.contains(i)) {
        priorityIndices.add(i);
      }
    }

    int cursor = 0;

    for (final gridIndex in priorityIndices) {
      if (cursor < sortedList.length) {
        displayList[gridIndex] = sortedList[cursor++];
      }
    }

    for (final gridIndex in lastIndices) {
      if (gridIndex < totalCount && cursor < sortedList.length) {
        displayList[gridIndex] = sortedList[cursor++];
      }
    }

    final gridItems = displayList.whereType<AppBadge>().toList();

    final unlockedCount = unlocked.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ──
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[350],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),

        // ── Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Badges',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                '$unlockedCount / $totalCount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 16, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Progress bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Grid ──
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: gridItems.length,
            itemBuilder: (context, index) {
              final badge = gridItems[index];
              final isUnlocked = badgeService.isBadgeUnlocked(badge.id);
              return _BadgeTile(badge: badge, isUnlocked: isUnlocked);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Individual badge tile — stark locked / unlocked contrast
// ─────────────────────────────────────────────────────────────
class _BadgeTile extends StatelessWidget {
  final AppBadge badge;
  final bool isUnlocked;

  const _BadgeTile({required this.badge, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isUnlocked ? Colors.white : Colors.grey[100],
        border: Border.all(
          color: isUnlocked
              ? badge.color.withOpacity(0.45)
              : Colors.grey[300]!,
          width: isUnlocked ? 1.8 : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: badge.color.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showBadgeDetails(context, badge, isUnlocked),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? badge.color.withOpacity(0.15)
                        : Colors.grey[200],
                    border: isUnlocked
                        ? Border.all(
                            color: badge.color.withOpacity(0.3),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Icon(
                    badge.icon,
                    size: 22,
                    color: isUnlocked ? badge.color : Colors.grey[400],
                  ),
                ),

                const SizedBox(height: 8),

                // Badge name
                Flexible(
                  child: Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isUnlocked ? FontWeight.w700 : FontWeight.w500,
                      color: isUnlocked ? Colors.black87 : Colors.grey[500],
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Status indicator
                if (isUnlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green[600]),
                      const SizedBox(width: 2),
                      Text(
                        'Unlocked',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  )
                else
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show badge details bottom sheet with analytics tracking.
  void _showBadgeDetails(
    BuildContext context,
    AppBadge badge,
    bool isUnlocked,
  ) {
    final openedAt = DateTime.now();

    // Track screen view
    AnalyticsService().trackEvent(
      AnalyticsEvents.badgeDetailsScreenView,
      properties: {
        AnalyticsParams.badgeId: badge.id.name,
        AnalyticsParams.badgeName: badge.name,
        AnalyticsParams.badgeDescription: badge.description,
        AnalyticsParams.badgeIsUnlocked: isUnlocked,
      },
    );

    final badgeColor = isUnlocked ? badge.color : Colors.grey;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Badge icon — colored if unlocked, grey if locked
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor.withOpacity(isUnlocked ? 0.12 : 0.08),
                  border: Border.all(
                    color: badgeColor.withOpacity(isUnlocked ? 0.4 : 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  badge.icon,
                  size: 36,
                  color: badgeColor,
                ),
              ),

              const SizedBox(height: 16),

              // Badge name
              Text(
                badge.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isUnlocked ? Colors.black87 : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                badge.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Unlock status chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_outline_rounded,
                      size: 16,
                      color:
                          isUnlocked ? Colors.green[700] : Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUnlocked ? 'Unlocked' : 'Locked',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked
                            ? Colors.green[700]
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Track dismiss with time spent
      final durationSeconds =
          DateTime.now().difference(openedAt).inSeconds;
      AnalyticsService().trackEvent(
        AnalyticsEvents.badgeDetailsScreenDismissed,
        properties: {
          AnalyticsParams.badgeId: badge.id.name,
          AnalyticsParams.badgeName: badge.name,
          AnalyticsParams.badgeDescription: badge.description,
          AnalyticsParams.badgeIsUnlocked: isUnlocked,
          AnalyticsParams.durationSeconds: durationSeconds,
        },
      );
    });
  }
}
