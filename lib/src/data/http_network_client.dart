import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:core_network/src/domain/network_client.dart';
import 'package:core_network/src/domain/app_exceptions.dart';
import 'package:core_network/src/data/http_interceptor_client.dart';

class HttpNetworkClient implements NetworkClient {
  final String baseUrl;
  final String defaultApiVersion;
  final Set<Type> defaultSilentExceptions;
  final http.Client _client;

  HttpNetworkClient({
    required this.baseUrl,
    required List<NetworkInterceptor> interceptors,
    this.defaultApiVersion = 'v1',
    this.defaultSilentExceptions = const {},
  }) : _client = HttpInterceptorClient(
         inner: http.Client(),
         interceptors: interceptors,
       ) {
    assert(baseUrl.isNotEmpty, 'baseUrl cannot be empty');
    assert(
      baseUrl.startsWith('http://') || baseUrl.startsWith('https://'),
      'baseUrl must start with http:// or https://',
    );
    assert(!baseUrl.endsWith('/'), 'baseUrl must not end with a slash /');
  }

  /// Test-only constructor for dependency injection of mock clients.
  HttpNetworkClient.test({
    required http.Client client,
    required List<NetworkInterceptor> interceptors,
    this.defaultApiVersion = 'v1',
    this.defaultSilentExceptions = const {},
  }) : baseUrl = 'https://api.test.com',
       _client = HttpInterceptorClient(
         inner: client,
         interceptors: interceptors,
       );

  Uri _buildUri(
    String path,
    Map<String, Object?>? queryParameters,
    String? apiVersion,
  ) {
    assert(path.isNotEmpty, 'Request path cannot be empty');

    // 1. Fully-qualified URL check
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.parse(path);
      if (queryParameters == null || queryParameters.isEmpty) {
        return uri;
      }
      final stringQueryParams = queryParameters.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return uri.replace(queryParameters: stringQueryParams);
    }

    // 2. Relative path assertions
    assert(
      path.startsWith('/'),
      'Request path must start with a slash (e.g. "/users") or be a fully qualified HTTP/HTTPS URL',
    );
    assert(!path.contains('//'), 'Request path contains double slashes: $path');

    final cleanVersion = apiVersion ?? defaultApiVersion;
    final versionedPath = cleanVersion.isNotEmpty
        ? '/$cleanVersion$path'
        : path;
    final urlString = '$baseUrl$versionedPath';

    if (queryParameters == null || queryParameters.isEmpty) {
      return Uri.parse(urlString);
    }

