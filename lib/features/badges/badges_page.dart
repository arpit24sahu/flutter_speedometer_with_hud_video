import 'package:flutter/material.dart';
import 'badge_card.dart';
import 'badge_manager.dart';
import 'badge_service.dart';

/// Full-screen page displaying all badges organized by category
class BadgesPage extends StatefulWidget {
  final BadgeService badgeService;
  final ScrollController? scrollController;
  final bool isBottomSheet;

  const BadgesPage({
    Key? key,
    required this.badgeService,
    this.scrollController,
    this.isBottomSheet = false,
  }) : super(key: key);

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<Map<String, dynamic>>> _badgesByCategory = {};
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  final List<BadgeCategory> _categories = [
    BadgeCategory.all,
    BadgeCategory.recording,
    BadgeCategory.export,
    BadgeCategory.streak,
    BadgeCategory.share,
    BadgeCategory.speed,
    BadgeCategory.premium,
    BadgeCategory.leaderboard,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadData();
    
    // Listen to badge service changes
    widget.badgeService.addListener(_onBadgeServiceUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.badgeService.removeListener(_onBadgeServiceUpdate);
    super.dispose();
  }

  void _onBadgeServiceUpdate() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _badgesByCategory = widget.badgeService.getBadgesByCategory();
    _stats = widget.badgeService.getStatsSummary();

    setState(() => _isLoading = false);
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

  IconData _getCategoryIcon(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.all:
        return Icons.grid_view;
      case BadgeCategory.recording:
        return Icons.videocam;
      case BadgeCategory.export:
        return Icons.file_download;
      case BadgeCategory.streak:
        return Icons.local_fire_department;
      case BadgeCategory.share:
        return Icons.share;
      case BadgeCategory.speed:
        return Icons.speed;
      case BadgeCategory.premium:
        return Icons.workspace_premium;
      case BadgeCategory.leaderboard:
        return Icons.leaderboard;
    }
  }

  List<Map<String, dynamic>> _getBadgesForCategory(BadgeCategory category) {
    if (category == BadgeCategory.all) {
      return widget.badgeService.getAllBadgesForUI();
    }

    final categoryKey = category.name;
    return _badgesByCategory[categoryKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: widget.isBottomSheet ? null : _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: widget.isBottomSheet ? null : _buildAppBar(),
      body: Column(
        children: [
          if (widget.isBottomSheet) _buildBottomSheetHeader(),
          _buildStatsCard(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                return _buildBadgeList(category);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Badges'),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.emoji_events),
          tooltip: 'View Stats',
          onPressed: () {
            // Navigate to stats page or show bottom sheet
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(child: Text('Stats Page')),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomSheetHeader() {
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
          const Text(
            'Badges',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final unlockedCount = _stats['unlockedBadges'] as int;
    final totalCount = _stats['totalBadges'] as int;
    final progress = _stats['progress'] as double;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.orange.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badge Collection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$unlockedCount of $totalCount unlocked',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% Complete',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.orange,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.orange,
        indicatorWeight: 3,
        tabs: _categories.map((category) {
          return Tab(
            icon: Icon(_getCategoryIcon(category), size: 20),
            text: _getCategoryName(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBadgeList(BadgeCategory category) {
    final badges = _getBadgesForCategory(category);

    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.stars_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No badges in this category yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badgeData = badges[index];
        return BadgeCard(
          badgeData: badgeData,
          onTap: () => _onBadgeTap(badgeData),
        );
      },
    );
  }

  void _onBadgeTap(Map<String, dynamic> badgeData) {
    // Show badge details dialog or bottom sheet
    showDialog(
      context: context,
      builder: (context) => _buildBadgeDetailsDialog(badgeData),
    );
  }

  Widget _buildBadgeDetailsDialog(Map<String, dynamic> badgeData) {
    final badge = badgeData['badge'] as Map<String, dynamic>;
    final isUnlocked = badgeData['isUnlocked'] as bool;
    final unlockDate = badgeData['unlockDate'] as String?;
    final progress = badgeData['progress'] as double;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
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
                IconData(
                  badge['icon'] as int,
                  fontFamily: 'MaterialIcons',
                ),
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
                      'Unlocked ${_formatUnlockDate(unlockDate)}',
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
    );
  }

  String _formatUnlockDate(String? dateString) {
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
