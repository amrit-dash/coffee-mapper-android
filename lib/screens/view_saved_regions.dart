import 'dart:async';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import 'package:coffee_mapper/widgets/header.dart';
import 'package:coffee_mapper/screens/interactive_shade_view.dart';
import 'package:coffee_mapper/providers/admin_provider.dart';
import 'package:coffee_mapper/utils/logger.dart';

class ViewSavedRegionsScreen extends StatefulWidget {
  const ViewSavedRegionsScreen({super.key});

  @override
  State<ViewSavedRegionsScreen> createState() => _ViewSavedRegionsScreenState();
}

class _ViewSavedRegionsScreenState extends State<ViewSavedRegionsScreen> {
  final _logger = AppLogger.getLogger('ViewSavedRegions');
  // ignore: undefined_class
  StreamSubscription<QuerySnapshot>? _regionsSubscription;
  List<DocumentSnapshot> _regions = [];
  bool _maybeNoItems = false;
  bool _isLoading = true;

  // Helper function to format the timestamp with different style options
  String _formatDate(dynamic timestamp, {String style = 'default'}) {
    if (timestamp == null) return 'Date not available';
    
    try {
      // Handle both Timestamp and Map cases
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        // Handle server timestamp special case
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

  void _setupRegionsSubscription() {
    // Get admin status
    if (!mounted) return;

    // Build the base query
    var query = FirebaseFirestore.instance
        .collection('savedRegions')
        .where('regionCategory', isNotEqualTo: 'Archived')
        .orderBy('updatedOn', descending: true);

    
    /*
    // Add user filter only for non-admin users - Descoped
    // All users can see all regions

    final isAdmin = context.read<AdminProvider>().isAdmin;
    
    if (!isAdmin) {
      query = query.where('savedBy', isEqualTo: FirebaseAuth.instance.currentUser!.email);
    }
    */

    // Subscribe to the Firestore stream
    _regionsSubscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        if(snapshot.docs.isEmpty) {
          _maybeNoItems = true;
        }
        _regions = snapshot.docs;
        _isLoading = false;
      });
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _maybeNoItems = true;
      });
      _logger.severe('Error fetching regions: $error');
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAdminAndSetup();
  }

  Future<void> _checkAdminAndSetup() async {
    if (!mounted) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await context.read<AdminProvider>().checkAdminStatus(user.email!);
      }
    } catch (e) {
      _logger.warning('Error checking admin status: $e');
    }
    
    _setupRegionsSubscription();
  }

  @override
  void dispose() {
    _regionsSubscription?.cancel();
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
                'Select Region To Update',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: (_regions.isEmpty)
                  ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if(_isLoading)
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
                                  "No saved regions found.",
                                  style: TextStyle(
                                    fontFamily: 'Gilroy-Medium',
                                    fontSize: 13.5,
                                    color: Theme.of(context).colorScheme.secondary,
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
                        itemCount: _regions.length,
                        itemBuilder: (context, index) {
                          return _buildRegionCard(
                              context, index, _regions[index]);
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

  // Widget for the region cards
  Widget _buildRegionCard(
      BuildContext context, int index, DocumentSnapshot document) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Card(
        color: (document['surveyStatus']) ? Theme.of(context).cardColor : Theme.of(context).colorScheme.surface,
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
                builder: (context) => InteractiveShadeViewScreen(
                  regionDocument: document,
                ),
              ),
            );
          },
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    18, 15, MediaQuery.of(context).size.width * 0.35, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document['regionName'], // Replace with actual region name
                      style: TextStyle(
                        fontFamily: 'Gilroy-SemiBold',
                        fontSize: 19,
                        color: Theme.of(context).highlightColor,
                      ),
                    ),
                    Text(
                      '${document['regionCategory']}', // Replace with actual survey status
                      style: TextStyle(
                        fontFamily: 'Gilroy-SemiBold',
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),

                  // const SizedBox(height: 8),
                  //   Text(
                  //     'Survey status', // Replace with actual survey status
                  //     style: TextStyle(
                  //       fontFamily: 'Gilroy-Medium',
                  //       fontSize: 11,
                  //     ),
                  //   ),
                  //   Text(
                  //     (document['surveyStatus'])
                  //         ? 'Completed'
                  //         : 'Not Completed', // Replace with actual survey status
                  //     style: TextStyle(
                  //       fontFamily: 'Gilroy-SemiBold',
                  //       fontSize: 13,
                  //       color: (document['surveyStatus'])
                  //           ? Theme.of(context).highlightColor
                  //           : Theme.of(context).primaryColor,
                  //     ),
                  //   ),

                    const SizedBox(height: 10),
                    Text(
                      'District: ${document['district']}', // Replace with actual district
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Subdivision: ${document['block']}', // Replace with actual tehsil/block
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Panchayat: ${document['panchayat']}', // Replace with actual tehsil/block
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Village: ${document['village']}', // Replace with actual tehsil/block
                      style: const TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(document['surveyStatus'])
                          ? 'Updated On:'
                          : 'Saved On:'} ${(document['updatedOn'].toString().isNotEmpty) ? _formatDate(document['updatedOn']) : ''}', // Replace with actual last updated date
                      style: TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 12.5,
                        color: Theme.of(context).highlightColor,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: MediaQuery.of(context).size.width * 0.028,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 135,
                  child: Center(
                    child: SizedBox(
                      width: 25,
                      height: 25,
                      child: LoadingAnimationWidget.beat(
                        color: Theme.of(context).colorScheme.primary,
                        size: 23,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 135,
                  child: (document['mapImageUrl'] == "NA" || document['mapImageUrl'] == null)
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(13),
                              bottomRight: Radius.circular(13),
                            ),
                            color: Colors.grey[300],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.grey[600],
                              size: 30,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(13),
                              bottomRight: Radius.circular(13),
                            ),
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              alignment: FractionalOffset.topCenter,
                              image: NetworkImage(document['mapImageUrl']),
                              onError: (exception, stackTrace) {
                                // Handle error silently
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
