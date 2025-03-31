import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  Function(LocationData)? _onLocationUpdate;
  bool _isTrackingActive = false;
  Timer? _throttleTimer;

  Future<void> initialize() async {
    bool backgroundEnabled = await _location.isBackgroundModeEnabled();
    if (!backgroundEnabled) {
      backgroundEnabled = await _location.enableBackgroundMode(enable: true);
    }
  }

  Future<void> startTracking(Function(LocationData) onLocationUpdate) async {
    if (_isTrackingActive) {
      return;
    }

    _onLocationUpdate = onLocationUpdate;

    // Cancel any existing subscriptions first
    await stopTracking();

    // Configure location settings with optimized values
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 500,
      distanceFilter: 0.2,
    );

    // Configure Android Notification
    await _location.changeNotificationOptions(
      onTapBringToFront: true, 
      title: "Background Mapper",
      subtitle: "Tracking region in the background...",
      iconName: "notification_icon",
      color: const Color(0xFFEADCC8),
    );

    // Start location updates with throttling
    _locationSubscription = _location.onLocationChanged.listen((locationData) {
      // Throttle updates to reduce main thread work
      _throttleTimer?.cancel();
      _throttleTimer = Timer(const Duration(milliseconds: 500), () {
        if (_onLocationUpdate != null && _isTrackingActive) {
          _onLocationUpdate!(locationData);
        }
      });
    });
    
    _isTrackingActive = true;
  }

  Future<void> stopTracking() async {
    if (!_isTrackingActive) {
      return;
    }

    try {
      // Cancel location subscription and throttle timer
      await _locationSubscription?.cancel();
      _throttleTimer?.cancel();
      _locationSubscription = null;
      _throttleTimer = null;
      _onLocationUpdate = null;
      
      // Disable background mode
      await _location.enableBackgroundMode(enable: false);
      
      _isTrackingActive = false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> dispose() async {
    await stopTracking();
    _isTrackingActive = false;
  }
} 