import 'api_service.dart';

class PointsService {
  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> getUnlocks() async {
    final response = await _api.dio.get(
      'points/unlocks/',
    );

    final data = response.data;

    if (data is List) {
      return data
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> unlockFeature({
    required String featureCode,
    required String referenceId,
  }) async {
    final response = await _api.dio.post(
      'points/use/',
      data: {
        'feature_code': featureCode,
        'reference_id': referenceId,
      },
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }

  Future<int> getBalance() async {
    final response = await _api.dio.get(
      'points/balance/',
    );

    return (response.data['balance'] as num).toInt();
  }

  String getErrorMessage(dynamic error) {
    return _api.getErrorMessage(error);
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _api.dio.get('points/transactions/');

    final data = response.data;

    if (data is List) {
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    return [];
  }

  // 管理員查詢全平台點數交易
  Future<List<Map<String, dynamic>>> getAdminTransactions(
      {String? type}) async {
    final Map<String, dynamic> params = {'all': 'true'};
    if (type != null && type != 'all') {
      params['type'] = type;
    }

    final response = await _api.dio.get(
      'points/transactions/',
      queryParameters: params,
    );

    final data = response.data;
    if (data is List) {
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }
}
