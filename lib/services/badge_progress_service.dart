import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'user_session.dart';

class BadgeProgressService {
  static const Set<String> supportedBadgeNames = {
    '起步之星',
    '超慢跑新星',
    '深蹲入門生',
    '穩穩前進',
    '節奏守護者',
    '不間斷玩家',
    '今日萬步王',
    '姿勢優等生',
    '穩定輸出王',
    '燃脂小火苗',
    '燃燒模式',
    '社群冒險家',
    '人氣回應王',
    '按讚收集者',
  };

  Future<Map<String, DateTime>> loadEarnedDates({int? memberId}) async {
    final currentMemberId = memberId ?? UserSession.memberId;
    final responses = await Future.wait([
      ApiService().dio.get('badges/'),
      ApiService().dio.get(
        'member-badges/',
        queryParameters: {'member_id': currentMemberId},
      ),
      ApiService().dio.get(
        'training-logs/',
        queryParameters: {'member': currentMemberId},
      ),
    ]);

    final badgeNamesById = <int, String>{};
    for (final badge in _extractList(responses[0].data)) {
      if (badge is! Map) {
        continue;
      }

      final id = int.tryParse('${badge['id'] ?? ''}');
      final name = badge['badge_name']?.toString();
      if (id != null && name != null && name.isNotEmpty) {
        badgeNamesById[id] = name;
      }
    }

    final earnedDates = <String, DateTime>{};
    for (final memberBadge in _extractList(responses[1].data)) {
      if (memberBadge is! Map) {
        continue;
      }

      final badgeMemberId = int.tryParse('${memberBadge['member'] ?? ''}');
      if (badgeMemberId != currentMemberId) {
        continue;
      }

      final badgeId = int.tryParse('${memberBadge['badge'] ?? ''}');
      final earnedAt = DateTime.tryParse(
        memberBadge['earn_at']?.toString() ?? '',
      );
      final badgeName = badgeNamesById[badgeId];

      if (badgeName != null && earnedAt != null) {
        earnedDates[badgeName] = earnedAt.toLocal();
      }
    }

    final trainingLogs = <_TrainingBadgeLog>[];
    for (final trainingLog in _extractList(responses[2].data)) {
      if (trainingLog is! Map) {
        continue;
      }

      final logMemberId = int.tryParse('${trainingLog['member'] ?? ''}');
      final completedAt = DateTime.tryParse(
        (trainingLog['end_time'] ?? trainingLog['start_time'])?.toString() ??
            '',
      );
      if (logMemberId != currentMemberId || completedAt == null) {
        continue;
      }

      trainingLogs.add(
        _TrainingBadgeLog(
          exerciseType: trainingLog['exercise_type']?.toString() ?? '',
          completedAt: completedAt.toLocal(),
          stepCount: int.tryParse('${trainingLog['step_count'] ?? ''}') ?? 0,
          postureScore:
              int.tryParse('${trainingLog['posture_score'] ?? ''}') ?? 0,
          calories: int.tryParse('${trainingLog['calories'] ?? ''}') ?? 0,
        ),
      );
    }

    trainingLogs.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    if (trainingLogs.isNotEmpty) {
      earnedDates.putIfAbsent(
        '起步之星',
        () => trainingLogs.first.completedAt,
      );
    }

    final slowJoggingLogs = trainingLogs
        .where((trainingLog) => trainingLog.exerciseType == 'slow_jogging')
        .toList();
    if (slowJoggingLogs.length >= 5) {
      earnedDates.putIfAbsent(
        '超慢跑新星',
        () => slowJoggingLogs[4].completedAt,
      );
    }

    final squatLogs = trainingLogs
        .where((trainingLog) => trainingLog.exerciseType == 'squat')
        .toList();
    if (squatLogs.length >= 5) {
      earnedDates.putIfAbsent(
        '深蹲入門生',
        () => squatLogs[4].completedAt,
      );
    }

    for (final trainingLog in trainingLogs) {
      if (trainingLog.postureScore >= 90) {
        earnedDates.putIfAbsent('姿勢優等生', () => trainingLog.completedAt);
        break;
      }
    }

    var consecutiveHighPostureScores = 0;
    for (final trainingLog in trainingLogs) {
      consecutiveHighPostureScores =
          trainingLog.postureScore > 90 ? consecutiveHighPostureScores + 1 : 0;
      if (consecutiveHighPostureScores >= 5) {
        earnedDates.putIfAbsent('穩定輸出王', () => trainingLog.completedAt);
        break;
      }
    }

    var totalCalories = 0;
    for (final trainingLog in trainingLogs) {
      totalCalories += trainingLog.calories;
      if (totalCalories >= 500) {
        earnedDates.putIfAbsent('燃脂小火苗', () => trainingLog.completedAt);
      }
      if (totalCalories >= 3000) {
        earnedDates.putIfAbsent('燃燒模式', () => trainingLog.completedAt);
        break;
      }
    }

    final dailyStepTotals = <String, int>{};
    for (final trainingLog in trainingLogs) {
      final date = trainingLog.completedAt;
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final totalSteps =
          (dailyStepTotals[dateKey] ?? 0) + trainingLog.stepCount;
      dailyStepTotals[dateKey] = totalSteps;

      if (totalSteps >= 10000) {
        earnedDates.putIfAbsent('今日萬步王', () => trainingLog.completedAt);
        break;
      }
    }

    DateTime? previousWorkoutDay;
    String? previousWorkoutDateKey;
    var consecutiveWorkoutDays = 0;
    for (final trainingLog in trainingLogs) {
      final date = trainingLog.completedAt;
      final dateKey = '${date.year}-${date.month}-${date.day}';
      if (dateKey == previousWorkoutDateKey) {
        continue;
      }

      final workoutDay = DateTime.utc(date.year, date.month, date.day);
      consecutiveWorkoutDays = previousWorkoutDay != null &&
              workoutDay.difference(previousWorkoutDay).inDays == 1
          ? consecutiveWorkoutDays + 1
          : 1;
      previousWorkoutDay = workoutDay;
      previousWorkoutDateKey = dateKey;

      if (consecutiveWorkoutDays >= 3) {
        earnedDates.putIfAbsent('穩穩前進', () => trainingLog.completedAt);
      }
      if (consecutiveWorkoutDays >= 7) {
        earnedDates.putIfAbsent('節奏守護者', () => trainingLog.completedAt);
      }
      if (consecutiveWorkoutDays >= 30) {
        earnedDates.putIfAbsent('不間斷玩家', () => trainingLog.completedAt);
        break;
      }
    }

    await _addCommunityBadgeDates(
      earnedDates: earnedDates,
      memberId: currentMemberId,
    );
    earnedDates.removeWhere(
      (badgeName, _) => !supportedBadgeNames.contains(badgeName),
    );
    return earnedDates;
  }

