import 'package:flutter/material.dart';
import 'badge_card.dart';

/// Widget for displaying a category section of badges
class BadgeCategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> badges;
  final Function(Map<String, dynamic>)? onBadgeTap;
  final bool showViewAll;
  final VoidCallback? onViewAll;
  final bool useGrid;

  const BadgeCategorySection({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.badges,
    this.onBadgeTap,
    this.showViewAll = false,
    this.onViewAll,
    this.useGrid = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        useGrid ? _buildGridView() : _buildListView(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final unlockedCount = badges.where((b) => b['isUnlocked'] as bool).length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$unlockedCount of ${badges.length} unlocked',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (showViewAll && onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return BadgeCard(
          badgeData: badges[index],
          onTap: onBadgeTap != null ? () => onBadgeTap!(badges[index]) : null,
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return BadgeCard(
          badgeData: badges[index],
          onTap: onBadgeTap != null ? () => onBadgeTap!(badges[index]) : null,
          compact: true,
        );
      },
    );
  }
}
