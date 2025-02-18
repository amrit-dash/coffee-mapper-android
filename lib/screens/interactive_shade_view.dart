import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:maps_toolkit/maps_toolkit.dart' as mp;

import 'package:coffee_mapper/widgets/header.dart';
import 'package:coffee_mapper/screens/update_shade_details.dart';
import 'package:coffee_mapper/utils/logger.dart';

class InteractiveShadeViewScreen extends StatefulWidget {
  final DocumentSnapshot regionDocument;

  const InteractiveShadeViewScreen({super.key, required this.regionDocument});

  @override
  State<InteractiveShadeViewScreen> createState() =>
      _InteractiveShadeViewScreenState();
}

class _InteractiveShadeViewScreenState
    extends State<InteractiveShadeViewScreen> {
  final _logger = AppLogger.getLogger('InteractiveShadeView');
  late StreamSubscription<DocumentSnapshot> _latestInsightsSubscription;
  late StreamSubscription<DocumentSnapshot> _formDropdownsSubscription;
  DocumentSnapshot? _latestInsights;
  DocumentSnapshot? _formDropDownData;
  final Completer<gmap.GoogleMapController> _mapController = Completer();
  Set<gmap.Polygon> _polygons = {};

  @override
  void initState() {

    _formDropdownsSubscription = FirebaseFirestore.instance
        .collection('appData')
        .doc('formFieldDropdowns')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _formDropDownData = snapshot;
      });
    });

    _latestInsightsSubscription = FirebaseFirestore.instance
        .collection('savedRegions')
        .doc(widget.regionDocument.reference.id)
        .collection('regionInsights')
        .doc('latestInformation')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _latestInsights = snapshot;
      });

      _fetchShadeData();
    });

    super.initState();
  }

  @override
  void dispose() {
    _latestInsightsSubscription.cancel();
    _formDropdownsSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchShadeData() async {
    try {
      final polygonPoints =
          (widget.regionDocument['polygonPoints'] as List<dynamic>)
              .map((pointString) {
        final coordinates = pointString.split(',');
        return gmap.LatLng(
          double.parse(coordinates[0]),
          double.parse(coordinates[1]),
        );
      }).toList();

      setState(() {
        _polygons = {
          gmap.Polygon(
            polygonId: const gmap.PolygonId('01'),
            zIndex: 10,
            points: polygonPoints,
            strokeColor: Theme.of(context).colorScheme.secondary,
            strokeWidth: 3,
            fillColor: Theme.of(context).colorScheme.secondary.withAlpha(
                _latestInsights?.exists == true &&
                        _latestInsights!['surveyStatus'] == true
                    ? 204    // 0.8 * 255
                    : 128),  // 0.5 * 255
          ),
        };
      });

      // Animate camera to the polygon
      final gmap.GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
        gmap.CameraUpdate.newLatLngBounds(
          _getBounds(polygonPoints),
          50,
        ),
      );
    } catch (e) {
      _logger.severe('Error fetching shade data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error Fetching Shade Details!'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Helper function to calculate bounds for a list of LatLng points
  gmap.LatLngBounds _getBounds(List<gmap.LatLng> points) {
    double minLat = double.infinity;
    double minLng = double.infinity;
    double maxLat = -double.infinity;
    double maxLng = -double.infinity;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return gmap.LatLngBounds(
      southwest: gmap.LatLng(minLat, minLng),
      northeast: gmap.LatLng(maxLat, maxLng),
    );
  }

  // gmap.LatLng _calculatePolygonCenter(List<gmap.LatLng> points) {
  //   double latSum = 0.0;
  //   double lngSum = 0.0;
  //   for (final point in points) {
  //     latSum += point.latitude;
  //     lngSum += point.longitude;
  //   }
  //   return gmap.LatLng(latSum / points.length, lngSum / points.length);
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.regionDocument['regionName'],
                    style: const TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Select region to insert/update details',
                    style: TextStyle(
                      fontFamily: 'Gilroy-Medium',
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // The map
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor),
                  borderRadius: BorderRadius.circular(15),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 25),
                child: _buildMap(context),
              ),
            ),
            const SizedBox(height: 30),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBottomButton(
                    context,
                    text: 'Back',
                    filled: false,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildBottomButton(
                    context,
                    text: 'Home',
                    filled: true,
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/main_menu', (route) => false);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget for the map
  Widget _buildMap(BuildContext context) {
    return Stack(
      children: [
        gmap.GoogleMap(
          mapType: gmap.MapType.satellite,
          initialCameraPosition: const gmap.CameraPosition(
            target: gmap.LatLng(18.8137326, 82.7001428),
            zoom: 14.0,
          ),
          onMapCreated: (gmap.GoogleMapController controller) {
            _mapController.complete(controller);
          },
          polygons: _polygons,
          onTap: (gmap.LatLng latLng) {
            final isTappedInsidePolygon =
                _polygons.any((polygon) => mp.PolygonUtil.containsLocation(
                      mp.LatLng(latLng.latitude, latLng.longitude),
                      polygon.points
                          .map((point) =>
                              mp.LatLng(point.latitude, point.longitude))
                          .toList(),
                      true,
                    ));
            if (isTappedInsidePolygon) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UpdateShadeDetailsScreen(
                    regionDocument: widget.regionDocument,
                    insightsDocument: _latestInsights!,
                    formDropDownData: _formDropDownData!,
                  ),
                ),
              );
            }
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true, // Hide zoom buttons
        ),
      ],
    );
  }

  // Widget for the bottom buttons
  Widget _buildBottomButton(
    BuildContext context, {
    required String text,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 75,
      width: MediaQuery.of(context).size.width * 0.40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: (filled)
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          textStyle: TextStyle(
            fontFamily: 'Gilroy-SemiBold',
            fontSize: 23,
          ),
          side: BorderSide(
            width: 3,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: (filled)
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}
