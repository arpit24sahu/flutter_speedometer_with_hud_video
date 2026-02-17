import 'package:flutter/material.dart';

/// Individual badge card widget
class BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badgeData;
  final VoidCallback? onTap;
  final bool compact;

  const BadgeCard({
    Key? key,
    required this.badgeData,
    this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final badge = badgeData['badge'] as Map<String, dynamic>;
    final isUnlocked = badgeData['isUnlocked'] as bool;
    final progress = badgeData['progress'] as double;
    final unlockDate = badgeData['unlockDate'] as String?;

    if (compact) {
      return _buildCompactCard(badge, isUnlocked, progress);
    }

    return _buildFullCard(badge, isUnlocked, progress, unlockDate);
  }

  Widget _buildFullCard(
    Map<String, dynamic> badge,
    bool isUnlocked,
    double progress,
    String? unlockDate,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Badge icon
              Container(
                width: 60,
                height: 60,
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
                  size: 30,
                  color: isUnlocked
                      ? Color(badge['color'] as int)
                      : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 16),
              
              // Badge info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            badge['name'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? Colors.black : Colors.grey[600],
                            ),
                          ),
                        ),
                        if (isUnlocked)
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[600],
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge['description'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Progress indicator
                    if (!isUnlocked) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(badge['color'] as int),
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toInt()}% complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Unlocked ${_formatUnlockDate(unlockDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Tier indicator
              const SizedBox(width: 8),
              _buildTierBadge(badge['tier'] as int),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(
    Map<String, dynamic> badge,
    bool isUnlocked,
    double progress,
  ) {
    return Card(
      margin: const EdgeInsets.all(4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Color(badge['color'] as int).withOpacity(0.2)
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      IconData(
                        badge['icon'] as int,
                        fontFamily: 'MaterialIcons',
                      ),
                      size: 24,
                      color: isUnlocked
                          ? Color(badge['color'] as int)
                          : Colors.grey[400],
                    ),
                    if (isUnlocked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge['name'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? Colors.black : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isUnlocked) ...[
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge(int tier) {
    final tierColors = {
      1: Colors.green,
      2: Colors.blue,
      3: Colors.purple,
      4: Colors.orange,
      5: Colors.red,
    };

    final tierNames = {
      1: 'Bronze',
      2: 'Silver',
      3: 'Gold',
      4: 'Platinum',
      5: 'Diamond',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tierColors[tier]?.withOpacity(0.1) ?? Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tierColors[tier]?.withOpacity(0.3) ?? Colors.grey,
          width: 1,
        ),
      ),
      child: Text(
        tierNames[tier] ?? 'T$tier',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: tierColors[tier] ?? Colors.grey[600],
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
