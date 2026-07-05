import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:core_network/src/domain/network_client.dart';
import 'package:core_network/src/domain/app_exceptions.dart';

class ConnectionInterceptor implements NetworkInterceptor {
  final ConnectionTracker _connectionTracker;
  final String message;
  final int? statusCode;
  final Map<String, Object?>? errorData;

  const ConnectionInterceptor(
    this._connectionTracker, {
    this.message = 'No internet connection',
    this.statusCode,
    this.errorData,
  });

  @override
  Future<void> onRequest(
    String path,
    Map<String, String> headers,
    Map<String, Object?> queryParameters,
  ) async {
    final isOnline = await _connectionTracker.isConnected;
    if (!isOnline) {
      throw NoInternetException(
        message: message,
        statusCode: statusCode,
        errorData: errorData,
      );
    }
  }
}

class AuthInterceptor implements NetworkInterceptor {
  final TokenProvider _tokenProvider;

  const AuthInterceptor(this._tokenProvider);

  @override
  Future<void> onRequest(
    String path,
    Map<String, String> headers,
    Map<String, Object?> queryParameters,
  ) async {
    final token = await _tokenProvider.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
}

class DefaultHeadersInterceptor implements NetworkInterceptor {
  const DefaultHeadersInterceptor();

  @override
  Future<void> onRequest(
    String path,
    Map<String, String> headers,
    Map<String, Object?> queryParameters,
  ) async {
    headers.putIfAbsent('Accept', () => 'application/json');
  }
}

class LoggingInterceptor implements NetworkInterceptor {
  const LoggingInterceptor();

  @override
  Future<void> onRequest(
    String path,
    Map<String, String> headers,
    Map<String, Object?> queryParameters,
  ) async {
    if (kDebugMode) {
      print('--> [HTTP Request] $path');
      print('Headers: $headers');
      if (queryParameters.isNotEmpty) {
        print('QueryParameters: $queryParameters');
      }
    }
  }
}
