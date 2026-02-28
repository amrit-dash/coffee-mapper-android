import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class UserProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  String? _lastCheckedUid;
  String? _name;
  String? _role;
  String? _allocatedPanchayat;

  final _logger = AppLogger.getLogger('UserProvider');

  bool get isAdmin => _isAdmin;
  bool get isSuperAdmin => _isSuperAdmin;
  String? get name => _name;
  String? get role => _role;
  String? get allocatedPanchayat => _allocatedPanchayat;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  void checkUserStatus(String uid) {
    if (_lastCheckedUid == uid) {
      _logger.info('Using active user status stream for $uid');
      return;
    }

    _userSubscription?.cancel();
    _lastCheckedUid = uid;

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    docRef.update({
      'lastLogin': DateFormat('dd/MM/yyyy, HH:mm:ss').format(DateTime.now()),
    }).catchError((e) {
      _logger.warning('Failed to update lastLogin: $e');
    });
    
    _userSubscription = docRef.snapshots().listen(
      (doc) {
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

        _logger.info('User status updated: role=$_role, isAdmin=$_isAdmin, isSuperAdmin=$_isSuperAdmin');
        notifyListeners();
      },
      onError: (e) {
        _logger.warning('User status listen failed: $e');
        _role = "USER";
        _name = null;
        _allocatedPanchayat = null;
        _isAdmin = false;
        _isSuperAdmin = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void reset() {
    _isAdmin = false;
    _isSuperAdmin = false;
    _name = null;
    _role = null;
    _allocatedPanchayat = null;
    _lastCheckedUid = null;
    _userSubscription?.cancel();
    _userSubscription = null;
    notifyListeners();
  }
}
