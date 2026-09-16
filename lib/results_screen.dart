import 'dart:convert';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'body_pain_picker.dart';
import 'config/api_config.dart';
import 'services/user_session.dart';
import 'services/badge_progress_service.dart';

class ResultsScreen extends StatefulWidget {
  final int timeSeconds;
  final double averageAccuracy;
  final int stepCount;
  final List<String> finalFeedback;
  final String exerciseTitle;

  const ResultsScreen({
    super.key,
    required this.timeSeconds,
    required this.averageAccuracy,
    required this.stepCount,
    required this.finalFeedback,
    this.exerciseTitle = '超慢跑',
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late ConfettiController _confettiController;
  String? _dynamicAiFeedback;
  bool _isLoadingAi = true;

  // 記錄使用者填寫的疼痛部位
  Set<BodyPart> _recordedPainParts = {};

  @override
  void initState() {
    super.initState();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

    _fetchAiFeedback(); // 獲取 AI 建議

    // 畫面載入完成後：先存檔、檢查徽章並優先頒獎，最後再跳疼痛回饋
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleInitialFlow();
      }
    });
  }

  // 循序流程：先檢查頒獎 -> 關閉後接著跳疼痛回報
  Future<void> _handleInitialFlow() async {
    // 1. 先送出基礎運動數據
    await _saveData();

    // 2. 檢查是否有新解鎖的徽章
    List<String> newBadges = [];
    try {
      newBadges = await BadgeProgressService().syncNewlyEarnedBadges();
      debugPrint('🎖️ 本次訓練解鎖徽章: $newBadges');
    } catch (e) {
      debugPrint('⚠️ 徽章檢查失敗: $e');
    }

    if (!mounted) return;

    if (newBadges.isNotEmpty) {
      // 👉 優先跳出頒獎彈窗！使用者點擊收下後，再跳疼痛回報
      await _showBadgeUnlockedDialog(newBadges);
    }

    // 3. 頒獎結束（或無新徽章）後，彈出疼痛回饋
    if (mounted) {
      _showDiscomfortModal(context);
    }
  }

  // 🎖️ 頒發新解鎖徽章的慶祝彈窗（回傳 Future 支援 await 等待關閉）
  Future<void> _showBadgeUnlockedDialog(List<String> badgeNames) async {
    if (!mounted || badgeNames.isEmpty) return;

    // 再次噴射慶祝彩帶
    _confettiController.play();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 獎牌圖示
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    size: 64,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '恭喜獲得新徽章！',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '你在本次訓練中達成了以下成就：',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // 列出所有剛解鎖的徽章名稱
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: badgeNames.map((badgeName) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            badgeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('太棒了！收下獎勵',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 疼痛回饋彈窗方法
  void _showDiscomfortModal(BuildContext context) {
    Set<BodyPart> tempSelected = Set.from(_recordedPainParts);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '跑步後有哪裡不適嗎？',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '點擊圖中感到痠痛或需要注意的部位',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // 火柴人元件
                    BodyPainPicker(
                      onSelectionChanged: (parts) {
                        setModalState(() {
                          tempSelected = parts;
                        });
                      },
                    ),

                    const SizedBox(height: 12),
                    Text(
                      tempSelected.isEmpty
                          ? '尚未選取部位（無不適請直接完成）'
                          : '已選部位：${tempSelected.map((e) => e.label).join('、')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: tempSelected.isEmpty
                            ? Colors.grey
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _recordedPainParts = tempSelected;
                        });

                        List<String> partLabels =
                            tempSelected.map((p) => p.label).toList();
                        debugPrint('送出部位中文名稱: $partLabels');
                        // 填寫完畢後更新後端紀錄
                        _saveData();
                      },
                      child: const Text('完成回饋', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 結算頁面中供使用者手動開啟修改的卡片按鈕
  Widget _buildPainStatusCard() {
    final hasPain = _recordedPainParts.isNotEmpty;

    return InkWell(
      onTap: () => _showDiscomfortModal(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasPain ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPain ? Colors.redAccent.shade100 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              hasPain
                  ? Icons.warning_amber_rounded
                  : Icons.accessibility_new_rounded,
              color: hasPain ? Colors.redAccent : Colors.black87,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPain ? '身體不適回報（點擊修改）' : '身體狀態良好（點擊記錄不適）',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasPain ? Colors.redAccent : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPain
                        ? _recordedPainParts.map((e) => e.label).join('、')
                        : '無回報痠痛部位',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _saveData() async {
    final String baseUrl = ApiConfig.baseUrl;
    final String url = baseUrl.endsWith('/')
        ? '${baseUrl}training-logs/'
        : '$baseUrl/training-logs/';

    final bool isSquat = widget.exerciseTitle == '深蹲';
    final int totalMins = widget.timeSeconds ~/ 60;
    final int fixedCalories = caloriesBurned;
    final int fixedSteps = isSquat ? 0 : widget.stepCount;

    final List<String> painList =
        _recordedPainParts.map((e) => e.label).toList();

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "member": UserSession.memberId,
          "exercise_type": isSquat ? "squat" : "slow_jogging",
          "start_time": DateTime.now()
              .subtract(Duration(seconds: widget.timeSeconds))
              .toIso8601String(),
          "end_time": DateTime.now().toIso8601String(),
          "total_mins": totalMins,
          "posture_score": widget.averageAccuracy.toInt(),
          "calories": fixedCalories,
          "step_count": fixedSteps,
          "pain_parts": painList,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ 運動紀錄成功同步至後端 (Status: ${response.statusCode})");
      } else {
        debugPrint("⚠️ 儲存失敗: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("⚠️ 連線異常: $e");
    }
  }

  Future<void> _fetchAiFeedback() async {
    String feedback = "";
    if (widget.exerciseTitle == '深蹲') {
      if (widget.averageAccuracy >= 80) {
        feedback = "深蹲姿勢非常標準！核心有收緊，膝蓋與腳尖方向一致，重心掌握得很好。請繼續保持這個好習慣，這對鍛鍊臀腿肌肉非常有幫助！";
      } else if (widget.averageAccuracy >= 60) {
        feedback = "做得不錯，但還有進步空間。注意深蹲時重心要放在腳跟，背部保持挺直，不要過度前傾。下蹲時感受臀部向後坐的感覺。";
      } else {
        feedback = "深蹲姿勢需要再調整喔。請注意：下蹲時臀部往後坐，膝蓋不要內夾，保持呼吸節奏。建議對著鏡子慢慢練習，感受肌肉發力。";
      }
    } else {
      if (widget.averageAccuracy >= 80) {
        feedback = "超慢跑節奏掌握得很完美！步伐輕盈，落地姿勢正確。繼續保持這樣的步頻與姿勢，能有效燃燒脂肪並保護膝蓋！";
      } else if (widget.averageAccuracy >= 60) {
        feedback = "表現不錯，但要注意落地時盡量使用前腳掌或全腳掌，避免腳跟重落地，以減少膝蓋負擔。保持身體微微前傾會更輕鬆喔。";
      } else {
        feedback = "超慢跑姿勢需要微調。請保持身體微微前傾，步伐縮小，提高步頻，並注意手臂自然擺動。不要急，跟著自己的節奏慢慢來。";
      }
    }

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _dynamicAiFeedback = feedback;
        _isLoadingAi = false;
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  int get caloriesBurned {
    double minutes = widget.timeSeconds / 60.0;
    return (minutes * 8.0).round();
  }

  @override
  Widget build(BuildContext context) {
    final String minutesStr =
        (widget.timeSeconds ~/ 60).toString().padLeft(2, '0');
    final String secondsStr =
        (widget.timeSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1F5),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('運動完成！',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('恭喜你完成了這段時間的${widget.exerciseTitle}',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 40),

                  // 數據網格
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '運動時間',
                          '$minutesStr:$secondsStr',
                          Icons.timer_outlined,
                          Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          '消耗熱量',
                          '$caloriesBurned kcal',
                          Icons.local_fire_department_outlined,
                          Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '平均準確率',
                          '${widget.averageAccuracy.toStringAsFixed(1)}%',
                          Icons.check_circle_outline,
                          widget.averageAccuracy > 80
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (widget.exerciseTitle != '深蹲')
                        Expanded(
                          child: _buildStatCard(
                            '步數',
                            '${widget.stepCount} 步',
                            Icons.directions_walk_outlined,
                            Colors.purpleAccent,
                          ),
                        )
                      else
                        Expanded(child: Container()),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 疼痛回報卡片（支援二次點選修改）
                  _buildPainStatusCard(),

                  const SizedBox(height: 24),

                  // AI 建議區塊
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tips_and_updates, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('AI 教練悄悄話',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingAi)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                            ),
                          )
                        else
                          Text(
                            _dynamicAiFeedback ?? '沒有建議',
                            style: const TextStyle(fontSize: 16, height: 1.6),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('回到主頁',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 慶祝彩帶
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
