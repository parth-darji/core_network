import 'dart:async';
import 'package:dio/dio.dart' hide ProgressCallback;
import 'package:core_network/src/domain/network_client.dart';
import 'package:core_network/src/domain/app_exceptions.dart';

class DioNetworkClient implements NetworkClient {
  final String baseUrl;
  final String defaultApiVersion;
  final Set<Type> defaultSilentExceptions;
  final Dio _dio;

  DioNetworkClient({
    required this.baseUrl,
    required List<NetworkInterceptor> interceptors,
    this.defaultApiVersion = 'v1',
    this.defaultSilentExceptions = const {},
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
         ),
       ) {
    assert(baseUrl.isNotEmpty, 'baseUrl cannot be empty');
    assert(
      baseUrl.startsWith('http://') || baseUrl.startsWith('https://'),
      'baseUrl must start with http:// or https://',
    );
    assert(!baseUrl.endsWith('/'), 'baseUrl must not end with a slash /');

    _dio.interceptors.add(_DioInterceptorWrapper(interceptors));
  }

  /// Test-only constructor for dependency injection of mock Dio client.
  DioNetworkClient.test({
    required this._dio,
    required List<NetworkInterceptor> interceptors,
    this.defaultApiVersion = 'v1',
    this.defaultSilentExceptions = const {},
  }) : baseUrl = 'https://api.test.com' {
    _dio.interceptors.add(_DioInterceptorWrapper(interceptors));
  }

