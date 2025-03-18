import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coffee_mapper/widgets/header.dart';
import 'package:coffee_mapper/widgets/custom_dropdown.dart';
import 'package:coffee_mapper/app_constants.dart';
import 'package:coffee_mapper/utils/area_formatter.dart';
import 'package:coffee_mapper/utils/logger.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:location/location.dart';

import '../widgets/image_modal.dart';

class ShadeDetailsScreen extends StatefulWidget {
  final double area;
  final double perimeter;
  final List<gmap.LatLng> polygonPoints;
  final List<String> shadeImagePaths;
  final List<LocationData> shadeImageLocations;

  const ShadeDetailsScreen({
    super.key,
    required this.area,
    required this.perimeter,
    required this.polygonPoints,
    required this.shadeImagePaths,
    required this.shadeImageLocations,
  });

  @override
  State<ShadeDetailsScreen> createState() => _ShadeDetailsScreenState();
}

class _ShadeDetailsScreenState extends State<ShadeDetailsScreen> {
  final _logger = AppLogger.getLogger('ShadeDetailsScreen');

  String? _selectedDistrict;
  String? _selectedTehsil;
  String? _selectedPanchayat;
  String? _selectedVillage;
  String? _selectedCategory;
  bool _dataInTextField = false;
  final _regionNameController = TextEditingController();
  final Completer<gmap.GoogleMapController> _controller = Completer();
  gmap.GoogleMapController? _mapController;
  final _formKey = GlobalKey<FormState>();

  List<String> _districtOptions = []; // List to store district names
  List<String> _subdivisionOptions = []; // List to store subdivision names
  List<String> _panchayatOptions = []; // List to store panchayat names
  List<String> _villageOptions = []; // List to store village names
  Map<String, List<String>> _subdivisionsCache = {};
  Map<String, List<String>> _panchayatsCache = {};

  final List<String> _boundaryCaptureMediaURLs = [];

  // ignore: undefined_class
  late StreamSubscription<DocumentSnapshot> _dropdownSubscription;
  // ignore: undefined_class
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;
  bool _noBack = false;

  bool _hideSaveField = false;

  String _imgURL = "NA";

  @override
  void initState() {
    super.initState();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivitySubscription
        .cancel(); // Cancel the subscription when the widget is disposed
    _dropdownSubscription.cancel();
    super.dispose();
  }

  //Listen to connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> result) {
    //print(result);
    setState(() {
      _isOffline = result[0] == ConnectivityResult.none;

      if (_isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('‼️Offline Alert - Cannot fetch dropdown data!'),
          ),
        );
      }

      if (!_isOffline) {
        _startListeningForDropdownData();
      }
    });
  }

  // Function to start listening for dropdown data
  void _startListeningForDropdownData() {
    _dropdownSubscription = FirebaseFirestore.instance
        .collection('appData')
        .doc('regionData')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _districtOptions =
              List<String>.from(snapshot.data()?['districts'] as List);
          _districtOptions
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          _subdivisionsCache = (snapshot.data()?['blocks'] as Map)
              .map((key, value) => MapEntry(key, List<String>.from(value)));
          _subdivisionOptions = _subdivisionsCache.keys.toList();
          _subdivisionOptions
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          _panchayatsCache = (snapshot.data()?['panchayats'] as Map)
              .map((key, value) => MapEntry(key, List<String>.from(value)));
        });
      }
    });
  }

  // Function to fetch panchayats for a given subdivision from Firestore
  Future<void> _fetchPanchayats(String subdivisionName) async {
    try {
      if (_subdivisionsCache.containsKey(subdivisionName)) {
        setState(() {
          _panchayatOptions = _subdivisionsCache[subdivisionName]!;
          _panchayatOptions
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        });
        return;
      }
    } catch (e) {
      _logger.warning('Error fetching panchayats', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data from database'),
        ),
      );
    }
  }

