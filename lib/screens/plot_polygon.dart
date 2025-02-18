import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:location/location.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;

import '../widgets/header.dart';
import '../utils/area_formatter.dart';
import 'fill_shade_details.dart';

class PlotPolygonScreen extends StatefulWidget {
  const PlotPolygonScreen({super.key});

  @override
  State<PlotPolygonScreen> createState() => _PlotPolygonScreenState();
}

class _PlotPolygonScreenState extends State<PlotPolygonScreen> {
  final Completer<gmap.GoogleMapController> _controller = Completer();
  Set<gmap.Polygon> _polygons = {};
  List<gmap.LatLng> _polygonPoints = [];
  gmap.LatLng _startingPoint = gmap.LatLng(0, 0);
  bool _isTracking = false;
  bool _isTrackEnd = false;
  bool _showCompleteButton = false;
  bool _showUndoButton = false;
  bool _showLocationButton = false;
  double? _calculatedArea, _calculatedPerimeter;
  bool _isSnackbarShown = false; // Flag to track snackbar display
  List<String> _imagePaths = [];
  List<LocationData> _locationDataList = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();

    /*
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

     */

    final locationData = await location.getLocation();
    final currentLocation =
        gmap.LatLng(locationData.latitude!, locationData.longitude!);

    final gmap.GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      gmap.CameraUpdate.newCameraPosition(
        gmap.CameraPosition(
          target: currentLocation,
          zoom: 18,
        ),
      ),
    );
  }

  void _startTracking() async {
    final snackbarContext = context;
    Location location = Location();
    final locationData = await location.getLocation();
    final currentLocation =
        gmap.LatLng(locationData.latitude!, locationData.longitude!);

    setState(() {
      _isTracking = true;
      _showCompleteButton = false;
      _showUndoButton = false;
      _polygonPoints = [];
      _isSnackbarShown = false;
      _startingPoint = currentLocation;
      _polygonPoints.add(currentLocation);
    });

    if (!mounted) return;
    if (snackbarContext.mounted) {
      ScaffoldMessenger.of(snackbarContext).showSnackBar(
        const SnackBar(
          content: Text('Please start walking around the plantation.'),
        ),
      );
    }

    Location().onLocationChanged.listen((LocationData locationData) {
      if (_isTracking && mounted) {
        setState(() {
          _polygonPoints.add(
              gmap.LatLng(locationData.latitude!, locationData.longitude!));
          _checkDistanceToStart();

          _polygons = {
            gmap.Polygon(
              polygonId: const gmap.PolygonId('shade'),
              points: _polygonPoints,
              strokeColor: Theme.of(context).colorScheme.secondary,
              strokeWidth: 2,
              fillColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 128),
            ),
          };

          _animateCamera(locationData);
        });
      }
    });
  }

  // Add this new method
  Future<void> _animateCamera(LocationData locationData) async {
    final gmap.GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      gmap.CameraUpdate.newCameraPosition(
        gmap.CameraPosition(
          target: gmap.LatLng(locationData.latitude!, locationData.longitude!),
          zoom: 20,
        ),
      ),
    );
  }

  void _checkDistanceToStart() {
    if (_polygonPoints.length < 25) {
      return; // Need at least 25 points to calculate distance
    }

    if (_isSnackbarShown) {
      return; // Prevent showing snackbar multiple times
    }

    final startPoint = _startingPoint;
    final currentPoint = _polygonPoints.last;
    var distance = _calculateDistance(startPoint, currentPoint);

    //Polygon can be closed when distance <= 5 m
    if (distance <= 5) {
      // Show snackbar notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can now complete the polygon.'),
        ),
      );
      setState(() {
        _showCompleteButton = true; // Show button if within 5 meters
        _isSnackbarShown =
            true; // Set snackbar flag to prevent multiple displays
      });
    }
  }

  double _calculateDistance(gmap.LatLng p1, gmap.LatLng p2) {
    // Calculate distance using Haversine formula
    const double earthRadius = 6371000; // in meters
    final double lat1 = _toRadians(p1.latitude);
    final double lon1 = _toRadians(p1.longitude);
    final double lat2 = _toRadians(p2.latitude);
    final double lon2 = _toRadians(p2.longitude);

    final double dlon = lon2 - lon1;
    final double dlat = lat2 - lat1;

    final double a =
        pow(sin(dlat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _showLocationButtonMethod() {
    setState(() {
      _showLocationButton = true;
    });
  }

  void _completePolygon() {
    setState(() {
      _polygonPoints.first = _polygonPoints.last;
      _isTracking = false;
      _isTrackEnd = true;
      // _showCompleteButton = false; // Keep the complete button visible
      _showUndoButton = true;
      _polygons = {
        gmap.Polygon(
          polygonId: const gmap.PolygonId('shade'),
          points: _polygonPoints,
          strokeColor: Theme.of(context).colorScheme.secondary,
          strokeWidth: 2,
          fillColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 128),
        ),
      };
      _getPolygonDetails();
    });
  }

  void _getPolygonDetails() {
    if (_polygonPoints.length < 3) {
      return; // Need at least 3 points to form a polygon
    }

    List<mp.LatLng> polygonPoints = [];

    for (int i = 0; i < _polygonPoints.length; i++) {
      polygonPoints.add(
          mp.LatLng(_polygonPoints[i].latitude, _polygonPoints[i].longitude));
    }

    _calculatedArea = mp.SphericalUtil.computeArea(polygonPoints) as double;
    _calculatedPerimeter =
        mp.SphericalUtil.computeLength(polygonPoints) as double;

    //print ('Area: $_calculatedArea');
    //print ('Perimeter: $_calculatedPerimeter');

    return;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: (_isTracking || _isTrackEnd) ? false : true,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const Header(),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 40, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Measure by GPS',
                        style: TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 5, 30, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The map
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: _buildMap(context),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBottomButton(
                      context,
                      text: (_isTrackEnd)
                          ? 'Clear'
                          : ((_isTracking) ? 'Clear' : 'Back'),
                      isDisabled: _isTracking,
                      onTap: () {
                        if (_isTrackEnd) {
                          setState(() {
                            _showCompleteButton =
                                false; // Initially disable the auto-complete button
                            _showUndoButton = false;
                            _imagePaths = [];
                            _locationDataList = [];
                            _polygonPoints = []; // Clear any previous points
                            _isSnackbarShown = false; // Reset snackbar flag
                            _polygons = {
                              gmap.Polygon(
                                polygonId: const gmap.PolygonId('shade'),
                                points: _polygonPoints,
                                strokeColor: Theme.of(context).colorScheme.secondary,
                                strokeWidth: 0,
                                fillColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0),
                              ),
                            };
                            _isTrackEnd = false;
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    SizedBox(width: 15),
                    _buildTrackingButton(
                        context), // Use a separate widget for the tracking button
                  ],
                ),
              ),
            ],
          ),
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
          myLocationEnabled: true,
          initialCameraPosition: const gmap.CameraPosition(
            target: gmap.LatLng(18.8137326, 82.7001428),
            zoom: 11.0,
          ),
          onMapCreated: (gmap.GoogleMapController controller) {
            _controller.complete(controller);
            _showLocationButtonMethod();
          },
          polygons: _polygons,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false, // Hide zoom buttons
        ),
        if (_calculatedArea != null && _calculatedPerimeter != null)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Boundary:",
                        style: TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '${_calculatedPerimeter!.toStringAsFixed(2)} m',
                        style: TextStyle(
                          fontFamily: 'Gilroy-Medium',
                          fontSize: 14,
                          color: Theme.of(context).highlightColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        "Area:",
                        style: TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        AreaFormatter.formatArea(_calculatedArea!),
                        style: TextStyle(
                          fontFamily: 'Gilroy-Medium',
                          fontSize: 14,
                          color: Theme.of(context).highlightColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_showCompleteButton)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onPressed: _completePolygon,
              child: const Icon(
                Icons.library_add_check_outlined,
                size: 30,
              ),
            ),
          ),
        if (_showUndoButton)
          Positioned(
            bottom: 16,
            right: 85,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              onPressed: () {
                setState(() {
                  _polygonPoints.first = _startingPoint;
                  _isTracking = true;
                  _isTrackEnd = false;
                  _showUndoButton = false;
                  //_showCompleteButton = false;
                  //_isSnackbarShown = false;
                });
              },
              child: Icon(
                Icons.undo,
                size: 30,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        if (_isTracking)
          Positioned(
            // Boundary Image Camera Button
            top: 16,
            right: 66,
            width: 40,
            height: 40,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onPressed: () async {
                // 1. Pick an image from the camera with square aspect ratio
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  preferredCameraDevice: CameraDevice.rear,
                  maxHeight: 1000,
                  maxWidth: 1000, // Setting same height and width forces square
                );

                if (image != null) {
                  // 2. Get the current location
                  final location = Location();
                  final locationData = await location.getLocation();

                  // 3. Add the image path and location data to the lists
                  setState(() {
                    _imagePaths.add(image.path);
                    _locationDataList.add(locationData);
                  });
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100.0),
              ),
              child: Icon(
                Icons.camera_enhance_rounded,
                color: Theme.of(context).highlightColor,
              ),
            ),
          ),
        if (_imagePaths.isNotEmpty && _isTracking) // Show the number only if there are images
          Positioned(
            top: 8,
            right: 60,
            width: 18,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: Center(
                child: Text(
                  _imagePaths.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        if (_showLocationButton)
          Positioned(
            // Current location button
            top: 16,
            right: 16,
            width: 40,
            height: 40,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onPressed: () async {
                final location = Location();
                final locationData = await location.getLocation();
                final currentLocation = gmap.LatLng(
                    locationData.latitude!, locationData.longitude!);

                final controller = await _controller.future;
                controller.animateCamera(gmap.CameraUpdate.newCameraPosition(
                    gmap.CameraPosition(target: currentLocation, zoom: 20)));
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100.0),
              ),
              child: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrackingButton(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.09,
        child: _isTracking
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                    width: 2.5,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 22,
                  ),
                ),
                onPressed: null, // Disabled while tracking
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tracking',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 22),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 15,
                        child: LoadingAnimationWidget.dotsTriangle(
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (!_isTrackEnd)
                      ? Theme.of(context).scaffoldBackgroundColor
                      : Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 22,
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                    width: 2.5,
                  ),
                ),
                onPressed: () {
                  if (!_isTracking && !_isTrackEnd) {
                    _startTracking();
                  } else if (_isTrackEnd) {
                    // Navigate to Next Page with area, perimeter, and polygon points
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShadeDetailsScreen(
                          area: _calculatedArea ??
                              0.0, // Pass the calculated area (or 0.0 if null)
                          perimeter: _calculatedPerimeter ??
                              0.0, // Pass the calculated perimeter
                          polygonPoints:
                              _polygonPoints, // Pass the polygon points
                          shadeImagePaths: _imagePaths,
                          shadeImageLocations: _locationDataList,
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  (_isTrackEnd) ? 'Next' : 'Start',
                  style: TextStyle(
                    color: (!_isTrackEnd)
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
      ),
    );
  }

  // Widget for the bottom buttons
  Widget _buildBottomButton(
    BuildContext context, {
    required String text,
    required VoidCallback onTap,
    bool isDisabled = false, // Add a parameter to disable the button
  }) {
    return Expanded(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.09,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Gilroy-SemiBold',
              fontSize: 22,
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: 2.5,
            ),
          ),
          onPressed: isDisabled
              ? null
              : onTap, // Disable the button if isDisabled is true
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}
