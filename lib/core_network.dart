import 'src/domain/network_client.dart';
import 'src/data/http_network_client.dart';
import 'src/data/dio_network_client.dart';
import 'src/data/default_interceptors.dart';

export 'src/domain/app_exceptions.dart';
export 'src/domain/network_client.dart';
export 'src/data/default_interceptors.dart';

class CoreNetwork {
  /// Instantiates a Dio-backed implementation of [NetworkClient].
  static NetworkClient dio({
    required String baseUrl,
    String defaultApiVersion = 'v1',
    List<NetworkInterceptor> interceptors = const [],
    Set<Type> defaultSilentExceptions = const {},
  }) {
    // Assert ConnectionInterceptor is the first in the chain if present
    final hasConnectionTracker = interceptors.any(
      (i) => i is ConnectionInterceptor,
    );
    if (hasConnectionTracker) {
      assert(
        interceptors.first is ConnectionInterceptor,
        'ConnectionInterceptor must be the first interceptor in the list to handle offline checks early.',
      );
    }

    return DioNetworkClient(
      baseUrl: baseUrl,
      defaultApiVersion: defaultApiVersion,
      interceptors: interceptors,
      defaultSilentExceptions: defaultSilentExceptions,
    );
  }

  /// Instantiates an HTTP-backed implementation of [NetworkClient].
  static NetworkClient http({
    required String baseUrl,
    String defaultApiVersion = 'v1',
    List<NetworkInterceptor> interceptors = const [],
    Set<Type> defaultSilentExceptions = const {},
  }) {
    // Assert ConnectionInterceptor is the first in the chain if present
    final hasConnectionTracker = interceptors.any(
      (i) => i is ConnectionInterceptor,
    );
    if (hasConnectionTracker) {
      assert(
        interceptors.first is ConnectionInterceptor,
        'ConnectionInterceptor must be the first interceptor in the list to handle offline checks early.',
      );
    }

    return HttpNetworkClient(
      baseUrl: baseUrl,
      defaultApiVersion: defaultApiVersion,
      interceptors: interceptors,
      defaultSilentExceptions: defaultSilentExceptions,
    );
  }
}