// Function to fetch villages for a given subdivision from Firestore
  Future<void> _fetchVillages(String panchayatName) async {
    try {
// 1. Check if the villages for this subdivision are in the cache
      if (_panchayatsCache.containsKey(panchayatName)) {
        setState(() {
          _villageOptions = _panchayatsCache[panchayatName]!;
          _villageOptions
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        });
        return; // No need to fetch from Firestore
      }
    } catch (e) {
      _logger.warning('Error fetching villages', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data from database'),
        ),
      );
    }
  }

  // Function to save data to Firestore
  Future<void> _saveShadeDataToFirestore() async {
    /*
    if(_isOffline) {
      await _saveShadeDataToFirestore();
      return;
    }

     */

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser!;

      if (widget.shadeImagePaths.isNotEmpty) {
        for (int indexCounter = 0;
            indexCounter < widget.shadeImagePaths.length;
            indexCounter++) {
          final file = File(widget.shadeImagePaths[indexCounter]);
          final storageRef = FirebaseStorage.instance.ref().child(
              "plantations/${_regionNameController.text}/boundaryImages/${widget.shadeImageLocations[indexCounter].latitude}_${widget.shadeImageLocations[indexCounter].longitude}.jpg");

          await storageRef.putFile(file);
          final downloadUrl = await storageRef.getDownloadURL();

          if (!mounted) return;
          setState(() {
            _boundaryCaptureMediaURLs.add(downloadUrl);
          });
        }
      }

      if (_imgURL == "NA") {
        await _captureMapImage();
      }

      final regionData = {
        'district': _selectedDistrict,
        'block': _selectedTehsil,
        'panchayat': _selectedPanchayat,
        'village': _selectedVillage,
        'regionName': _regionNameController.text,
        'regionCategory': _selectedCategory,
        'savedOn': FieldValue.serverTimestamp(),
        'updatedOn': FieldValue.serverTimestamp(),
        'savedBy': user.email,
        'mapImageUrl': _imgURL,
        'boundaryImageURLs': _boundaryCaptureMediaURLs,
        'area': widget.area,
        'perimeter': widget.perimeter,
        'polygonPoints': widget.polygonPoints
            .map((point) => '${point.latitude},${point.longitude}')
            .toList(),
        'surveyStatus': false,
      };
      final regionInsightsData = {
        'savedOn': FieldValue.serverTimestamp(), // Add timestamp field
        'savedBy': user.email, // Add username field (using email for now)
        'updatedOn': FieldValue.serverTimestamp(),
        'surveyStatus': false,
        'regionCategory': _selectedCategory,
        'shadeType': null,
        'plotNumber': null,
        'khataNumber': null,
        'plantationYear': null,
        'beneficiaries': null,
        'agencyName': null,
        'averageYield': null,
        'plantVarieties': null,
        'survivalPercentage': null,
        'averageHeight': null,
        'mediaURLs': null,
      };

      String documentName = '${DateTime.now().millisecondsSinceEpoch.toString()}_${_regionNameController.text.split(' ').join("_")}';

      await firestore
          .collection('savedRegions')
          .doc(documentName)
          .set(regionData)
          .onError((e, _) => _logger.severe('Error writing document', e));

      await firestore
          .collection('savedRegions')
          .doc(documentName)
          .collection('regionInsights')
          .doc("latestInformation")
          .set(regionInsightsData)
          .onError((e, _) => _logger.severe('Error writing document', e));

      setState(() {
        _noBack = true;
      });
    } catch (e) {
      _logger.severe('Error saving data to Firestore', e);
      rethrow; // Rethrow the error to be caught by the caller
    }
  }

  // Function to capture the map image
  Future<void> _captureMapImage() async {
    try {
      final gmap.GoogleMapController controller = await _controller.future;
      // ignore: undefined_class
      final Uint8List? imageBytes = await controller.takeSnapshot();

      if (imageBytes != null) {
        // 1. Create a unique filename for the image
        final String imageName =
            '/plantations/${(_regionNameController.text.isNotEmpty) ? _regionNameController.text : "autoSaves"}/regionMiniMap/${(_regionNameController.text.isNotEmpty) ? _regionNameController.text : "regionShadeImage_autosave"}_${DateTime.now().millisecondsSinceEpoch}.png';

        // 2. Upload the image to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child(imageName);
        final uploadTask = storageRef.putData(imageBytes);
        await uploadTask;

        // 3. Get the download URL of the uploaded image
        final imgURL = await storageRef.getDownloadURL();

        if (!mounted) return;
        setState(() {
          _imgURL = imgURL;
        });
      }
    } catch (e) {
      _logger.warning('Error capturing map image', e);
      // Handle the error appropriately (e.g., display an error message)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error capturing map image')),
      );
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: (_noBack) ? true : false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: const Text(
                  'Shade mapped successfully!',
                  style: TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 5, 30, 20),
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
                      height: MediaQuery.of(context).size.height * 0.28,
                      child: _buildMap(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 20),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: _buildSaveFormFields(context),
                      ), // Call the new widget
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

