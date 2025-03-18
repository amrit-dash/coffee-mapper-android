import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:coffee_mapper/utils/logger.dart';

class AdminProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  final _logger = AppLogger.getLogger('AdminProvider');

  bool get isAdmin => _isAdmin;

  bool get isSuperAdmin => _isSuperAdmin;

  Future<void> checkAdminStatus(String email) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('admins').doc(email);
      final doc = await docRef.get();
      _isAdmin = doc.exists;

      if (doc.exists) {
        // Document exists, retrieve the data
        final data = doc.data();

        if (data != null) {
          final role = data['role'];

          if (role == "superAdmin") {
            _isSuperAdmin = true;
          } else {
            _isSuperAdmin = false;
          }
        }
      }
    } catch (e) {
      _logger.warning('Error checking admin status: $e');
      _isAdmin = false;
      _isSuperAdmin = false;
    }
    notifyListeners();
  }

  void reset() {
    _isAdmin = false;
    _isSuperAdmin = false;
    notifyListeners();
  }
}
