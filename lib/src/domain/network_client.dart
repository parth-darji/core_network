import 'dart:async';

typedef ProgressCallback = void Function(int sentBytes, int totalBytes);

abstract interface class NetworkRequestPayload {
  Object toBody();
}

class NetworkFile {
  final List<int> bytes;
  final String filename;
  final String? contentType;

  const NetworkFile({
    required this.bytes,
    required this.filename,
    this.contentType,
  });
}

class MultipartPayload implements NetworkRequestPayload {
  final Map<String, String> fields;
  final Map<String, List<NetworkFile>> files;

  const MultipartPayload({required this.fields, required this.files})
    : assert(
        fields.length > 0 || files.length > 0,
        'MultipartPayload must contain at least one field or one file.',
      );

  @override
  Object toBody() => this;
}

abstract interface class NetworkInterceptor {
  /// Executed before every request is sent. Can modify headers or query parameters.
  Future<void> onRequest(
    String path,
    Map<String, String> headers,
    Map<String, Object?> queryParameters,
  );
}

abstract interface class NetworkClient {
  Future<T> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  });

  Future<T> post<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  });

  Future<T> put<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  });

  Future<T> delete<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  });

  Future<T> patch<T>(
    String path, {
    NetworkRequestPayload? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Set<Type> silentExceptions = const {},
    String? apiVersion,
  });
}

abstract interface class ConnectionTracker {
  Future<bool> get isConnected;
  Stream<bool> get onConnectionChanged;
}

abstract interface class TokenProvider {
  Future<String?> getAccessToken();
}