// Widget for the map
  Widget _buildMap(BuildContext context) {
    gmap.LatLng center = _calculatePolygonCenter(widget.polygonPoints);
    double zoomLevel = (widget.area < 5)
        ? 20.8
        : ((widget.area < 10)
            ? 20
            : ((widget.area < 50)
                ? 19.2
                : ((widget.area < 100)
                    ? 19
                    : ((widget.area < 1000) ? 18.2 : 16.75))));

    double offCenterValue = (widget.area < 5)
        ? 0.000011
        : ((widget.area < 10)
            ? 0.00003
            : ((widget.area < 50)
                ? 0.00008
                : ((widget.area < 100)
                    ? 0.0001
                    : ((widget.area < 1000) ? 0.00015 : 0.0005))));

    gmap.LatLng offCenter =
        gmap.LatLng(center.latitude - offCenterValue, center.longitude);

    return Stack(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.25,
          child: gmap.GoogleMap(
            mapType: gmap.MapType.satellite,
            onMapCreated: (gmap.GoogleMapController controller) async {
              _mapController = controller;

              // Calculate bounds and move camera to center the polygon
              gmap.LatLngBounds bounds = _getBounds(widget.polygonPoints);
              _mapController!.animateCamera(
                gmap.CameraUpdate.newLatLngBounds(bounds, 70), // Add padding
              );

              _controller.complete(controller);

              //Future.delayed(const Duration(milliseconds: 1000), () async {
              //  await _captureMapImage();
              //});
            },
            initialCameraPosition: gmap.CameraPosition(
              target: offCenter,
              zoom: zoomLevel,
            ),
            polygons: {
              gmap.Polygon(
                polygonId: const gmap.PolygonId('shade'),
                points: widget.polygonPoints,
                strokeColor: Theme.of(context).colorScheme.secondary,
                strokeWidth: 2,
                fillColor:
                    Theme.of(context).colorScheme.secondary.withAlpha(128),
              ),
            },
            //style: _mapStyle,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false, // Hide zoom buttons
// Make the map non-interactive
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            scrollGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
        ),
        Positioned(
          bottom: -1,
          left: -1,
          right: -1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.06,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Area: ${AreaFormatter.formatArea(widget.area)}',
                    style: const TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Perimeter: ${widget.perimeter.toStringAsFixed(2)} m',
                    style: const TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

// Helper function to calculate the center point of a polygon
  gmap.LatLng _calculatePolygonCenter(List<gmap.LatLng> points) {
    double latSum = 0.0;
    double lngSum = 0.0;
    for (final point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    return gmap.LatLng((latSum / points.length), (lngSum / points.length));
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

// Widget for the dropdown fields
  Widget _buildSaveFormFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
// District input
        _buildDropdown(
          context,
          label: 'District',
          hint: 'Select district',
          value: _selectedDistrict,
          items: _districtOptions, // Use fetched district options
          onChanged: (value) {
            setState(() {
              _selectedDistrict = value;
            });
          },
        ),
        const SizedBox(height: 30),
// Tehsil input
        _buildDropdown(
          context,
          label: 'Block',
          hint: 'Select block',
          value: _selectedTehsil,
          items: _subdivisionOptions, // Use fetched subdivision options
          onChanged: (value) {
            setState(() {
              _selectedTehsil = value;
              _selectedPanchayat = null; // Reset panchayats when block changes
              _panchayatOptions = []; // Clear Panchayat options
              _selectedVillage = null; // Reset village when tehsil changes
              _villageOptions = [];
            });
            if (value != null) {
              _fetchPanchayats(
                  value); // Fetch panchayats when a block is selected
            }
          },
        ),
        const SizedBox(height: 30),
// Gram Panchayat input
        _buildDropdown(
          context,
          label: 'Panchayat',
          hint: 'Select gram panchayat',
          value: _selectedPanchayat,
          items: _panchayatOptions, // Use fetched village options <- CHANGE IT
          onChanged: (value) {
            setState(() {
              _selectedPanchayat = value;
              _selectedVillage = null; // Reset village when tehsil changes
              _villageOptions = []; // Clear village options
            });
            if (value != null) {
              _fetchVillages(value); // Fetch villages when a tehsil is selected
            }
          },
        ),
        const SizedBox(height: 30),
        // Village input
        _buildDropdown(
          context,
          label: 'Village',
          hint: 'Select village',
          value: _selectedVillage,
          items: _villageOptions, // Use fetched village options
          onChanged: (value) {
            setState(() {
              _selectedVillage = value;
            });
          },
        ),
        const SizedBox(height: 30),
// Region name input
        _buildTextField(
          context,
          label: 'Plantation Name',
          hint: 'Enter name of the plantation',
          controller: _regionNameController,
        ),
        SizedBox(height: 30),
        // Category Input
        _buildDropdown(
          context,
          label: 'Plantation Category',
          hint: 'Select plantation category',
          value: _selectedCategory,
          items: [
            "Old Shade",
            "New Shade",
            "Non Bearing Coffee",
            "Bearing Coffee",
            "Private Plantation Coffee"
          ], // Category options
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
        SizedBox(height: 30),

        if (widget.shadeImagePaths.isNotEmpty) ...[
          Text(
            "Plantation Captures",
            style: TextStyle(
              fontFamily: 'Gilroy-SemiBold',
              fontSize: 16,
              color: Theme.of(context).highlightColor,
            ),
          ),
          SizedBox(height: 7),
          for (int indexCounter = 0;
              indexCounter < widget.shadeImagePaths.length;
              indexCounter++)
            ListTile(
              onTap: () async {
                //print(widget.shadeImagePaths[indexCounter]);
                showDialog(
                  context: context,
                  builder: (context) => ImageModal(
                      mediaPath: widget.shadeImagePaths[indexCounter]),
                );
              },
              title: Text(
                "${widget.shadeImageLocations[indexCounter].latitude}_${widget.shadeImageLocations[indexCounter].longitude}.jpg",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
              dense: true,
              visualDensity: VisualDensity(vertical: -3),
              selectedTileColor: AppConstants.scaffoldColor(context),
              focusColor: AppConstants.scaffoldColor(context),
              hoverColor: AppConstants.scaffoldColor(context),
              minVerticalPadding: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    widget.shadeImagePaths.removeAt(indexCounter);
                    widget.shadeImageLocations.removeAt(indexCounter);
                  });
                },
              ),
            ),
        ],
        SizedBox(height: 30),
        if (!_hideSaveField)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomButton(
                context,
                text: 'Back',
                fill: false,
                isDisabled: false,
                onTap: () async {
                  final navigatorContext = context;
                  if (_imgURL != "NA" && !_isOffline) {
                    await FirebaseStorage.instance.refFromURL(_imgURL).delete();
                    _imgURL = "NA";
                  }
                  if (navigatorContext.mounted) {
                    Navigator.pop(navigatorContext);
                  }
                },
              ),
              SizedBox(width: 10),
              _buildBottomButton(
                context,
                text: 'Save & exit',
                fill: true,
                isDisabled: _selectedDistrict == null ||
                    _selectedTehsil == null ||
                    _selectedVillage == null ||
                    _selectedPanchayat == null ||
                    _selectedCategory == null ||
                    !_dataInTextField, // Disable if any field is empty
                onTap: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _noBack = true;
                    });
                    // 1. Show a progress indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          Center(child: CircularProgressIndicator()),
                    );

                    // 2. Save the data to Firestore
                    final dialogContext = context;
                    _saveShadeDataToFirestore().then((_) {
                      // 3. Hide the progress indicator
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);

                        // 4. Show a success message
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: const Text('Region saved successfully!'),
                            backgroundColor: Theme.of(dialogContext).colorScheme.error,
                          ),
                        );

                        // 5. Navigate back to the previous screen
                        Navigator.pushNamedAndRemoveUntil(
                            dialogContext, '/main_menu', (route) => false);
                      }
                    }).catchError((error) {
                      _logger.warning('Error saving data to Firestore: $error');
                      if (dialogContext.mounted) {
                        // 6. Hide the progress indicator
                        Navigator.pop(dialogContext);

                        // 7. Show an error message
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Error saving shade data. Please try again.'),
                            backgroundColor: Theme.of(dialogContext).colorScheme.error,
                          ),
                        );
                      }
                    });
                  }
                },
              ),
            ],
          ),
      ],
    );
  }

