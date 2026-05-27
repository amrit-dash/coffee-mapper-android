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
  List<String> _allocatedPanchayats = const [];

  final _logger = AppLogger.getLogger('UserProvider');

  bool get isAdmin => _isAdmin;
  bool get isSuperAdmin => _isSuperAdmin;
  String? get name => _name;
  String? get role => _role;
  List<String> get allocatedPanchayats => _allocatedPanchayats;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  void checkUserStatus(String uid) {
    if (_lastCheckedUid == uid) {
      _logger.info('Using active user status stream for $uid');
      return;
    }

    _userSubscription?.cancel();
    _lastCheckedUid = uid;

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    _logger.info('Attempting to update lastLogin for user $uid...');
    docRef.update({
      'lastLogin': DateFormat('dd/MM/yyyy, HH:mm:ss').format(DateTime.now()),
    }).then((_) {
      _logger.info('Successfully updated lastLogin for user $uid');
    }).catchError((e) {
      _logger.severe('Failed to update lastLogin for user $uid. Error: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        _logger.severe('Permission denied: Check Firestore rules for user writes.');
      }
      if (e is FirebaseException && e.code == 'not-found') {
        _logger.severe('Not found: User document does not exist yet.');
      }
    });
    
    _userSubscription = docRef.snapshots().listen(
      (doc) {
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            _role = data['role'];
            _name = data['name'];
            _allocatedPanchayats = _parseAllocatedPanchayats(data['allocatedPanchayats']);

            _isSuperAdmin = _role == "DEV";
            _isAdmin = _role == "ADMIN" || _role == "DEV";
          }
        } else {
          // If no doc exists, default to non-admin
          _role = "USER";
          _name = null;
          _allocatedPanchayats = const [];
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
        _allocatedPanchayats = const [];
        _isAdmin = false;
        _isSuperAdmin = false;
        notifyListeners();
      },
    );
  }

  List<String> _parseAllocatedPanchayats(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().where((s) => s.isNotEmpty).toList(growable: false);
    }
    return const [];
  }

  Future<void> updateName(String uid, String newName) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'name': newName.trim()});
    // The existing snapshot listener auto-updates _name and calls notifyListeners()
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
    _allocatedPanchayats = const [];
    _lastCheckedUid = null;
    _userSubscription?.cancel();
    _userSubscription = null;
    notifyListeners();
  }
}
