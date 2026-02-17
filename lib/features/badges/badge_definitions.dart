import 'package:flutter/material.dart';
import 'badge_id.dart';
import 'badge_model.dart';

class BadgeDefinitions {
  static final List<AppBadge> allBadges = [
    // Recording badges (sorted by attainability)
    AppBadge(
      id: BadgeId.firstVideo,
      name: 'First Ride',
      description: 'Record your first video',
      icon: Icons.videocam,
      color: Colors.green,
      tier: 1,
      level: 1,
      attainabilityScore: 1,
    ),
    AppBadge(
      id: BadgeId.record20Videos,
      name: 'Video Enthusiast',
      description: 'Record 20 videos',
      icon: Icons.video_library,
      color: Colors.blue,
      tier: 2,
      level: 2,
      attainabilityScore: 20,
    ),
    AppBadge(
      id: BadgeId.record50Videos,
      name: 'Video Master',
      description: 'Record 50 videos',
      icon: Icons.movie_creation,
      color: Colors.purple,
      tier: 3,
      level: 3,
      attainabilityScore: 50,
    ),

    // Export badges
    AppBadge(
      id: BadgeId.export1Video,
      name: 'First Export',
      description: 'Export your first video',
      icon: Icons.file_download,
      color: Colors.teal,
      tier: 1,
      level: 1,
      attainabilityScore: 2,
    ),
    AppBadge(
      id: BadgeId.export20Videos,
      name: 'Export Pro',
      description: 'Export 20 videos',
      icon: Icons.cloud_download,
      color: Colors.indigo,
      tier: 2,
      level: 2,
      attainabilityScore: 21,
    ),
    AppBadge(
      id: BadgeId.export50Videos,
      name: 'Export Legend',
      description: 'Export 50 videos',
      icon: Icons.download_done,
      color: Colors.deepPurple,
      tier: 3,
      level: 3,
      attainabilityScore: 51,
    ),

    // Streak badges
    AppBadge(
      id: BadgeId.streak3Days,
      name: 'Consistent',
      description: 'Record videos 3 days in a row',
      icon: Icons.local_fire_department,
      color: Colors.orange,
      tier: 1,
      level: 1,
      attainabilityScore: 3,
    ),
    AppBadge(
      id: BadgeId.streak10Days,
      name: 'Dedicated',
      description: 'Record videos 10 days in a row',
      icon: Icons.whatshot,
      color: Colors.deepOrange,
      tier: 2,
      level: 2,
      attainabilityScore: 10,
    ),
    AppBadge(
      id: BadgeId.streak25Days,
      name: 'Unstoppable',
      description: 'Record videos 25 days in a row',
      icon: Icons.local_fire_department_rounded,
      color: Colors.red,
      tier: 3,
      level: 3,
      attainabilityScore: 25,
    ),

    // Share badges
    AppBadge(
      id: BadgeId.share1Video,
      name: 'Social Starter',
      description: 'Share your first video',
      icon: Icons.share,
      color: Colors.cyan,
      tier: 1,
      level: 1,
      attainabilityScore: 4,
    ),
    AppBadge(
      id: BadgeId.share10Videos,
      name: 'Influencer',
      description: 'Share 10 videos',
      icon: Icons.ios_share,
      color: Colors.lightBlue,
      tier: 2,
      level: 2,
      attainabilityScore: 11,
    ),
    AppBadge(
      id: BadgeId.share25Videos,
      name: 'Content Creator',
      description: 'Share 25 videos',
      icon: Icons.send,
      color: Colors.blue,
      tier: 3,
      level: 3,
      attainabilityScore: 26,
    ),

    // Speed badges (sorted by speed)
    AppBadge(
      id: BadgeId.speed50Kmph,
      name: 'Speed Rookie',
      description: 'Hit 50 km/h',
      icon: Icons.speed,
      color: Colors.lightGreen,
      tier: 1,
      level: 1,
      attainabilityScore: 5,
    ),
    AppBadge(
      id: BadgeId.speed80Kmph,
      name: 'Cruiser',
      description: 'Hit 80 km/h',
      icon: Icons.directions_car,
      color: Colors.green,
      tier: 1,
      level: 2,
      attainabilityScore: 6,
    ),
    AppBadge(
      id: BadgeId.speed100Kmph,
      name: 'Century',
      description: 'Hit 100 km/h',
      icon: Icons.speed,
      color: Colors.lime,
      tier: 2,
      level: 1,
      attainabilityScore: 7,
    ),
    AppBadge(
      id: BadgeId.speed120Kmph,
      name: 'Fast & Furious',
      description: 'Hit 120 km/h',
      icon: Icons.fast_forward,
      color: Colors.yellow,
      tier: 2,
      level: 2,
      attainabilityScore: 8,
    ),
    AppBadge(
      id: BadgeId.speed150Kmph,
      name: 'Speed Demon',
      description: 'Hit 150 km/h',
      icon: Icons.flash_on,
      color: Colors.amber,
      tier: 2,
      level: 3,
      attainabilityScore: 9,
    ),
    AppBadge(
      id: BadgeId.speed200Kmph,
      name: 'Adrenaline Junkie',
      description: 'Hit 200 km/h',
      icon: Icons.bolt,
      color: Colors.orange,
      tier: 3,
      level: 1,
      attainabilityScore: 52,
    ),
    AppBadge(
      id: BadgeId.speed250Kmph,
      name: 'Supersonic',
      description: 'Hit 250 km/h',
      icon: Icons.rocket_launch,
      color: Colors.deepOrange,
      tier: 3,
      level: 2,
      attainabilityScore: 53,
    ),
    AppBadge(
      id: BadgeId.speed500Kmph,
      name: 'Jet Speed',
      description: 'Hit 500 km/h',
      icon: Icons.flight,
      color: Colors.red,
      tier: 4,
      level: 1,
      attainabilityScore: 100,
    ),
    AppBadge(
      id: BadgeId.speed800Kmph,
      name: 'Hypersonic',
      description: 'Hit 800 km/h',
      icon: Icons.rocket,
      color: Colors.pink,
      tier: 4,
      level: 2,
      attainabilityScore: 200,
    ),
    AppBadge(
      id: BadgeId.speed1000Kmph,
      name: 'Breaking Sound',
      description: 'Hit 1000 km/h',
      icon: Icons.airplanemode_active,
      color: Colors.purple,
      tier: 5,
      level: 1,
      attainabilityScore: 500,
    ),

    // Premium badge
    AppBadge(
      id: BadgeId.purchasePremium,
      name: 'Premium Member',
      description: 'Purchased premium subscription',
      icon: Icons.workspace_premium,
      color: Colors.amber,
      tier: 1,
      level: 1,
      attainabilityScore: 12,
    ),

    // Future leaderboard badges (placeholders)
    AppBadge(
      id: BadgeId.dailyLeaderboard1Time,
      name: 'On the Board',
      description: 'Appear on daily leaderboard once',
      icon: Icons.leaderboard,
      color: Colors.blueGrey,
      tier: 2,
      level: 1,
      attainabilityScore: 30,
    ),
    AppBadge(
      id: BadgeId.dailyLeaderboard10Times,
      name: 'Regular Contender',
      description: 'Appear on daily leaderboard 10 times',
      icon: Icons.emoji_events,
      color: Colors.brown,
      tier: 3,
      level: 1,
      attainabilityScore: 54,
    ),
    AppBadge(
      id: BadgeId.dailyLeaderboard1TimeFirst,
      name: 'Champion',
      description: 'Rank 1st on daily leaderboard once',
      icon: Icons.military_tech,
      color: Colors.yellow.shade700,
      tier: 3,
      level: 2,
      attainabilityScore: 55,
    ),
    AppBadge(
      id: BadgeId.dailyLeaderboard10TimesFirst,
      name: 'Legend',
      description: 'Rank 1st on daily leaderboard 10 times',
      icon: Icons.stars,
      color: Colors.amber.shade800,
      tier: 4,
      level: 1,
      attainabilityScore: 56,
    ),
  ];