  Future<void> _addCommunityBadgeDates({
    required Map<String, DateTime> earnedDates,
    required int memberId,
  }) async {
    try {
      final postsResponse = await ApiService().dio.get(
        'community-posts/',
        queryParameters: {'member_id': memberId},
      );
      DateTime? firstPostAt;
      final popularPostIds = <int>[];
      final ownedPostIds = <int>{};
      var totalLikeCount = 0;

      for (final post in _extractList(postsResponse.data)) {
        if (post is! Map) {
          continue;
        }

        final postMemberId = int.tryParse('${post['member_id'] ?? ''}');
        final createdAt = DateTime.tryParse(
          post['created_at']?.toString() ?? '',
        );
        if (postMemberId != memberId || createdAt == null) {
          continue;
        }

        final localCreatedAt = createdAt.toLocal();
        if (firstPostAt == null || localCreatedAt.isBefore(firstPostAt)) {
          firstPostAt = localCreatedAt;
        }

        final postId = int.tryParse('${post['id'] ?? ''}');
        final likeCount = int.tryParse('${post['like_count'] ?? ''}') ?? 0;
        final commentCount =
            int.tryParse('${post['comment_count'] ?? ''}') ?? 0;
        if (postId != null) {
          ownedPostIds.add(postId);
          totalLikeCount += likeCount;
          if (commentCount >= 20) {
            popularPostIds.add(postId);
          }
        }
      }

      if (firstPostAt != null) {
        earnedDates.putIfAbsent('社群冒險家', () => firstPostAt!);
      }

      DateTime? popularResponderAt;
      for (final postId in popularPostIds) {
        try {
          final commentsResponse = await ApiService().dio.get(
                'community-posts/$postId/comments/',
              );
          final comments = _extractList(commentsResponse.data);
          if (comments.length < 20 || comments[19] is! Map) {
            continue;
          }

          final twentiethComment = comments[19] as Map;
          final earnedAt = DateTime.tryParse(
            twentiethComment['created_at']?.toString() ?? '',
          )?.toLocal();
          if (earnedAt != null &&
              (popularResponderAt == null ||
                  earnedAt.isBefore(popularResponderAt))) {
            popularResponderAt = earnedAt;
          }
        } catch (error) {
          debugPrint('載入貼文回應資料失敗: $error');
        }
      }

      if (popularResponderAt != null) {
        earnedDates.putIfAbsent('人氣回應王', () => popularResponderAt!);
      }

      if (totalLikeCount >= 100) {
        try {
          final likesResponse = await ApiService().dio.get('post-likes/');
          final likeDates = <DateTime>[];
          for (final like in _extractList(likesResponse.data)) {
            if (like is! Map) {
              continue;
            }

            final postId = int.tryParse('${like['post'] ?? ''}');
            final createdAt = DateTime.tryParse(
              like['created_at']?.toString() ?? '',
            );
            if (postId != null &&
                ownedPostIds.contains(postId) &&
                createdAt != null) {
              likeDates.add(createdAt.toLocal());
            }
          }

          likeDates.sort();
          if (likeDates.length >= 100) {
            earnedDates.putIfAbsent('按讚收集者', () => likeDates[99]);
          }
        } catch (error) {
          debugPrint('載入貼文按讚資料失敗: $error');
        }
      }
    } catch (error) {
      debugPrint('載入社群勳章資料失敗: $error');
    }
  }

  List<dynamic> _extractList(dynamic payload) {
    if (payload is List) {
      return payload;
    }
    if (payload is Map && payload['results'] is List) {
      return payload['results'] as List;
    }
    return const [];
  }
}

class _TrainingBadgeLog {
  final String exerciseType;
  final DateTime completedAt;
  final int stepCount;
  final int postureScore;
  final int calories;

  const _TrainingBadgeLog({
    required this.exerciseType,
    required this.completedAt,
    required this.stepCount,
    required this.postureScore,
    required this.calories,
  });
}
