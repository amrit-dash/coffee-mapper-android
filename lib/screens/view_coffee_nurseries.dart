import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:coffee_mapper/widgets/header.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'package:coffee_mapper/screens/update_nursery_details.dart';

class ViewCoffeeNurseriesScreen extends StatefulWidget {
  const ViewCoffeeNurseriesScreen({super.key});

  @override
  State<ViewCoffeeNurseriesScreen> createState() =>
      _ViewCoffeeNurseriesScreenState();
}

class _ViewCoffeeNurseriesScreenState extends State<ViewCoffeeNurseriesScreen> {
  final _logger = AppLogger.getLogger('ViewCoffeeNurseries');
  StreamSubscription<QuerySnapshot>? _nurseriesSubscription;
  List<DocumentSnapshot> _nurseries = [];
  bool _maybeNoItems = false;
  bool _isLoading = true;

  // Helper function to format the timestamp with different style options
  String _formatDate(dynamic timestamp, {String style = 'default'}) {
    if (timestamp == null) return 'Date not available';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        final seconds = timestamp['_seconds'];
        if (seconds == null) return 'Date not available';
        dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } else {
        return 'Invalid date format';
      }

      switch (style) {
        case 'DD-MMM-YYYY':
          final day = dateTime.day.toString().padLeft(2, '0');
          final month = DateFormat('MMM').format(dateTime);
          final year = dateTime.year;
          return '$day-$month-$year';

        case 'dd/MM/YYYY':
          return DateFormat('dd/MM/yyyy').format(dateTime);

        case 'dd/MM/yy':
          return DateFormat('dd/MM/yy').format(dateTime);

        default: // DD/MM/YY
          return DateFormat('dd-MM-yy').format(dateTime);
      }
    } catch (e) {
      _logger.warning('Error formatting date: $e');
      return 'Invalid Date';
    }
  }

  @override
  void initState() {
    super.initState();
    _setupNurseriesSubscription();
  }

  void _setupNurseriesSubscription() {
    if (!mounted) return;

    var query = FirebaseFirestore.instance
        .collection('coffeeNursery')
        .where('status', isNotEqualTo: 'Archived')
        .orderBy('updatedOn', descending: true);

    _nurseriesSubscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        if (snapshot.docs.isEmpty) {
          _maybeNoItems = true;
        }
        _nurseries = snapshot.docs;
        _isLoading = false;
      });
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _maybeNoItems = true;
      });
      _logger.severe('Error fetching nurseries: $error');
    });
  }

  @override
  void dispose() {
    _nurseriesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 0, 10),
              child: const Text(
                'Select Nursery To Update',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: (_nurseries.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          FutureBuilder(
                            future: Future.delayed(Duration(seconds: 4), () {
                              setState(() {
                                if (_maybeNoItems) {
                                  _isLoading = false;
                                }
                              });
                            }),
                            builder: (context, snapshot) {
                              if (_maybeNoItems && !_isLoading) {
                                return Text(
                                  "No saved nurseries found.",
                                  style: TextStyle(
                                    fontFamily: 'Gilroy-Medium',
                                    fontSize: 13.5,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                );
                              } else {
                                return SizedBox();
                              }
                            },
                          )
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                      child: ListView.builder(
                        itemCount: _nurseries.length,
                        itemBuilder: (context, index) {
                          return _buildNurseryCard(
                              context, index, _nurseries[index]);
                        },
                      ),
                    ),
            ),
            // Back button
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 15, 20, 20),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.08,
                width: MediaQuery.of(context).size.width * 0.45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    side: BorderSide(
                      width: 2.5,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 23,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Back',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for the nursery cards
  Widget _buildNurseryCard(
      BuildContext context, int index, DocumentSnapshot document) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Card(
        color: Theme.of(context).cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.0),
        ),
        child: InkWell(
          highlightColor:
              Theme.of(context).scaffoldBackgroundColor.withAlpha(77),
          splashColor: Theme.of(context).primaryColor.withAlpha(102),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpdateNurseryDetailsScreen(
                  nurseryDocument: document,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document['regionName'],
                  style: TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 19,
                    color: Theme.of(context).highlightColor,
                  ),
                ),
                Text(
                  '${document['regionCategory']}',
                  style: TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            'District: ${document['district']}',
                            style: const TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Subdivision: ${document['block']}',
                            style: const TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Panchayat: ${document['panchayat']}',
                            style: const TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Village: ${document['village']}',
                            style: const TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Updated On: ${_formatDate(document['updatedOn'])}',
                            style: TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: 12.5,
                              color: Theme.of(context).highlightColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: SvgPicture.asset(
                        'assets/icons/coffeeBeanOutline.svg',
                        height: 40,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).primaryColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
