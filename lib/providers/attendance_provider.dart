import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;
import 'package:ntp/ntp.dart';
import '../utils/geofence_helper.dart';

enum AttendanceStatus { initializing, checkIn, locked, checkOut, done }

class AttendanceProvider with ChangeNotifier, WidgetsBindingObserver {
  AttendanceStatus _status = AttendanceStatus.initializing;
  bool _isLoading = false;
  String? _error;
  bool _hasRegions = true;
  
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  StreamSubscription<DocumentSnapshot>? _attendanceSubscription;
  String? _uid;
  List<String> _panchayats = const [];
  Timer? _lockTimer;
  Timer? _midnightTimer;
  String? _currentDateStr;
  
  StreamSubscription<QuerySnapshot>? _regionsSubscription;
  StreamSubscription<QuerySnapshot>? _nurserySubscription;
  bool _hasSavedRegions = false;
  bool _hasNursery = false;

  // In-memory cache of polygon data — populated by the region streams so
  // verifyGeofence() can run the math locally without a network round-trip.
  List<Map<String, dynamic>> _cachedSavedRegions = [];
  List<Map<String, dynamic>> _cachedNurseryRegions = [];

  AttendanceProvider() {
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightTimer();
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (_uid != null && _currentDateStr != _getTodayDateString()) {
        _listenToTodayAttendance();
      }
      _scheduleMidnightTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_uid != null && _currentDateStr != _getTodayDateString()) {
        _listenToTodayAttendance();
      }
    }
  }

  AttendanceStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasRegions => _hasRegions;
  List<String> get panchayats => _panchayats;
  DateTime? get checkInTime => _checkInTime;
  DateTime? get checkOutTime => _checkOutTime;

  void initialize(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _listenToTodayAttendance();
  }

  void updatePanchayats(List<String> panchayats) {
    if (_listEquals(_panchayats, panchayats)) return;
    _panchayats = List<String>.unmodifiable(panchayats);

    _regionsSubscription?.cancel();
    _nurserySubscription?.cancel();
    _cachedSavedRegions = [];
    _cachedNurseryRegions = [];

    if (_panchayats.isEmpty) {
      _hasRegions = false;
      _hasSavedRegions = false;
      _hasNursery = false;
      notifyListeners();
      return;
    }

    _hasSavedRegions = false;
    _hasNursery = false;
    _hasRegions = false;
    notifyListeners();

    // Fetch all region documents (not just .limit(1)) so we can cache polygon
    // data for offline-capable geofence verification in verifyGeofence().
    _regionsSubscription = FirebaseFirestore.instance
        .collection('savedRegions')
        .where('panchayat', whereIn: _panchayats)
        .snapshots()
        .listen((snapshot) {
      _hasSavedRegions = snapshot.docs.isNotEmpty;
      _cachedSavedRegions = snapshot.docs
          .where((doc) => doc.data()['polygonPoints'] is List)
          .map((doc) => {'id': doc.id, 'polygonPoints': doc.data()['polygonPoints'] as List})
          .toList();
      _evaluateHasRegions();
    }, onError: (e) {
      // Keep existing behaviour on error: assume regions exist so the user
      // can still attempt a check-in (verifyGeofence will catch mismatches).
      _hasRegions = true;
      notifyListeners();
    });

    _nurserySubscription = FirebaseFirestore.instance
        .collection('coffeeNursery')
        .where('panchayat', whereIn: _panchayats)
        .snapshots()
        .listen((snapshot) {
      _hasNursery = snapshot.docs.isNotEmpty;
      _cachedNurseryRegions = snapshot.docs
          .where((doc) => doc.data()['polygonPoints'] is List)
          .map((doc) => {'id': doc.id, 'polygonPoints': doc.data()['polygonPoints'] as List})
          .toList();
      _evaluateHasRegions();
    }, onError: (e) {
      _hasRegions = true;
      notifyListeners();
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _evaluateHasRegions() {
    final newValue = _hasSavedRegions || _hasNursery;
    if (_hasRegions != newValue) {
      _hasRegions = newValue;
      notifyListeners();
    }
  }

  void reset() {
    _uid = null;
    _panchayats = const [];
    _attendanceSubscription?.cancel();
    _regionsSubscription?.cancel();
    _nurserySubscription?.cancel();
    _lockTimer?.cancel();
    _status = AttendanceStatus.initializing;
    _checkInTime = null;
    _checkOutTime = null;
    _isLoading = false;
    _cachedSavedRegions = [];
    _cachedNurseryRegions = [];
    notifyListeners();
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  void _listenToTodayAttendance() {
    _attendanceSubscription?.cancel();
    if (_uid == null) return;

    final todayStr = _getTodayDateString();
    _currentDateStr = todayStr;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('attendance')
        .doc(todayStr);

    _status = AttendanceStatus.initializing;
    Future.microtask(() => notifyListeners());

    _attendanceSubscription = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        _status = AttendanceStatus.checkIn;
        _checkInTime = null;
        _checkOutTime = null;
        notifyListeners();
      } else {
        final data = snapshot.data();
        if (data != null) {
          final checkInData = data['checkInData'] as Map?;
          final checkOutData = data['checkOutData'] as Map?;
          
          _checkInTime = (checkInData?['time'] as Timestamp?)?.toDate() ?? (data['checkInTime'] as Timestamp?)?.toDate();
          if (checkInData != null && _checkInTime == null) {
            _checkInTime = DateTime.now();
          }

          _checkOutTime = (checkOutData?['time'] as Timestamp?)?.toDate() ?? (data['checkOutTime'] as Timestamp?)?.toDate();
          if (checkOutData != null && _checkOutTime == null) {
            _checkOutTime = DateTime.now();
          }

          await _evaluateStatus();
          notifyListeners();
        }
      }
    });
  }

  Future<void> _evaluateStatus() async {
    _lockTimer?.cancel();
    if (_checkOutTime != null) {
      _status = AttendanceStatus.done;
    } else if (_checkInTime != null) {
      final currentCheckInTime = _checkInTime!;
      DateTime now;
      try {
        now = await NTP.now();
      } catch (e) {
        now = DateTime.now();
      }
      
      // Prevent crash if reset() was called while awaiting NTP
      if (_checkInTime == null) return;
      
      final difference = now.difference(currentCheckInTime);
      if (difference.inMinutes >= 5) {
        _status = AttendanceStatus.checkOut;
      } else {
        _status = AttendanceStatus.locked;
        // Set timer to unlock
        final timeToWait = Duration(minutes: 5) - difference;
        if (!timeToWait.isNegative) {
          _lockTimer = Timer(timeToWait, () {
            _status = AttendanceStatus.checkOut;
            notifyListeners();
          });
        } else {
          _status = AttendanceStatus.checkOut;
        }
      }
    } else {
      _status = AttendanceStatus.checkIn;
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<Map<String, String>?> verifyGeofence(LocationData userLocationData) async {
    if (userLocationData.latitude == null || userLocationData.longitude == null) {
      return null;
    }
    if (_panchayats.isEmpty) return null;

    final userLatLng = mp.LatLng(userLocationData.latitude!, userLocationData.longitude!);

    // Use in-memory cache when available (populated by real-time streams in
    // updatePanchayats). The geofence math is purely local, so this path works
    // fully offline once the streams have fired at least once after login.
    // Falls back to a direct Firestore .get() only when the cache is still
    // empty (e.g. the very first check-in attempt immediately after login,
    // before the stream callbacks have had time to run).

    // 1. Check savedRegions
    if (_cachedSavedRegions.isNotEmpty) {
      for (final region in _cachedSavedRegions) {
        final polygon = GeofenceHelper.getPolygonPoints(region['polygonPoints'] as List);
        if (GeofenceHelper.isWithinGeofence(userLatLng, polygon)) {
          return {'id': region['id'] as String, 'type': 'savedRegion'};
        }
      }
    } else {
      final regionsQuery = await FirebaseFirestore.instance
          .collection('savedRegions')
          .where('panchayat', whereIn: _panchayats)
          .get();
      for (final doc in regionsQuery.docs) {
        final data = doc.data();
        if (data['polygonPoints'] is List) {
          final polygon = GeofenceHelper.getPolygonPoints(data['polygonPoints'] as List);
          if (GeofenceHelper.isWithinGeofence(userLatLng, polygon)) {
            return {'id': doc.id, 'type': 'savedRegion'};
          }
        }
      }
    }

    // 2. Check coffeeNursery
    if (_cachedNurseryRegions.isNotEmpty) {
      for (final region in _cachedNurseryRegions) {
        final polygon = GeofenceHelper.getPolygonPoints(region['polygonPoints'] as List);
        if (GeofenceHelper.isWithinGeofence(userLatLng, polygon)) {
          return {'id': region['id'] as String, 'type': 'coffeeNursery'};
        }
      }
    } else {
      final nurseryQuery = await FirebaseFirestore.instance
          .collection('coffeeNursery')
          .where('panchayat', whereIn: _panchayats)
          .get();
      for (final doc in nurseryQuery.docs) {
        final data = doc.data();
        if (data['polygonPoints'] is List) {
          final polygon = GeofenceHelper.getPolygonPoints(data['polygonPoints'] as List);
          if (GeofenceHelper.isWithinGeofence(userLatLng, polygon)) {
            return {'id': doc.id, 'type': 'coffeeNursery'};
          }
        }
      }
    }

    return null;
  }

  Future<void> markAttendance(bool isCheckIn, LocationData location, Map<String, String> regionInfo) async {
    if (_uid == null) throw Exception("User not authenticated.");
    
    // Write to the date we are currently tracking to avoid midnight edge cases
    final targetDateStr = _currentDateStr ?? _getTodayDateString();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('attendance')
        .doc(targetDateStr);

    final now = FieldValue.serverTimestamp();
    
    final checkData = {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'gpsAccuracy': location.accuracy,
      'time': now,
      'nearbyType': regionInfo['type'],
      'nearbyId': regionInfo['id'],
    };
    
    if (isCheckIn) {
      await docRef.set({
        'checkInData': checkData,
        'dateString': targetDateStr,
        'markedBy': _uid,
      }, SetOptions(merge: true));
    } else {
      final updateData = <String, dynamic>{
        'checkOutData': checkData,
        'markedBy': _uid,
      };

      if (_checkInTime != null) {
        final currentTime = DateTime.now();
        final diff = currentTime.difference(_checkInTime!);
        final durationInHours = diff.inSeconds / 3600.0;
        updateData['duration'] = double.parse(durationInHours.toStringAsFixed(1));
      }

      await docRef.update(updateData);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attendanceSubscription?.cancel();
    _regionsSubscription?.cancel();
    _nurserySubscription?.cancel();
    _lockTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }
}
