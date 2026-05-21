// header.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coffee_mapper/providers/attendance_provider.dart';
import 'package:coffee_mapper/providers/user_provider.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'package:coffee_mapper/widgets/user_menu_bottom_sheet.dart';

class Header extends StatefulWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  final _logger = AppLogger.getLogger('Header');
  int tapCounter = 0;
  int longTapCounter = 0;
  int doubleTapCounter = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.watch<UserProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    if (userProvider.role == 'USER') {
      final allocatedPanchayat = userProvider.allocatedPanchayat;
      if (attendanceProvider.panchayat != allocatedPanchayat) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) attendanceProvider.updatePanchayat(allocatedPanchayat);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 18, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and title
          SizedBox(
            height: 55,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      tapCounter++;
                    });
                  },
                  onDoubleTap: () {
                    setState(() {
                      doubleTapCounter++;
                    });
                  },
                  onLongPress: () {
                    if (tapCounter == 3 && doubleTapCounter == 1 && longTapCounter == 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Developed with 🤎 by Amrit Dash.'),
                          backgroundColor: Theme.of(context).highlightColor,
                        ),
                      );
                    }

                    if (tapCounter == 3 && doubleTapCounter == 1 && longTapCounter == 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Designed with 🤎 by Manish Rath.'),
                          backgroundColor: Theme.of(context).highlightColor,
                        ),
                      );
                    }

                    if (tapCounter == 3 && doubleTapCounter == 1 && longTapCounter == 5) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Co-ordinated with 🤎 by Abhishek Dutta.'),
                          backgroundColor: Theme.of(context).highlightColor,
                        ),
                      );
                      _resetCounters();
                      return;
                    }

                    setState(() {
                      longTapCounter++;
                    });

                    _logTapEvent();
                  },
                  child: SvgPicture.asset(
                    'assets/logo/logo.svg',
                    height: 34,
                    width: 36,
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Coffee Mapper',
                      style: TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Menu button
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 34),
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).highlightColor,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: false,
                backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const UserMenuBottomSheet(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _resetCounters() {
    setState(() {
      tapCounter = 0;
      doubleTapCounter = 0;
      longTapCounter = 0;
    });
    _logger.info("Counter's Reset!");
  }

  void _logTapEvent() {
    _logger.fine('Tap: $tapCounter\nDouble Tap: $doubleTapCounter\nLong Press: $longTapCounter');
  }
}