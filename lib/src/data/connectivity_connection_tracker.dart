import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_network/src/domain/network_client.dart';

class ConnectivityConnectionTracker implements ConnectionTracker {
  final Connectivity _connectivity;

  ConnectivityConnectionTracker({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Stream<bool> get onConnectionChanged {
    return _connectivity.onConnectivityChanged.map(
      (result) => result != ConnectivityResult.none,
    );
  }
}
