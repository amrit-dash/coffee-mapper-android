import 'dart:async';
import 'package:coffee_mapper/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/user_provider.dart';

class UserMenuBottomSheet extends StatefulWidget {
  const UserMenuBottomSheet({super.key});

  @override
  State<UserMenuBottomSheet> createState() => _UserMenuBottomSheetState();
}

class _UserMenuBottomSheetState extends State<UserMenuBottomSheet> {
  final Location _location = Location();
  bool _hasShownLocationDialog = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Notification helpers ──────────────────────────────────────────────────

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Gilroy-SemiBold', fontSize: 18),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Gilroy-Medium', fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // ── Location & permissions ────────────────────────────────────────────────

  Future<bool> _checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isGranted || status.isLimited) return true;

    if (!mounted) return false;

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
              Text(
                'Coffee Mapper collects and uses your precise location data to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Verify your attendance at designated plantations'),
              Text('• Ensure check-ins occur within allowed geofences'),
              SizedBox(height: 12),
              Text(
                'Your location data will be used to validate your current position against the assigned region boundaries.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
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
        _showErrorDialog('Permission Required', 'Location permission is required for attendance.');
        return false;
      }
      _hasShownLocationDialog = true;
    }

    final newStatus = await Permission.location.request();
    if (newStatus.isGranted || newStatus.isLimited) return true;

    if (newStatus.isPermanentlyDenied) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission is required for attendance. Please enable it in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      _showErrorDialog('Permission Denied', 'Location permission denied.');
    }
    return false;
  }

  Future<void> _handleAttendance(
    AttendanceProvider attendanceProvider,
    String allocatedPanchayat,
    bool isCheckIn,
  ) async {
    if (attendanceProvider.isLoading) return;

    // Capture top-level UI references so notifications survive even if the
    // user dismisses this bottom sheet (or navigates away) while the GPS
    // lock / Firestore write is still in flight.
    final messenger = ScaffoldMessenger.of(context);
    final rootNavCtx = Navigator.of(context, rootNavigator: true).context;
    final dialogBg = Theme.of(context).dialogTheme.backgroundColor;
    final snackbarColor = Theme.of(context).colorScheme.secondary;

    void notifyError(String title, String message) {
      showDialog(
        context: rootNavCtx,
        builder: (ctx) => AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'Gilroy-SemiBold', fontSize: 18),
          ),
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Gilroy-Medium', fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    void notifySuccess(String message) {
      if (mounted) {
        Navigator.pop(context); // close bottom sheet if still visible
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Gilroy-Medium', fontSize: 14),
          ),
          backgroundColor: snackbarColor,
          elevation: 0,
        ),
      );
    }

    attendanceProvider.setLoading(true);

    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        attendanceProvider.setLoading(false);
        return;
      }

      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          notifyError('Location Disabled', 'Location service is disabled.');
          attendanceProvider.setLoading(false);
          return;
        }
      }

      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
            'Failed to get GPS lock. Please ensure you are outdoors with a clear view of the sky.',
          );
        },
      );

      if (locationData.isMock == true) {
        notifyError('Not Allowed', 'Mock locations are not allowed.');
        attendanceProvider.setLoading(false);
        return;
      }

      final regionInfo = await attendanceProvider.verifyGeofence(allocatedPanchayat, locationData);
      if (regionInfo == null) {
        notifyError('Out of Range', 'Not within range of any allocated region.');
        attendanceProvider.setLoading(false);
        return;
      }

      await attendanceProvider.markAttendance(isCheckIn, locationData, regionInfo);

      notifySuccess(isCheckIn ? 'Successfully checked in!' : 'Attendance marked!');
    } catch (e) {
      if (e is TimeoutException) {
        notifyError('GPS Timeout', e.message ?? 'GPS timeout error.');
      } else if (e.toString().contains('unavailable') ||
          e.toString().contains('UnknownHostException')) {
        notifyError('Network Error', 'Please check your internet connection.');
      } else {
        notifyError('Error', 'An unexpected error occurred.');
      }
    } finally {
      attendanceProvider.setLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    Navigator.pop(context);
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.read<UserProvider>().reset();
    context.read<AttendanceProvider>().reset();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── Name edit dialog ──────────────────────────────────────────────────────

  Future<void> _showEditNameDialog(String currentName) async {
    _nameController.text = currentName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: const Text(
          'Edit Name',
          style: TextStyle(fontFamily: 'Gilroy-SemiBold', fontSize: 18),
        ),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            fontFamily: 'Gilroy-SemiBold',
            fontSize: 16,
            color: Theme.of(context).highlightColor,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(
              fontFamily: 'Gilroy-Medium',
              fontSize: 14,
              color: Theme.of(context).canvasColor,
            ),
          ),
          onSubmitted: (_) => _saveNameFromDialog(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Gilroy-Medium',
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _saveNameFromDialog(ctx),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNameFromDialog(BuildContext ctx) async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && mounted) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await context.read<UserProvider>().updateName(uid, newName);
      }
    }
    if (ctx.mounted) Navigator.pop(ctx);
  }

  // ── Attendance button ─────────────────────────────────────────────────────

  static const double _btnHeight = 58;
  static const double _iconSize = 26;
  static const double _fontSize = 15;
  static const double _iconTextGap = 18;

  Widget _buildDisabledAttendanceButton(String label, IconData iconData) {
    final radius = BorderRadius.circular(14);
    final disabledBg = Theme.of(context).colorScheme.primary.withAlpha(90);
    return Expanded(
      child: SizedBox(
        height: _btnHeight,
        child: FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            backgroundColor: disabledBg,
            disabledBackgroundColor: disabledBg,
            side: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: _iconSize,
                weight: 600,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: _iconTextGap),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: _fontSize,
                  color: Theme.of(context).canvasColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceButton(
    AttendanceProvider attendanceProvider,
    String? allocatedPanchayat,
  ) {
    final isLoading = attendanceProvider.isLoading;
    final status = attendanceProvider.status;
    final hasRegions = attendanceProvider.hasRegions;
    final radius = BorderRadius.circular(14);
    final disabledBg = Theme.of(context).colorScheme.primary.withAlpha(90);

    if (status == AttendanceStatus.initializing) {
      return Expanded(
        child: SizedBox(
          height: _btnHeight,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),
      );
    }

    if (isLoading) {
      return Expanded(
        child: SizedBox(
          height: _btnHeight,
          child: FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: disabledBg,
              disabledBackgroundColor: disabledBg,
              side: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            child: SizedBox(
              width: 30,
              height: 30,
              child: LoadingAnimationWidget.fallingDot(
                color: Theme.of(context).colorScheme.secondary,
                size: 30,
              ),
            ),
          ),
        ),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 360;

    if (status == AttendanceStatus.done) {
      return _buildDisabledAttendanceButton(
        isNarrow ? 'MARKED' : 'ATTENDANCE MARKED',
        Symbols.check_circle,
      );
    }
    if (!hasRegions) {
      return _buildDisabledAttendanceButton('NO REGIONS', Symbols.timer_off);
    }
    if (status == AttendanceStatus.locked) {
      return _buildDisabledAttendanceButton('WAIT FOR 5 MINS', Symbols.timer_5);
    }

    String label;
    IconData iconData;
    VoidCallback onPressed;

    if (status == AttendanceStatus.checkOut) {
      label = 'CHECK OUT';
      iconData = Symbols.timer_pause;
      onPressed = () => _handleAttendance(attendanceProvider, allocatedPanchayat ?? '', false);
    } else {
      iconData = Symbols.timer_play;
      final panchayat = allocatedPanchayat ?? '';
      if (panchayat.isEmpty) {
        return _buildDisabledAttendanceButton('CHECK IN', Symbols.timer_play);
      }
      label = 'CHECK IN';
      onPressed = () => _handleAttendance(attendanceProvider, panchayat, true);
    }

    return Expanded(
      child: SizedBox(
        height: _btnHeight,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            side: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: _iconSize,
                weight: 600,
                color: Colors.white,
              ),
              const SizedBox(width: _iconTextGap),
              Text(
                label,
                style: const TextStyle(fontFamily: 'Gilroy-SemiBold', fontSize: _fontSize),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    final name = userProvider.name ?? '';
    final panchayat = userProvider.allocatedPanchayat ?? '—';
    final isUser = userProvider.role == 'USER';

    final labelStyle = TextStyle(
      fontFamily: 'Gilroy-Medium',
      fontSize: 13,
      color: Theme.of(context).canvasColor,
    );
    final valueStyle = TextStyle(
      fontFamily: 'Gilroy-SemiBold',
      fontSize: 19,
      color: Theme.of(context).highlightColor,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor.withAlpha(150),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 26),

          // Name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name', style: labelStyle),
                    const SizedBox(height: 4),
                    Text(
                      name.isNotEmpty ? name : '—',
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showEditNameDialog(name),
                icon: const Icon(Icons.edit_outlined, size: 22),
                color: Theme.of(context).canvasColor,
                tooltip: 'Edit name',
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (isUser)
          // Allocated Panchayat row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Allocated Panchayat', style: labelStyle),
              const SizedBox(height: 4),
              Text(panchayat, style: valueStyle),
            ],
          ),
          const SizedBox(height: 30),
          

          // Action buttons
          Row(
            children: [
              if (isUser) ...[
                _buildAttendanceButton(
                  attendanceProvider,
                  userProvider.allocatedPanchayat,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 58,
                  width: 58,
                  child: OutlinedButton(
                    onPressed: _handleLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828), width: 1.5),
                      backgroundColor: const Color(0xFFFFEBEE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.logout, size: 24),
                  ),
                ),
              ] else
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: OutlinedButton(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828), width: 1.5),
                        backgroundColor: const Color(0xFFFFEBEE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.logout, size: 26),
                          SizedBox(width: _iconTextGap),
                          Text(
                            'LOG OUT',
                            style: TextStyle(fontFamily: 'Gilroy-SemiBold', fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
