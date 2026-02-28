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
  String? _panchayat;
  Timer? _lockTimer;
  Timer? _midnightTimer;
  String? _currentDateStr;
  
  StreamSubscription<QuerySnapshot>? _regionsSubscription;
  StreamSubscription<QuerySnapshot>? _nurserySubscription;
  bool _hasSavedRegions = false;
  bool _hasNursery = false;

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
  String? get panchayat => _panchayat;
  DateTime? get checkInTime => _checkInTime;
  DateTime? get checkOutTime => _checkOutTime;

  void initialize(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _listenToTodayAttendance();
  }

  void updatePanchayat(String? panchayat) {
    if (_panchayat == panchayat) return;
    _panchayat = panchayat;
    
    _regionsSubscription?.cancel();
    _nurserySubscription?.cancel();
    
    if (_panchayat == null || _panchayat!.isEmpty || _panchayat == 'NA') {
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

    _regionsSubscription = FirebaseFirestore.instance
        .collection('savedRegions')
        .where('panchayat', isEqualTo: _panchayat)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      _hasSavedRegions = snapshot.docs.isNotEmpty;
      _evaluateHasRegions();
    }, onError: (e) {
      // In case of offline errors, default to true to allow checks
      _hasRegions = true;
      notifyListeners();
    });

    _nurserySubscription = FirebaseFirestore.instance
        .collection('coffeeNursery')
        .where('panchayat', isEqualTo: _panchayat)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      _hasNursery = snapshot.docs.isNotEmpty;
      _evaluateHasRegions();
    }, onError: (e) {
      _hasRegions = true;
      notifyListeners();
    });
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
    _panchayat = null;
    _attendanceSubscription?.cancel();
    _regionsSubscription?.cancel();
    _nurserySubscription?.cancel();
    _lockTimer?.cancel();
    _status = AttendanceStatus.initializing;
    _checkInTime = null;
    _checkOutTime = null;
    _isLoading = false;
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

  Future<Map<String, String>?> verifyGeofence(String allocatedPanchayat, LocationData userLocationData) async {
    if (userLocationData.latitude == null || userLocationData.longitude == null) {
      return null;
    }
    final userLatLng = mp.LatLng(userLocationData.latitude!, userLocationData.longitude!);
    
    // 1. Query savedRegions
    final regionsQuery = await FirebaseFirestore.instance
        .collection('savedRegions')
        .where('panchayat', isEqualTo: allocatedPanchayat)
        .get();

    for (var doc in regionsQuery.docs) {
      final data = doc.data();
      if (data['polygonPoints'] is List) {
        final List<dynamic> pointsStr = data['polygonPoints'];
        final polygon = GeofenceHelper.getPolygonPoints(pointsStr);
        if (GeofenceHelper.isWithinGeofence(userLatLng, polygon)) {
          return {'id': doc.id, 'type': 'savedRegion'};
        }
      }
    }

    // 2. Query coffeeNursery
    final nurseryQuery = await FirebaseFirestore.instance
        .collection('coffeeNursery')
        .where('panchayat', isEqualTo: allocatedPanchayat)
        .get();

    for (var doc in nurseryQuery.docs) {
      final data = doc.data();
      if (data['polygonPoints'] is List) {
        final List<dynamic> pointsStr = data['polygonPoints'];
        final polygon = GeofenceHelper.getPolygonPoints(pointsStr);
        if (GeofenceHelper.isWithinGeofence(userLatLng, polygon)) {
          return {'id': doc.id, 'type': 'coffeeNursery'};
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
