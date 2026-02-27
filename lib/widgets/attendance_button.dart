import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../providers/user_provider.dart';
import '../providers/attendance_provider.dart';

class AttendanceButton extends StatefulWidget {
  const AttendanceButton({super.key});

  @override
  State<AttendanceButton> createState() => _AttendanceButtonState();
}

class _AttendanceButtonState extends State<AttendanceButton> {
  final Location _location = Location();
  bool _hasShownLocationDialog = false;

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (!mounted) return false;

    // Show compliance notice before asking
    if (!status.isGranted && !_hasShownLocationDialog) {
      final bool? userConsent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            'Important Privacy Notice',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Coffee Mapper collects and uses your precise location data to:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('• Verify your attendance at designated plantations'),
              Text('• Ensure check-ins occur within allowed geofences'),
              SizedBox(height: 12),
              Text('Your location data will be used to validate your current position against the assigned region boundaries.', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (userConsent != true) {
        _showErrorSnackBar('Location permission is required for attendance.');
        return false;
      }
      _hasShownLocationDialog = true;
    }

    final newStatus = await Permission.location.request();
    if (newStatus.isGranted || newStatus.isLimited) {
      return true;
    } else if (newStatus.isPermanentlyDenied) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text("Location permission is required for attendance. Please enable it in Settings."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
    } else {
      _showErrorSnackBar('Location permission denied.');
    }
    return false;
  }

  Future<void> _handleAttendance(BuildContext context, String? allocatedPanchayat, AttendanceProvider attendanceProvider, bool isCheckIn) async {
    if (attendanceProvider.isLoading) return; // Prevent double-taps
    
    if (allocatedPanchayat == null || allocatedPanchayat.isEmpty) {
      _showErrorSnackBar('No allocated panchayat.');
      return;
    }

    attendanceProvider.setLoading(true);

    try {
      // 1. Check permissions
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        attendanceProvider.setLoading(false);
        return;
      }

      // 2. Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _showErrorSnackBar('Location service is disabled.');
          attendanceProvider.setLoading(false);
          return;
        }
      }

      // 3. Get location
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifying location...'), duration: Duration(seconds: 1)),
      );
      
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Failed to get GPS lock. Please ensure you are outdoors with a clear view of the sky.');
        },
      );

      if (locationData.isMock == true) {
        _showErrorSnackBar('Mock locations are not allowed.');
        attendanceProvider.setLoading(false);
        return;
      }

      // 4. Verify Geofence
      final regionInfo = await attendanceProvider.verifyGeofence(allocatedPanchayat, locationData);

      if (regionInfo == null) {
        _showErrorSnackBar('Not within range of any allocated region.');
        attendanceProvider.setLoading(false);
        return;
      }

      // 5. Mark Attendance
      await attendanceProvider.markAttendance(isCheckIn, locationData, regionInfo);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCheckIn ? 'Successfully Checked In!' : 'Successfully Checked Out!'),
            backgroundColor: Theme.of(context).highlightColor,
          ),
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        _showErrorSnackBar(e.message ?? 'GPS timeout error.');
      } else if (e.toString().contains('unavailable') || e.toString().contains('UnknownHostException')) {
        _showErrorSnackBar('Network error. Please check your internet connection.');
      } else {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      attendanceProvider.setLoading(false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final userProvider = context.watch<UserProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    
    if (userProvider.role == "USER") {
      final allocatedPanchayat = userProvider.allocatedPanchayat;
      if (attendanceProvider.panchayat != allocatedPanchayat) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            attendanceProvider.updatePanchayat(allocatedPanchayat);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    if (userProvider.role != "USER") {
      return const SizedBox.shrink();
    }

    final allocatedPanchayat = userProvider.allocatedPanchayat;

    final isChecking = attendanceProvider.isLoading;
    final status = attendanceProvider.status;
    final hasRegions = attendanceProvider.hasRegions;

    IconData buttonIcon = Icons.alarm;
    Color? iconColor = Theme.of(context).colorScheme.secondary;
    VoidCallback? onPressed;

    if (status == AttendanceStatus.initializing) {
      return const SizedBox.shrink();
    }

    if (status == AttendanceStatus.done) {
      buttonIcon = Icons.check_circle_outline;
      iconColor = Theme.of(context).highlightColor;
      onPressed = null;
    } else if (!hasRegions) {
      buttonIcon = Icons.location_off;
      iconColor = Theme.of(context).colorScheme.secondary;
      onPressed = () {
        _showErrorSnackBar('No saved regions in your allocated panchayat.');
      };
    } else if (status == AttendanceStatus.locked) {
      buttonIcon = Icons.lock_clock;
      iconColor = Theme.of(context).colorScheme.secondary;
      onPressed = () {
        _showErrorSnackBar('Already checked in. Please wait 5 mins to check out.');
      };
    } else if (status == AttendanceStatus.checkOut) {
      buttonIcon = Icons.alarm_off;
      iconColor = Theme.of(context).highlightColor;
      onPressed = () => _handleAttendance(context, allocatedPanchayat, attendanceProvider, false);
    } else {
      // status == AttendanceStatus.checkIn
      buttonIcon = Icons.alarm;
      iconColor = Theme.of(context).highlightColor;
      onPressed = () {
        if (allocatedPanchayat == null || allocatedPanchayat.isEmpty) {
          _showErrorSnackBar('No allocated panchayat.');
        } else {
          _handleAttendance(context, allocatedPanchayat, attendanceProvider, true);
        }
      };
    }

    return IconButton(
      onPressed: isChecking ? null : onPressed,
      icon: isChecking
          ? SizedBox(
              height: 25,
              width: 25,
              child: LoadingAnimationWidget.fallingDot(
                color: Theme.of(context).colorScheme.secondary,
                size: 30,
              ),
            )
          : Icon(buttonIcon),
      color: iconColor,
      iconSize: 28,
      tooltip: status == AttendanceStatus.checkOut ? "Check Out" : "Check In",
    );
  }
}
