import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ConnectionApi {
  final Dio _dio;

  ConnectionApi(this._dio);

  Future<bool> checkHealth(String host) async {
    final response = await _dio.get(
      'http://$host:8383/health',
      options: Options(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    return response.statusCode == 200;
  }
}
