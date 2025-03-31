import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:location/location.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:permission_handler/permission_handler.dart';

import '../widgets/header.dart';
import '../utils/area_formatter.dart';
import 'fill_shade_details.dart';
import '../config/app_config_parameters.dart';
import '../services/background_location_service.dart';

class PlotPolygonScreen extends StatefulWidget {
  const PlotPolygonScreen({super.key});

  @override
  State<PlotPolygonScreen> createState() => _PlotPolygonScreenState();
}

class _PlotPolygonScreenState extends State<PlotPolygonScreen> {
  final Completer<gmap.GoogleMapController> _controller = Completer();
  final BackgroundLocationService _backgroundService =
      BackgroundLocationService();
  final Location _location =
      Location(); // Keep this only for initial location check

  // Map related
  Set<gmap.Polygon> _polygons = {};
  List<gmap.LatLng> _polygonPoints = [];
  gmap.GoogleMapController? _mapController;
  gmap.LatLng? _startingPoint;

  // Core states
  bool _showErrorUI = false;
  bool _isMapInitialized = false;
  bool _isTracking = false;
  bool _isTrackEnd = false;

  // UI states
  bool _showCompleteButton = false;
  bool _showUndoButton = false;
  bool _showLocationButton = false;
  bool _isSnackbarShown = false;

  // Dialog tracking
  bool _hasShownLocationDialog = false;
  bool _hasShownBackgroundDialog = false;

  // UI optimization timers
  Timer? _cameraDebounceTimer;
  Timer? _polygonUpdateTimer;
  bool _needsPolygonUpdate = false;

  // Tracking data
  List<String> _imagePaths = [];
  List<LocationData> _locationDataList = [];
  double? _calculatedArea;
  double? _calculatedPerimeter;

  @override
  void initState() {
    super.initState();
    _checkLocationService();
  }

