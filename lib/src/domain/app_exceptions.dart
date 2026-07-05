abstract class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, Object?>? errorData;
  final bool isSilent;

  const NetworkException({
    required this.message,
    this.statusCode,
    this.errorData,
    this.isSilent = false,
  });

  @override
  String toString() =>
      '$runtimeType: $message (status: $statusCode, silent: $isSilent)';
}

class NoInternetException extends NetworkException {
  const NoInternetException({
    super.message = 'No internet connection',
    super.statusCode,
    super.errorData,
    super.isSilent = false,
  });
}

class TimeoutException extends NetworkException {
  const TimeoutException({
    required super.message,
    super.statusCode,
    super.errorData,
    super.isSilent = false,
  });
}

class UnauthorizedException extends NetworkException {
  const UnauthorizedException({
    super.message = 'Unauthorized access',
    super.statusCode = 401,
    super.errorData,
    super.isSilent = false,
  });
}

class ForbiddenException extends NetworkException {
  const ForbiddenException({
    super.message = 'Access forbidden',
    super.statusCode = 403,
    super.errorData,
    super.isSilent = false,
  });
}

class NotFoundException extends NetworkException {
  const NotFoundException({
    super.message = 'Resource not found',
    super.statusCode = 404,
    super.errorData,
    super.isSilent = false,
  });
}

class ServerException extends NetworkException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.errorData,
    super.isSilent = false,
  });
}

class UnknownNetworkException extends NetworkException {
  const UnknownNetworkException({
    required super.message,
    super.statusCode,
    super.errorData,
    super.isSilent = false,
  });
}
