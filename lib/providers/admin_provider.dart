import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:coffee_mapper/utils/logger.dart';

class AdminProvider with ChangeNotifier {
  bool _isAdmin = false;
  final _logger = AppLogger.getLogger('AdminProvider');

  bool get isAdmin => _isAdmin;

  Future<void> checkAdminStatus(String email) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('admins').doc(email);
      final doc = await docRef.get();
      _isAdmin = doc.exists;
    } catch (e) {
      _logger.warning('Error checking admin status: $e');
      _isAdmin = false;
    }
    notifyListeners();
  }

  void reset() {
    _isAdmin = false;
    notifyListeners();
  }
} 