// Widget for the dropdown fields
// Widget for the dropdown fields
  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return CustomDropdown(
      // Use the new CustomDropdown widget
      label: label,
      hint: hint,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

// Widget for the text field
  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Gilroy-SemiBold',
            fontSize: 19,
          ),
        ),
        SizedBox(height: 4),
        TextFormField(
          onTap: () {
            setState(() {
              _hideSaveField = true;
            });
          },
          onTapOutside: (pdEvent) {
            setState(() {
              _hideSaveField = false;
            });
          },
          onEditingComplete: () {
            setState(() {
              _hideSaveField = false;
            });
          },
          controller: controller,
          onChanged: (value) {
            if (value.isNotEmpty) {
              setState(() {
                _dataInTextField = true;
              });
            } else {
              setState(() {
                _dataInTextField = false;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Region Name cannot be empty!';
            }
            if (value.length < 3) {
              return 'Region Name needs to have at least 3 characters';
            }
            if (value.length > 15) {
              return 'Region Name cannot be more than 15 characters';
            }
            return null; // Return null if the input is valid
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Gilroy-Medium',
              fontSize: 15,
              color: Theme.of(context).colorScheme.secondary,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error, width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }

// Widget for the bottom buttons
  Widget _buildBottomButton(
    BuildContext context, {
    required String text,
    required bool fill,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    fill = (isDisabled) ? false : fill;
    return Expanded(
      child: SizedBox(
        height: AppConstants.buttonHeight(context),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (fill)
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: (fill) ? 0 : 2.5,
            ),
            textStyle: TextStyle(
              fontFamily: 'Gilroy-SemiBold',
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: (isDisabled) ? null : onTap,
          child: Text(
            text,
            style: TextStyle(
              color: (fill)
                  ? Theme.of(context).scaffoldBackgroundColor
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}