  Future<void> _checkLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();

      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
      }

      if (!mounted) return;
      setState(() {
        _showErrorUI = !serviceEnabled;
      });

      if (serviceEnabled) {
        await _requestLocationPermissions();
      } else {
        _showLocationServiceSnackBar();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showErrorUI = true;
      });
    }
  }

  Future<void> _requestLocationPermissions() async {
    // First request foreground location
    final status = await Permission.location.request();

    if (status.isGranted || status.isLimited) {
      await _initializeMap();
    } else if (status.isDenied) {
      setState(() => _showErrorUI = true);
      _showLocationDeniedSnackBar();
    } else if (status.isPermanentlyDenied) {
      setState(() => _showErrorUI = true);
      _showSettingsDialog();
    }
  }

  void _showLocationServiceSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location service is required for maps to load'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  void _showLocationDeniedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location permission is required for maps to load'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    if (!mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To enable tracking in the background, please allow the app to access location all the time.\n\nSteps to enable location permissions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('1. Click - "Open Settings"'),
                const Text('2. Go to "App Permissions"'),
                const Text('3. Tap on "Location"'),
                const Text('4. Select "Allow all the time"'),
                const Text('5. Return to the app'),
                const Text('6. Restart Tracking'),
              ],
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
                  // Check permission status after returning from settings
                  final status = await Permission.location.status;
                  if (status.isDenied || status.isPermanentlyDenied) {
                    return;
                  }
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  Future<void> _initializeMap() async {
    try {
      // Check and request location permissions if needed
      await _requestLocationPermission();

      // After permissions are granted, mark that we need to update the map
      if (mounted) {
        setState(() {
          _isMapInitialized = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showErrorUI = true;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    var permissionStatus = await Permission.location.status;

    if (permissionStatus.isDenied && !_hasShownLocationDialog) {
      permissionStatus = await Permission.location.request();
      _hasShownLocationDialog = true;

      if (permissionStatus.isDenied) {
        if (!mounted) return;
        setState(() {
          _showErrorUI = true;
        });
        return;
      }
    }

    if (permissionStatus.isPermanentlyDenied) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text(
              "Location permission is required for tracking. Please enable it in Settings."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
                // Check permission status after returning from settings
                final status = await Permission.location.status;
                if (status.isDenied) {
                  if (!mounted) return;
                  setState(() {
                    _showErrorUI = true;
                  });
                  return;
                }
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
      return;
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      final currentLocation =
          gmap.LatLng(locationData.latitude!, locationData.longitude!);

      if (!mounted) return;

      // Get the controller once it's available
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        _mapController = controller;

        // Clear any existing polygons to force refresh
        setState(() {
          _polygons = {};
        });

        // Animate to current location with debounce
        _animateToLocation(currentLocation);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _animateToLocation(gmap.LatLng location) {
    if (!mounted || _mapController == null) return;

    _cameraDebounceTimer?.cancel();
    _cameraDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _mapController!.animateCamera(
        gmap.CameraUpdate.newCameraPosition(
          gmap.CameraPosition(
            target: location,
            zoom: 20.0, // Increased zoom level for better detail
          ),
        ),
      );
    });
  }

  Future<void> _startTracking() async {
    try {
      // Check background permission status first
      var backgroundStatus = await Permission.locationAlways.status;

      // Show first dialog only if permission is not granted and hasn't been shown before
      if (!backgroundStatus.isGranted && !_hasShownBackgroundDialog) {
        if (!mounted) return;
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
                'This app needs additional permissions to track regions in the background.\n'
                'Please select "Allow all the time" in the next screen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  // Enable background permission
                  backgroundStatus = await Permission.locationAlways.request();
                  if (!mounted) return;
                  navigator.pop();
                },
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        );

        setState(() => _hasShownBackgroundDialog = true);
      }

      if (!backgroundStatus.isGranted) {
        if (!mounted) return;

        // Show second dialog with detailed settings instructions
        await _showSettingsDialog();
        return;
      }

      // Initialize background service
      await _backgroundService.initialize();

      // Start tracking with background service
      await _backgroundService.startTracking((locationData) {
        if (!mounted) return;

        // If actively tracking, update polygon
        if (_isTracking) {
          final newPoint =
              gmap.LatLng(locationData.latitude!, locationData.longitude!);

          setState(() {
            // Store starting point for the first point only if we're starting fresh
            if (_polygonPoints.isEmpty) {
              _startingPoint = newPoint;
            }

            _polygonPoints.add(newPoint);
            _needsPolygonUpdate = true;
          });

          // Update polygon with debounce
          _updatePolygon();

          // Animate camera to new location
          _animateToLocation(newPoint);

          // Check if we can complete the polygon
          if (_startingPoint != null) {
            _checkDistanceToStart();
          }
        }
      });

      setState(() {
        _isTracking = true;
        _showCompleteButton = false;
      });
    } catch (e) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: Text("Failed to start tracking: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _updatePolygon() {
    if (!_needsPolygonUpdate) return;

    _polygonUpdateTimer?.cancel();
    _polygonUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _polygonPoints.isNotEmpty) {
        setState(() {
          _polygons = {
            gmap.Polygon(
              polygonId: const gmap.PolygonId('shade'),
              points: _polygonPoints,
              strokeColor: Theme.of(context).colorScheme.secondary,
              strokeWidth: 2,
              fillColor: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 128),
            ),
          };
        });
        _needsPolygonUpdate = false;
      }
    });
  }

  void _checkDistanceToStart() {
    if (_isSnackbarShown || _startingPoint == null || _polygonPoints.isEmpty) {
      return; // Prevent showing snackbar multiple times or if points are not set
    }

    // Only check for completion if we have enough points
    if (_polygonPoints.length < AppConfigParameters.minPolygonPoints) {
      return;
    }

    final currentPoint = _polygonPoints.last;
    var distance = _calculateDistance(_startingPoint!, currentPoint);

    if (distance <= AppConfigParameters.minPolygonCloseDistance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can now complete the polygon.'),
        ),
      );
      setState(() {
        _showCompleteButton = true;
        _isSnackbarShown = true;
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
    if (_polygonPoints.length < 3) {
      // Need at least 3 points to form a polygon
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Need at least 3 points to form a polygon. Please continue tracking.'),
        ),
      );
      return;
    }

    // Stop tracking and clean up background service
    _backgroundService.stopTracking().then((_) => _backgroundService.dispose());

    setState(() {
      _polygonPoints.first = _polygonPoints.last;
      _isTracking = false;
      _isTrackEnd = true;
      _showUndoButton = true;

      // Only create polygon if we have points
      if (_polygonPoints.isNotEmpty) {
        _polygons = {
          gmap.Polygon(
            polygonId: const gmap.PolygonId('shade'),
            points: _polygonPoints,
            strokeColor: Theme.of(context).colorScheme.secondary,
            strokeWidth: 2,
            fillColor:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 128),
          ),
        };
      }

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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: (_isTracking || _isTrackEnd) ? false : true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Stop tracking and clean up background service
          await _backgroundService.stopTracking();
          await _backgroundService.dispose();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: AppConfigParameters.headerHeight,
                child: const Header(),
              ),
              SizedBox(
                height: AppConfigParameters.titleHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 40, 0),
                    child: Text(
                      'Measure by GPS',
                      style: TextStyle(
                        fontFamily: 'Gilroy-SemiBold',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // Map container with fixed height
              Container(
                height: screenHeight * AppConfigParameters.mapHeightRatio,
                margin: const EdgeInsets.fromLTRB(30, 5, 30, 15),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: _buildMap(context),
              ),
              // Bottom buttons with fixed height
              Container(
                height: screenHeight * AppConfigParameters.buttonHeightRatio,
                padding: const EdgeInsets.fromLTRB(30, 5, 30, 10),
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
                            _showCompleteButton = false;
                            _showUndoButton = false;
                            _imagePaths = [];
                            _locationDataList = [];
                            _polygonPoints = [];
                            _isSnackbarShown = false;
                            _polygons = {};
                            _isTrackEnd = false;
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(width: 15),
                    _buildTrackingButton(context),
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
    if (_showErrorUI) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to load maps',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  if (!_hasShownLocationDialog) {
                    _checkLocationService();
                  } else {
                    _openLocationSettings();
                  }
                },
                child: Text(
                  _hasShownLocationDialog ? 'Open Settings' : 'Retry',
                  style: TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isMapInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingAnimationWidget.dotsTriangle(
                color: Theme.of(context).colorScheme.secondary,
                size: 30,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Map...',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        gmap.GoogleMap(
          mapType: gmap.MapType.satellite,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          initialCameraPosition: const gmap.CameraPosition(
            target: gmap.LatLng(18.8137326, 82.7001428),
            zoom: 11.0,
          ),
          onMapCreated: (gmap.GoogleMapController controller) {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
              _mapController = controller;
              _showLocationButtonMethod();

              // If we already requested permissions before map was created, get location immediately
              if (_isMapInitialized) {
                _getCurrentLocation();
              } else {
                // If map is created but permissions not yet requested, request them now
                _requestLocationPermission();
              }
            }
          },
          polygons: _polygons,
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
              heroTag: "complete_button",
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
              heroTag: "undo_button",
              backgroundColor: Theme.of(context).colorScheme.secondary,
              onPressed: () {
                setState(() {
                  // Keep the first point and continue tracking from the last point
                  _isTracking = true;
                  _isTrackEnd = false;
                  _showUndoButton = false;
                  _showCompleteButton = false;
                  _isSnackbarShown = false;
                });
                // Restart tracking
                _startTracking();
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
            top: 16,
            right: 66,
            width: 40,
            height: 40,
            child: FloatingActionButton(
              heroTag: "camera_button",
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
        if (_imagePaths.isNotEmpty &&
            _isTracking) // Show the number only if there are images
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
              heroTag: "location_button",
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onPressed: () async {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Getting your current location...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  final location = Location();
                  final locationData = await location.getLocation();
                  final currentLocation = gmap.LatLng(
                      locationData.latitude!, locationData.longitude!);

                  if (_controller.isCompleted) {
                    final controller = await _controller.future;
                    controller.animateCamera(
                        gmap.CameraUpdate.newCameraPosition(gmap.CameraPosition(
                            target: currentLocation, zoom: 20)));
                  }
                } catch (e) {
                  _showErrorSnackBar('Error getting location: $e');
                }
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
                    // Stop tracking before navigating
                    _backgroundService.stopTracking();

                    // Navigate to Next Page with area, perimeter, and polygon points
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShadeDetailsScreen(
                          area: _calculatedArea ?? 0.0,
                          perimeter: _calculatedPerimeter ?? 0.0,
                          polygonPoints: _polygonPoints,
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
    bool isDisabled = false,
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
              : () {
                  if (!_isTrackEnd) {
                    _backgroundService
                        .stopTracking()
                        .then((_) => _backgroundService.dispose());
                  }
                  if (_isTrackEnd && text == 'Clear') {
                    setState(() {
                      _showCompleteButton = false;
                      _showUndoButton = false;
                      _imagePaths = [];
                      _locationDataList = [];
                      _polygonPoints = [];
                      _isSnackbarShown = false;
                      _polygons = {};
                      _isTrackEnd = false; // Reset track end state
                      _isTracking = false; // Reset tracking state
                    });
                  } else {
                    onTap();
                  }
                },
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

  Future<void> _openLocationSettings() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location service is required to load maps'),
        duration: Duration(seconds: 3),
      ),
    );
    await openAppSettings();
  }

  @override
  void dispose() {
    _cameraDebounceTimer?.cancel();
    _polygonUpdateTimer?.cancel();
    // Stop tracking and clean up background service
    if (_isTracking || _isTrackEnd) {
      _backgroundService
          .stopTracking()
          .then((_) => _backgroundService.dispose());
    }
    if (_mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }
}