    final stringQueryParams = queryParameters.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    return Uri.parse(urlString).replace(queryParameters: stringQueryParams);
  }

  NetworkException _updateExceptionSilence(
    NetworkException ex, {
    required bool isSilent,
  }) {
    if (ex is NoInternetException) {
      return NoInternetException(
        message: ex.message,
        statusCode: ex.statusCode,
        errorData: ex.errorData,
        isSilent: isSilent,
      );
    }
    if (ex is UnauthorizedException) {
      return UnauthorizedException(
        message: ex.message,
        statusCode: ex.statusCode,
        errorData: ex.errorData,
        isSilent: isSilent,
      );
    }
    if (ex is ForbiddenException) {
      return ForbiddenException(
        message: ex.message,
        statusCode: ex.statusCode,
        errorData: ex.errorData,
        isSilent: isSilent,
      );
    }
    if (ex is NotFoundException) {
      return NotFoundException(
        message: ex.message,
        statusCode: ex.statusCode,
        errorData: ex.errorData,
        isSilent: isSilent,
      );
    }
    if (ex is ServerException) {
      return ServerException(
        message: ex.message,
        statusCode: ex.statusCode,
        errorData: ex.errorData,
        isSilent: isSilent,
      );
    }
    if (ex is TimeoutException) {
      return TimeoutException(
        message: ex.message,
        statusCode: ex.statusCode,
        errorData: ex.errorData,
        isSilent: isSilent,
      );
    }
    return UnknownNetworkException(
      message: ex.message,
      statusCode: ex.statusCode,
      errorData: ex.errorData,
      isSilent: isSilent,
    );
  }

  Future<T> _executeRequest<T>(
    http.BaseRequest request, {
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
  }) async {
    final mergedSilentExceptions = {
      ...defaultSilentExceptions,
      ...silentExceptions,
    };
    try {
      final streamedResponse = await _client.send(request);
      final responseBodyBytes = <int>[];
      final totalBytes = streamedResponse.contentLength ?? -1;
      int bytesReceived = 0;

      await for (final chunk in streamedResponse.stream) {
        responseBodyBytes.addAll(chunk);
        bytesReceived += chunk.length;
        if (onReceiveProgress != null && totalBytes > 0) {
          onReceiveProgress(bytesReceived, totalBytes);
        }
      }

      final responseBody = utf8.decode(responseBodyBytes);

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        return _parseResponse<T>(responseBody);
      } else {
        throw _mapErrorResponse(
          statusCode: streamedResponse.statusCode,
          body: responseBody,
          silentExceptions: mergedSilentExceptions,
        );
      }
    } catch (e) {
      if (e is NetworkException) {
        final isSilent =
            e.isSilent || mergedSilentExceptions.contains(e.runtimeType);
        if (isSilent != e.isSilent) {
          throw _updateExceptionSilence(e, isSilent: isSilent);
        }
        rethrow;
      }
      final isSilent = mergedSilentExceptions.contains(UnknownNetworkException);
      throw UnknownNetworkException(message: e.toString(), isSilent: isSilent);
    }
  }

  T _parseResponse<T>(String body) {
    if (T == String) {
      return body as T;
    }
    if (body.isEmpty) {
      return null as T;
    }
    final decoded = jsonDecode(body);
    return decoded as T;
  }

  NetworkException _mapErrorResponse({
    required int statusCode,
    required String body,
    required Set<Type> silentExceptions,
  }) {
    Map<String, Object?>? errorMap;
    String errorMessage =
        'A network error occurred with status code $statusCode';

    try {
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          errorMap = decoded;
          errorMessage =
              decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              errorMessage;
        }
      }
    } catch (_) {
      // Ignore parsing errors for non-JSON error pages (like 500 HTML dumps)
    }

    final Type exceptionType;
    if (statusCode == 401) {
      exceptionType = UnauthorizedException;
    } else if (statusCode == 403) {
      exceptionType = ForbiddenException;
    } else if (statusCode == 404) {
      exceptionType = NotFoundException;
    } else if (statusCode >= 500) {
      exceptionType = ServerException;
    } else {
      exceptionType = UnknownNetworkException;
    }

    final isSilent = silentExceptions.contains(exceptionType);

    if (exceptionType == UnauthorizedException) {
      return UnauthorizedException(
        message: errorMessage,
        errorData: errorMap,
        isSilent: isSilent,
      );
    } else if (exceptionType == ForbiddenException) {
      return ForbiddenException(
        message: errorMessage,
        errorData: errorMap,
        isSilent: isSilent,
      );
    } else if (exceptionType == NotFoundException) {
      return NotFoundException(
        message: errorMessage,
        errorData: errorMap,
        isSilent: isSilent,
      );
    } else if (exceptionType == ServerException) {
      return ServerException(
        message: errorMessage,
        statusCode: statusCode,
        errorData: errorMap,
        isSilent: isSilent,
      );
    } else {
      return UnknownNetworkException(
        message: errorMessage,
        statusCode: statusCode,
        errorData: errorMap,
        isSilent: isSilent,
      );
    }
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  }) async {
    final uri = _buildUri(path, queryParameters, apiVersion);
    final request = http.Request('GET', uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    return _executeRequest<T>(
      request,
      onReceiveProgress: onReceiveProgress,
      silentExceptions: silentExceptions,
    );
  }

  @override
  Future<T> post<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  }) async {
    final uri = _buildUri(path, queryParameters, apiVersion);
    final request = _buildRequest('POST', uri, data, onSendProgress);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    return _executeRequest<T>(
      request,
      onReceiveProgress: onReceiveProgress,
      silentExceptions: silentExceptions,
    );
  }

  @override
  Future<T> put<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  }) async {
    final uri = _buildUri(path, queryParameters, apiVersion);
    final request = _buildRequest('PUT', uri, data, onSendProgress);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    return _executeRequest<T>(
      request,
      onReceiveProgress: onReceiveProgress,
      silentExceptions: silentExceptions,
    );
  }

  @override
  Future<T> delete<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  }) async {
    final uri = _buildUri(path, queryParameters, apiVersion);
    final request = _buildRequest('DELETE', uri, data, null);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    return _executeRequest<T>(request, silentExceptions: silentExceptions);
  }

  http.BaseRequest _buildRequest(
    String method,
    Uri uri,
    NetworkRequestPayload? data,
    ProgressCallback? onSendProgress,
  ) {
    if (data is MultipartPayload) {
      final request = _ProgressMultipartRequest(
        method,
        uri,
        onSendProgress: onSendProgress,
      );
      request.fields.addAll(data.fields);

      for (final entry in data.files.entries) {
        for (final file in entry.value) {
          request.files.add(
            http.MultipartFile.fromBytes(
              entry.key,
              file.bytes,
              filename: file.filename,
            ),
          );
        }
      }
      return request;
    }

    final request = _ProgressRequest(
      method,
      uri,
      onSendProgress: onSendProgress,
    );
    if (data != null) {
      final bodyData = data.toBody();
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(bodyData);
    }
    return request;
  }
}

class _ProgressRequest extends http.Request {
  final ProgressCallback? onSendProgress;

  _ProgressRequest(super.method, super.url, {this.onSendProgress});

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final totalBytes = contentLength;

    if (onSendProgress == null || totalBytes <= 0) {
      return byteStream;
    }

    int bytesSent = 0;
    return http.ByteStream(
      byteStream.map((chunk) {
        bytesSent += chunk.length;
        onSendProgress!(bytesSent, totalBytes);
        return chunk;
      }),
    );
  }
}

class _ProgressMultipartRequest extends http.MultipartRequest {
  final ProgressCallback? onSendProgress;

  _ProgressMultipartRequest(super.method, super.url, {this.onSendProgress});

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final totalBytes = contentLength;

    if (onSendProgress == null || totalBytes <= 0) {
      return byteStream;
    }

    int bytesSent = 0;
    return http.ByteStream(
      byteStream.map((chunk) {
        bytesSent += chunk.length;
        onSendProgress!(bytesSent, totalBytes);
        return chunk;
      }),
    );
  }
}
