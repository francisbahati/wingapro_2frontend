import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A service that monitors network connectivity.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isConnected = true;

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isConnected = result != ConnectivityResult.none;
      _controller.add(_isConnected);
    });
  }

  /// Stream of connectivity changes. Emits `true` when online, `false` when offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current connectivity status.
  bool get isConnected => _isConnected;

  /// Check connectivity once.
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() => _controller.close();
}