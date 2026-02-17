import 'package:flutter/material.dart';
import 'badge_card.dart';
import 'badge_manager.dart';
import 'badge_service.dart';

/// Bottom sheet for displaying badges
class BadgeBottomSheet extends StatefulWidget {
  final BadgeService badgeService;
  final BadgeCategory? category;

  const BadgeBottomSheet({
    super.key,
    required this.badgeService,
    this.category,
  });

  @override
  State<BadgeBottomSheet> createState() => _BadgeBottomSheetState();
}

class _BadgeBottomSheetState extends State<BadgeBottomSheet> {
  List<Map<String, dynamic>> _badges = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (widget.category == null || widget.category == BadgeCategory.all) {
      _badges = widget.badgeService.getAllBadgesForUI();
    } else {
      final categorizedBadges = widget.badgeService.getBadgesByCategory();
      _badges = categorizedBadges[widget.category!.name] ?? [];
    }

    _stats = widget.badgeService.getStatsSummary();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              _buildHeader(),
              if (!_isLoading) _buildStatsBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBadgesList(scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.category == null || widget.category == BadgeCategory.all
                    ? 'All Badges'
                    : _getCategoryName(widget.category!),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final unlockedCount = _stats['unlockedBadges'] as int;
    final totalCount = _stats['totalBadges'] as int;
    final progress = _stats['progress'] as double;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade300,
            Colors.orange.shade300,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$unlockedCount / $totalCount unlocked',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesList(ScrollController scrollController) {
    if (_badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No badges yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        return BadgeCard(
          badgeData: _badges[index],
          onTap: () => _showBadgeDetails(_badges[index]),
        );
      },
    );
  }

  void _showBadgeDetails(Map<String, dynamic> badgeData) {
    final badge = badgeData['badge'] as Map<String, dynamic>;
    final isUnlocked = badgeData['isUnlocked'] as bool;
    final unlockDate = badgeData['unlockDate'] as String?;
    final progress = badgeData['progress'] as double;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Color(badge['color'] as int).withOpacity(0.2)
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(badge['icon'] as int, fontFamily: 'MaterialIcons'),
                  size: 50,
                  color: isUnlocked
                      ? Color(badge['color'] as int)
                      : Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                badge['name'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                badge['description'] as String,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (isUnlocked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Unlocked ${_formatDate(unlockDate)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(badge['color'] as int),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}% Complete',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryName(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.all:
        return 'All Badges';
      case BadgeCategory.recording:
        return 'Recording';
      case BadgeCategory.export:
        return 'Export';
      case BadgeCategory.streak:
        return 'Streaks';
      case BadgeCategory.share:
        return 'Sharing';
      case BadgeCategory.speed:
        return 'Speed';
      case BadgeCategory.premium:
        return 'Premium';
      case BadgeCategory.leaderboard:
        return 'Leaderboard';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'on ${date.day}/${date.month}/${date.year}';
    }
  }
}
