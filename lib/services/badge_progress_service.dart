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

  // 自動將未儲存的新解鎖徽章存入後端，並回傳新解鎖的徽章名稱清單
  Future<List<String>> syncNewlyEarnedBadges({
    int? memberId,
    String? currentExerciseType,
  }) async {
    final currentMemberId = memberId ?? UserSession.memberId;
    if (currentMemberId == null) {
      debugPrint('🔍 [BadgeDebug] currentMemberId 為空，直接返回');
      return [];
    }

    final List<String> newlyUnlockedBadges = [];

    try {
      // 1. 取得所有徽章定義 (名稱 -> ID 對照表)
      final badgesResponse = await ApiService().dio.get('badges/');
      debugPrint('🔍 [BadgeDebug] badges/ 原始回傳資料: ${badgesResponse.data}');
      final badgeIdByName = <String, int>{};
      for (final item in _extractList(badgesResponse.data)) {
        if (item is Map) {
          final id = int.tryParse('${item['id'] ?? ''}');
          final name = item['badge_name']?.toString();
          if (id != null && name != null && name.isNotEmpty) {
            badgeIdByName[name] = id;
          }
        }
      }
      debugPrint('🔍 [BadgeDebug] 後端資料庫現有徽章清單: $badgeIdByName');

      // 2. 取得資料庫裡使用者已擁有的徽章 ID
      final existingResponse = await ApiService().dio.get(
        'member-badges/',
        queryParameters: {'member_id': currentMemberId},
      );
      final ownedBadgeIds = <int>{};
      for (final item in _extractList(existingResponse.data)) {
        if (item is Map) {
          final badgeId = int.tryParse('${item['badge'] ?? ''}');
          if (badgeId != null) {
            ownedBadgeIds.add(badgeId);
          }
        }
      }
      debugPrint('🔍 [BadgeDebug] 該會員已擁有的徽章 ID: $ownedBadgeIds');

      // 3. 計算所有已達標徽章
      final earnedMap = await loadEarnedDates(
        memberId: currentMemberId,
        currentExerciseType: currentExerciseType,
      );
      debugPrint('🔍 [BadgeDebug] 前端計算出已達標徽章: ${earnedMap.keys.toList()}');

      // 4. 比對並存入資料庫
      for (final badgeName in earnedMap.keys) {
        final badgeId = badgeIdByName[badgeName];
        debugPrint(
            '🔍 [BadgeDebug] 比對徽章 "$badgeName" -> 後端ID: $badgeId, 是否已擁有: ${ownedBadgeIds.contains(badgeId)}');

        if (badgeId != null && !ownedBadgeIds.contains(badgeId)) {
          try {
            await ApiService().dio.post(
              'member-badges/',
              data: {
                'member': currentMemberId,
                'badge': badgeId,
              },
            );
            debugPrint('🎖️ 成功同步新徽章至後端：$badgeName (ID: $badgeId)');
          } catch (postError) {
            debugPrint('⚠️ 新增徽章失敗: $postError');
          }
          newlyUnlockedBadges.add(badgeName);
        }
      }
    } catch (e) {
      debugPrint('⚠️ 同步徽章至後端時發生錯誤: $e');
    }

    debugPrint('🔍 [BadgeDebug] 最終判定新解鎖清單: $newlyUnlockedBadges');
    return newlyUnlockedBadges;
  }

  Future<Map<String, DateTime>> loadEarnedDates({
    int? memberId,
    String? currentExerciseType,
  }) async {
    final currentMemberId = memberId ?? UserSession.memberId;
    if (currentMemberId == null) return {};

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

    // 1. 解析所有徽章定義
    final badgeNamesById = <int, String>{};
    for (final badge in _extractList(responses[0].data)) {
      if (badge is! Map) continue;
      final id = int.tryParse('${badge['id'] ?? ''}');
      final name = badge['badge_name']?.toString();
      if (id != null && name != null && name.isNotEmpty) {
        badgeNamesById[id] = name;
      }
    }

    final earnedDates = <String, DateTime>{};

    // 2. 解析後端回傳的 training-logs（包含容錯與欄位別名）
    final rawLogs = _extractList(responses[2].data);
    debugPrint('🔍 [BadgeDebug] 後端回傳 training-logs 原始筆數: ${rawLogs.length}');

    final trainingLogs = <_TrainingBadgeLog>[];
    for (final log in rawLogs) {
      if (log is! Map) continue;

      // 寬鬆比對 memberId（避免 int vs String 失敗）
      final logMemberStr = '${log['member'] ?? log['member_id'] ?? ''}';
      if (logMemberStr.isNotEmpty && logMemberStr != '$currentMemberId') {
        continue;
      }

      // 抓取結束時間或建立時間
      final rawTime = log['end_time'] ?? log['created_at'] ?? log['start_time'];
      final completedAt = DateTime.tryParse(rawTime?.toString() ?? '');

      if (completedAt == null) {
        debugPrint('⚠️ [BadgeDebug] 這筆 log 解析不到時間: $log');
        continue;
      }

      trainingLogs.add(
        _TrainingBadgeLog(
          exerciseType: log['exercise_type']?.toString() ?? '',
          completedAt: completedAt.toLocal(),
          stepCount: int.tryParse('${log['step_count'] ?? ''}') ?? 0,
          postureScore: int.tryParse('${log['posture_score'] ?? ''}') ?? 0,
          calories: int.tryParse('${log['calories'] ?? ''}') ?? 0,
        ),
      );
    }

    debugPrint('🔍 [BadgeDebug] 成功解析出屬於當前使用者的有效紀錄筆數: ${trainingLogs.length}');

    trainingLogs.sort((a, b) => a.completedAt.compareTo(b.completedAt));

    // ----------------- 判定邏輯 -----------------

    // 1. 只要有任何一筆運動紀錄，就達成「起步之星」
    if (trainingLogs.isNotEmpty) {
      earnedDates.putIfAbsent(
        '起步之星',
        () => trainingLogs.first.completedAt,
      );
    }

    // 2. 超慢跑累積次數達標
    final slowJoggingLogs = trainingLogs
        .where((log) => log.exerciseType == 'slow_jogging')
        .toList();
    if (slowJoggingLogs.length >= 5) {
      if (currentExerciseType == null ||
          currentExerciseType == 'slow_jogging') {
        earnedDates.putIfAbsent(
          '超慢跑新星',
          () => slowJoggingLogs.last.completedAt,
        );
      }
    }

    // 3. 深蹲累積次數達標
    final squatLogs =
        trainingLogs.where((log) => log.exerciseType == 'squat').toList();
    if (squatLogs.length >= 5) {
      if (currentExerciseType == null || currentExerciseType == 'squat') {
        earnedDates.putIfAbsent(
          '深蹲入門生',
          () => squatLogs.last.completedAt,
        );
      }
    }

    // 4. 姿勢分數達標
    if (trainingLogs.isNotEmpty && trainingLogs.last.postureScore >= 80) {
      earnedDates.putIfAbsent('姿勢優等生', () => trainingLogs.last.completedAt);
    }

    // 5. 穩定輸出王：連續 5 次姿勢分數 > 90
    var consecutiveHighPostureScores = 0;
    for (final trainingLog in trainingLogs) {
      consecutiveHighPostureScores =
          trainingLog.postureScore > 90 ? consecutiveHighPostureScores + 1 : 0;
      if (consecutiveHighPostureScores >= 5) {
        earnedDates.putIfAbsent('穩定輸出王', () => trainingLog.completedAt);
        break;
      }
    }

    // 6. 熱量徽章
    var totalCalories = 0;
    for (final log in trainingLogs) {
      totalCalories += log.calories;
      if (totalCalories >= 500) {
        earnedDates.putIfAbsent('燃脂小火苗', () => log.completedAt);
      }
      if (totalCalories >= 3000) {
        earnedDates.putIfAbsent('燃燒模式', () => log.completedAt);
        break;
      }
    }

    // 7. 今日萬步王
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

    // 8. 連續運動天數徽章
    DateTime? previousWorkoutDay;
    String? previousWorkoutDateKey;
    var consecutiveWorkoutDays = 0;
    for (final trainingLog in trainingLogs) {
      final date = trainingLog.completedAt;
      final dateKey = '${date.year}-${date.month}-${date.day}';
      if (dateKey == previousWorkoutDateKey) continue;

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

    // 9. 社群相關徽章
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

      final rawPosts = _extractList(postsResponse.data);
      debugPrint('🔍 [BadgeDebug] 社群貼文原始筆數: ${rawPosts.length}');

      for (final post in rawPosts) {
        if (post is! Map) continue;

        // 寬鬆比對發文者 ID（相容 member, member_id, author 等欄位）
        final postMemberStr =
            '${post['member_id'] ?? post['member'] ?? post['author'] ?? ''}';
        if (postMemberStr.isNotEmpty && postMemberStr != '$memberId') {
          continue;
        }

        final createdAt = DateTime.tryParse(
          post['created_at']?.toString() ?? '',
        );
        if (createdAt == null) continue;

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

      // 👉 只要有發過至少 1 篇貼文，就解鎖「社群冒險家」！
      if (firstPostAt != null) {
        earnedDates.putIfAbsent('社群冒險家', () => firstPostAt!);
        debugPrint('🎖️ [BadgeDebug] 達成社群冒險家！');
      }

      // 檢查人氣回應王與按讚收集者
      if (popularPostIds.isNotEmpty) {
        // ... (保持原樣或後續擴充)
      }
      if (totalLikeCount >= 100) {
        // ... (保持原樣)
      }
    } catch (error) {
      debugPrint('⚠️ 載入社群勳章資料失敗: $error');
    }
  }

  List<dynamic> _extractList(dynamic payload) {
    if (payload is List) return payload;
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