  /// Returns badges sorted by attainability (easiest first)
  static List<AppBadge> get sortedBadges {
    final badges = List<AppBadge>.from(allBadges);
    badges.sort((a, b) => a.attainabilityScore.compareTo(b.attainabilityScore));
    return badges;
  }

  /// Get a badge by its ID
  static AppBadge? getBadgeById(BadgeId id) {
    try {
      return allBadges.firstWhere((badge) => badge.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get all badges for a specific tier
  static List<AppBadge> getBadgesByTier(int tier) {
    return allBadges.where((badge) => badge.tier == tier).toList();
  }

  /// Get all badges of a specific category
  static List<AppBadge> getRecordingBadges() {
    return [
      BadgeId.firstVideo,
      BadgeId.record20Videos,
      BadgeId.record50Videos,
    ].map((id) => getBadgeById(id)!).toList();
  }

  static List<AppBadge> getExportBadges() {
    return [
      BadgeId.export1Video,
      BadgeId.export20Videos,
      BadgeId.export50Videos,
    ].map((id) => getBadgeById(id)!).toList();
  }

  static List<AppBadge> getStreakBadges() {
    return [
      BadgeId.streak3Days,
      BadgeId.streak10Days,
      BadgeId.streak25Days,
    ].map((id) => getBadgeById(id)!).toList();
  }

  static List<AppBadge> getShareBadges() {
    return [
      BadgeId.share1Video,
      BadgeId.share10Videos,
      BadgeId.share25Videos,
    ].map((id) => getBadgeById(id)!).toList();
  }

  static List<AppBadge> getSpeedBadges() {
    return [
      BadgeId.speed50Kmph,
      BadgeId.speed80Kmph,
      BadgeId.speed100Kmph,
      BadgeId.speed120Kmph,
      BadgeId.speed150Kmph,
      BadgeId.speed200Kmph,
      BadgeId.speed250Kmph,
      BadgeId.speed500Kmph,
      BadgeId.speed800Kmph,
      BadgeId.speed1000Kmph,
    ].map((id) => getBadgeById(id)!).toList();
  }

  static List<AppBadge> getLeaderboardBadges() {
    return [
      BadgeId.dailyLeaderboard1Time,
      BadgeId.dailyLeaderboard10Times,
      BadgeId.dailyLeaderboard1TimeFirst,
      BadgeId.dailyLeaderboard10TimesFirst,
    ].map((id) => getBadgeById(id)!).toList();
  }
}