  String _resolvePath(String path, String? apiVersion) {
    assert(path.isNotEmpty, 'Request path cannot be empty');

    // 1. Fully-qualified URL check
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // 2. Relative path assertions
    assert(
      path.startsWith('/'),
      'Request path must start with a slash (e.g. "/users") or be a fully qualified HTTP/HTTPS URL',
    );
    assert(!path.contains('//'), 'Request path contains double slashes: $path');

    final cleanVersion = apiVersion ?? defaultApiVersion;
    return cleanVersion.isNotEmpty ? '/$cleanVersion$path' : path;
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
    Future<Response<dynamic>> Function() requestCall, {
    Set<Type> silentExceptions = const {},
  }) async {
    final mergedSilentExceptions = {
      ...defaultSilentExceptions,
      ...silentExceptions,
    };
    try {
      final response = await requestCall();
      return _parseResponse<T>(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e, silentExceptions: mergedSilentExceptions);
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

  T _parseResponse<T>(dynamic data) {
    if (data == null) {
      return null as T;
    }
    if (T == String) {
      return data.toString() as T;
    }
    return data as T;
  }

  Object? _buildRequestBody(NetworkRequestPayload? data) {
    if (data == null) {
      return null;
    }

    if (data is MultipartPayload) {
      final formData = FormData.fromMap(data.fields);
      for (final entry in data.files.entries) {
        for (final file in entry.value) {
          formData.files.add(
            MapEntry(
              entry.key,
              MultipartFile.fromBytes(
                file.bytes,
                filename: file.filename,
                contentType: file.contentType != null
                    ? DioMediaType.parse(file.contentType!)
                    : null,
              ),
            ),
          );
        }
      }
      return formData;
    }

    return data.toBody();
  }

  NetworkException _mapDioError(
    DioException error, {
    required Set<Type> silentExceptions,
  }) {
    if (error.error is NetworkException) {
      final originEx = error.error as NetworkException;
      final isSilent =
          originEx.isSilent || silentExceptions.contains(originEx.runtimeType);

      if (originEx is NoInternetException) {
        return NoInternetException(
          message: originEx.message,
          statusCode: originEx.statusCode,
          errorData: originEx.errorData,
          isSilent: isSilent,
        );
      }
      if (originEx is UnauthorizedException) {
        return UnauthorizedException(
          message: originEx.message,
          statusCode: originEx.statusCode,
          errorData: originEx.errorData,
          isSilent: isSilent,
        );
      }
      if (originEx is ForbiddenException) {
        return ForbiddenException(
          message: originEx.message,
          statusCode: originEx.statusCode,
          errorData: originEx.errorData,
          isSilent: isSilent,
        );
      }
      if (originEx is NotFoundException) {
        return NotFoundException(
          message: originEx.message,
          statusCode: originEx.statusCode,
          errorData: originEx.errorData,
          isSilent: isSilent,
        );
      }
      if (originEx is ServerException) {
        return ServerException(
          message: originEx.message,
          statusCode: originEx.statusCode,
          errorData: originEx.errorData,
          isSilent: isSilent,
        );
      }
      return UnknownNetworkException(
        message: originEx.message,
        statusCode: originEx.statusCode,
        errorData: originEx.errorData,
        isSilent: isSilent,
      );
    }

    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    Map<String, Object?>? errorMap;
    String errorMessage = 'A network error occurred';

    if (responseData is Map<String, dynamic>) {
      errorMap = responseData;
      if (responseData['error'] is Map<String, dynamic>) {
        final innerError = responseData['error'] as Map<String, dynamic>;
        final innerMessage = innerError['message'];
        if (innerMessage is List) {
          errorMessage = innerMessage.join(', ');
        } else if (innerMessage != null) {
          errorMessage = innerMessage.toString();
        } else {
          errorMessage = innerError['code']?.toString() ?? errorMessage;
        }
      } else {
        final msg = responseData['message'];
        if (msg is List) {
          errorMessage = msg.join(', ');
        } else {
          errorMessage =
              msg?.toString() ??
              responseData['error']?.toString() ??
              errorMessage;
        }
      }
    } else if (responseData is String && responseData.isNotEmpty) {
      errorMessage = responseData;
    }

    final Type exceptionType;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      exceptionType = TimeoutException;
    } else if (error.type == DioExceptionType.connectionError) {
      exceptionType = NoInternetException;
    } else if (statusCode == 401) {
      exceptionType = UnauthorizedException;
    } else if (statusCode == 403) {
      exceptionType = ForbiddenException;
    } else if (statusCode == 404) {
      exceptionType = NotFoundException;
    } else if (statusCode != null && statusCode >= 500) {
      exceptionType = ServerException;
    } else {
      exceptionType = UnknownNetworkException;
    }

    final isSilent = silentExceptions.contains(exceptionType);

    if (exceptionType == TimeoutException) {
      return TimeoutException(
        message: 'Connection timed out',
        statusCode: statusCode,
        isSilent: isSilent,
      );
    } else if (exceptionType == NoInternetException) {
      return NoInternetException(
        message: 'No internet connection',
        statusCode: statusCode,
        isSilent: isSilent,
      );
    } else if (exceptionType == UnauthorizedException) {
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
    final resolvedPath = _resolvePath(path, apiVersion);
    return _executeRequest<T>(
      () => _dio.get<dynamic>(
        resolvedPath,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        onReceiveProgress: onReceiveProgress,
      ),
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
    final resolvedPath = _resolvePath(path, apiVersion);
    return _executeRequest<T>(
      () => _dio.post<dynamic>(
        resolvedPath,
        data: _buildRequestBody(data),
        queryParameters: queryParameters,
        options: Options(headers: headers),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
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
    final resolvedPath = _resolvePath(path, apiVersion);
    return _executeRequest<T>(
      () => _dio.put<dynamic>(
        resolvedPath,
        data: _buildRequestBody(data),
        queryParameters: queryParameters,
        options: Options(headers: headers),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
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
    final resolvedPath = _resolvePath(path, apiVersion);
    return _executeRequest<T>(
      () => _dio.delete<dynamic>(
        resolvedPath,
        data: _buildRequestBody(data),
        queryParameters: queryParameters,
        options: Options(headers: headers),
      ),
      silentExceptions: silentExceptions,
    );
  }

  @override
  Future<T> patch<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  }) async {
    final resolvedPath = _resolvePath(path, apiVersion);
    return _executeRequest<T>(
      () => _dio.patch<dynamic>(
        resolvedPath,
        data: _buildRequestBody(data),
        queryParameters: queryParameters,
        options: Options(headers: headers),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      silentExceptions: silentExceptions,
    );
  }
}

class _DioInterceptorWrapper extends Interceptor {
  final List<NetworkInterceptor> _interceptors;

  _DioInterceptorWrapper(this._interceptors);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final headersMap = options.headers.map((k, v) => MapEntry(k, v.toString()));

    try {
      for (final interceptor in _interceptors) {
        await interceptor.onRequest(
          options.path,
          headersMap,
          options.queryParameters,
        );
      }
      options.headers.addAll(headersMap);
      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.connectionError,
        ),
      );
    }
  }
}
