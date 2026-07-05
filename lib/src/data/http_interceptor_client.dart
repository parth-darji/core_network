import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:core_network/src/domain/network_client.dart';
import 'package:core_network/src/domain/app_exceptions.dart';

class HttpInterceptorClient extends http.BaseClient {
  final http.Client _inner;
  final List<NetworkInterceptor> _interceptors;

  HttpInterceptorClient({required this._inner, required this._interceptors});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      for (final interceptor in _interceptors) {
        await interceptor.onRequest(
          request.url.path,
          request.headers,
          request.url.queryParameters,
        );
      }

      return await _inner.send(request);
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw UnknownNetworkException(message: e.toString());
    }
  }
}
