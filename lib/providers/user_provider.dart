import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'dart:async';
import 'dart:math';

class UserProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  String? _lastCheckedUid;
  String? _name;
  String? _role;
  String? _allocatedPanchayat;

  final _logger = AppLogger.getLogger('UserProvider');
  static const int _maxRetries = 5;
  static const Duration _initialDelay = Duration(milliseconds: 500);
  static const Duration _maxDelay = Duration(seconds: 5);

  bool get isAdmin => _isAdmin;
  bool get isSuperAdmin => _isSuperAdmin;
  String? get name => _name;
  String? get role => _role;
  String? get allocatedPanchayat => _allocatedPanchayat;

  Future<void> checkUserStatus(String uid) async {
    if (_lastCheckedUid == uid) {
      _logger.info('Using cached user status for $uid');
      return;
    }

    int retryCount = 0;
    Duration delay = _initialDelay;

    while (retryCount < _maxRetries) {
      try {
        _logger.info('Checking user status for $uid (attempt ${retryCount + 1}/$_maxRetries)');
        
        final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final doc = await docRef.get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            _role = data['role'];
            _name = data['name'];
            _allocatedPanchayat = data['allocatedPanchayat'];
            
            _isSuperAdmin = _role == "DEV";
            _isAdmin = _role == "ADMIN" || _role == "DEV";
          }
        } else {
          // If no doc exists, default to non-admin
          _role = "USER";
          _name = null;
          _allocatedPanchayat = null;
          _isAdmin = false;
          _isSuperAdmin = false;
        }

        _lastCheckedUid = uid;
        _logger.info('User status check successful: role=$_role, isAdmin=$_isAdmin, isSuperAdmin=$_isSuperAdmin');
        notifyListeners();
        return; 
      } catch (e) {
        retryCount++;
        _logger.warning('User status check attempt $retryCount failed: $e');
        
        if (retryCount == _maxRetries) {
          _logger.severe('Failed to check user status after $retryCount attempts. Defaulting to non-admin access.');
          _role = "USER";
          _name = null;
          _allocatedPanchayat = null;
          _isAdmin = false;
          _isSuperAdmin = false;
          notifyListeners();
          return;
        }

        delay = Duration(milliseconds: min(
          _maxDelay.inMilliseconds,
          (_initialDelay.inMilliseconds * pow(2, retryCount - 1)).round() +
              (Random().nextInt(1000)),
        ));

        _logger.info('Retrying user status check in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
  }

  void reset() {
    _isAdmin = false;
    _isSuperAdmin = false;
    _name = null;
    _role = null;
    _allocatedPanchayat = null;
    _lastCheckedUid = null;
    notifyListeners();
  }
}
