import 'package:google_generative_ai/google_generative_ai.dart';

class AiCoachService {
  // TODO: 使用者必須在此填上他們自己的 Gemini API Key
  // 您可以在 https://aistudio.google.com/ 申請免費的 API Key
  static const String _apiKey = 'AIzaSyCWPFBKIdEGUYV8hfzPeyMB-yGP7j6F14o';

  /// 產生針對超慢跑運動表現的專屬教練回饋
  static Future<String> generateFeedback({
    required int timeSeconds,
    required double averageAccuracy,
    required int stepCount,
    required int calories,
  }) async {
    // 檢查是否仍為預設的 Placeholder 或為空
    if (_apiKey.isEmpty || _apiKey == 'AIzaSyCWPFBKIdEGUYV8hfzPeyMB-yGP7j6F14o') {
      return '【系統提示】偵測到尚未設定有效的 Gemini API Key。\n\n'
             '請前往 aistudio.google.com 申請 Key，並將其貼入 lib/services/ai_coach_service.dart 的 _apiKey 變數中！';
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
        ),
      );

      final int mins = timeSeconds ~/ 60;
      final int secs = timeSeconds % 60;

      final prompt = '''
你是一位專業、充滿熱情且溫暖的「超慢跑與體態矯正教練」。
你的學員剛剛完成了一次超慢跑訓練，請根據以下真實的感測器數據，給他一段大約 50~80 字的口語化回饋與建議。

[學員運動數據]
- 運動總時長：$mins 分 $secs 秒
- 總步數：$stepCount 步
- 消耗卡路里：$calories 大卡
- 姿勢平均準確率：${(averageAccuracy * 100).toStringAsFixed(1)}% 
  （準確率低於 70% 代表身體太前傾或膝蓋抬不夠高；高於 85% 代表姿勢非常標準）

[回答要求]
1. 語氣要像真人教練對學員說話，充滿鼓勵與熱情感。
2. 針對「準確率」或「時長」給出具體的下一步建議（例如改善駝背、提醒呼吸等）。
3. 使用繁體中文回答，可以直接加上一點 Emoji。
4. 字數精簡，不用長篇大論，大約 3 到 4 句話即可。
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      
      if (text == null || text.isEmpty) {
        return '教練正在思考中，請稍後再試！或者是剛才的運動數據讓教練太驚訝了。😅';
      }
      
      return text;
    } on GenerativeAIException catch (e) {
      if (e.message.contains('API_KEY_INVALID')) {
        return '【API 錯誤】您的 Gemini API Key 似乎無效，請重新檢查設定。';
      }
      return 'AI 服務發生異常：${e.message}';
    } catch (e) {
      return '連線到 AI 教練失敗，請檢查網路連線或 API Key 是否正確！\n錯誤類型: ${e.runtimeType}';
    }
  }
}
