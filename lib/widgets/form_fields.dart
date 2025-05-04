import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_mapper/app_constants.dart';
import 'package:coffee_mapper/providers/admin_provider.dart';
import 'package:coffee_mapper/utils/area_formatter.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'image_modal.dart';
import 'image_capture_widget.dart';
import 'video_capture_widget.dart';

class FormFields extends StatefulWidget {
  final DocumentSnapshot regionDocument;
  final DocumentSnapshot insightsDocument;
  final DocumentSnapshot formDropDownData;

  const FormFields({
    super.key,
    required this.regionDocument,
    required this.insightsDocument,
    required this.formDropDownData,
  });

  @override
  State<FormFields> createState() => _FormFieldsState();
}

class _FormFieldsState extends State<FormFields> {
  final _formKey = GlobalKey<FormState>();
  final _logger = AppLogger.getLogger('FormFields');

  final _plotNumberController = TextEditingController();
  final _khataNumberController = TextEditingController();
  final _survivalPercentController = TextEditingController();
  final _beneficiariesCountController = TextEditingController();
  final _treeHeightController = TextEditingController();
  final _yeildValueController = TextEditingController();

  String? _plantationYear;
  String? _regionCategory;
  String? _shadeType;
  String? _agencyValue;
  String? _elevation;
  String? _maxTemp;
  String? _slope;
  String? _ph;
  String? _aspect;
  List<String> _plantVariety = [];

  // Static dropdown values for new fields
  final List<String> _coffeeShadeTypes = [
    "Natural : 20 - 30",
    "Natural : 30 - 40",
    "Silveroak : 400 - 500",
    "Silveroak : 500 - 600"
  ];
  final List<String> _elevationValues = [
    "800m - 900m",
    "900m - 1000m",
    "1000m - 1100m"
  ];
  final List<String> _maxTempValues = ["30°C - 35°C", "35°C - 40°C"];
  final List<String> _slopeValues = ["30° - 45°", "45° - 60°"];
  final List<String> _phValues = ["5 - 6", "6 - 7", "7 - 8"];
  final List<String> _aspectValues = [
    "N",
    "NE",
    "E",
    "SE",
    "S",
    "SW",
    "W",
    "NW"
  ];

  List _mediaList = [];
  bool _isImageUploading = false;
  bool _isImageDeleting = false;
  int _totalMediaCount = 0;

  bool _isSideLabelActive = false;
  bool _isReadonlySideLabelField = true;
  final FocusNode _focusNodeSideLabelField = FocusNode();

  bool _isShade = false;

  bool _areFieldsEditable = false;
  final _areaController = TextEditingController();
  final _boundaryController = TextEditingController();

  String _formatDate(Timestamp timestamp) {
    try {
      final dateTime = timestamp.toDate();
      final day = dateTime.day.toString().padLeft(2, '0');
      //final month = DateFormat('MMM').format(dateTime);
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year
          .toString()
          .substring(2); // Get last two digits of the year
      return '$day-$month-$year';
    } catch (e) {
      _handleDateFormatError(e);
      return 'Invalid Date';
    }
  }

  void _handleDateFormatError(e) {
    _logger.warning('Error formatting date: $e');
  }

  void _handleImageDelete(String message, [dynamic error]) {
    final snackbarContext = context;
    if (!mounted) return;
    if (snackbarContext.mounted) {
      ScaffoldMessenger.of(snackbarContext).showSnackBar(
        SnackBar(
          content: Text(message.isNotEmpty ? message : 'Error deleting image!'),
        ),
      );
    }
    if (error != null) {
      _logger.warning('Error deleting image: $error');
    }
  }

  void _handleFirestoreError(String operation, dynamic error) {
    _logger.severe('Error $operation: $error');
  }

  @override
  void initState() {
    super.initState();
    var regionDoc = widget.regionDocument.data() as Map;
    var insightsDoc = widget.insightsDocument.data() as Map;

    // Initialize area and boundary controllers
    _areaController.text = (regionDoc['area'] / AreaFormatter.hectareConversion)
        .toStringAsFixed(3);
    _boundaryController.text = regionDoc['perimeter'].toStringAsFixed(2);

    setState(() {
      _regionCategory = insightsDoc['regionCategory'].toString();
      _isShade = regionDoc['regionCategory']
          .toString()
          .toLowerCase()
          .contains("shade");

      // Set values from insights document
      if (insightsDoc['shadeType'] != null) {
        _shadeType = insightsDoc['shadeType'];
      }
      if (insightsDoc['plotNumber'] != null) {
        _plotNumberController.text = insightsDoc['plotNumber'].toString();
      }
      if (insightsDoc['khataNumber'] != null) {
        _khataNumberController.text = insightsDoc['khataNumber'].toString();
      }
      if (insightsDoc['plantationYear'] != null) {
        _plantationYear = insightsDoc['plantationYear'].toString();
      }
      if (insightsDoc['beneficiaries'] != null) {
        _beneficiariesCountController.text =
            insightsDoc['beneficiaries'].toString();
      }
      if (insightsDoc['agencyName'] != null) {
        _agencyValue = insightsDoc['agencyName'];
      }
      if (insightsDoc['averageYield'] != null) {
        _yeildValueController.text = insightsDoc['averageYield'].toString();
      }
      if (insightsDoc['plantVarieties'] != null) {
        _plantVariety = List<String>.from(insightsDoc['plantVarieties']);
      }
      if (insightsDoc['survivalPercentage'] != null) {
        _survivalPercentController.text =
            insightsDoc['survivalPercentage'].toString();
      }
      if (insightsDoc['averageHeight'] != null) {
        _treeHeightController.text = insightsDoc['averageHeight'].toString();
      }
      if (insightsDoc['mediaURLs'] != null) {
        _mediaList = List<String>.from(insightsDoc['mediaURLs']);
        _totalMediaCount = _mediaList.length;
      }

      // Initialize new fields
      if (insightsDoc['elevation'] != null) {
        _elevation = insightsDoc['elevation'];
      }
      if (insightsDoc['slope'] != null) {
        _slope = insightsDoc['slope'];
      }
      if (insightsDoc['maxTemp'] != null) {
        _maxTemp = insightsDoc['maxTemp'];
      }
      if (insightsDoc['ph'] != null) {
        _ph = insightsDoc['ph'];
      }
      if (insightsDoc['aspect'] != null) {
        _aspect = insightsDoc['aspect'];
      }
    });
  }

  Future<void> _handleFieldClick(BuildContext context) async {
    final isSuperAdmin = context.read<AdminProvider>().isSuperAdmin;
    if (!isSuperAdmin || _areFieldsEditable) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Critical Fields"),
        content:
            Text("Do you want to enable editing of area and boundary fields?"),
        actions: [
          TextButton(
            child: Text("No"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text("Yes"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _areFieldsEditable = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = context.watch<AdminProvider>().isSuperAdmin;

    return Form(
      //autovalidateMode: AutovalidateMode.onUserInteraction,
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Region Name : ',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 20,
                  color: Theme.of(context).highlightColor,
                ),
              ),
              Text(
                '${widget.regionDocument['regionName']}',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                (_isShade) ? 'Shade Type : ' : 'Plantation Type : ',
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 18,
                  color: Theme.of(context).highlightColor,
                ),
              ),
              Expanded(
                child: Text(
                  '${widget.insightsDocument['regionCategory']}',
                  style: TextStyle(
                    fontFamily: 'Gilroy-SemiBold',
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Region Boundary and Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: isSuperAdmin
                          ? () => _handleFieldClick(context)
                          : null,
                      child: _buildFormField(
                        context,
                        fieldName: 'Boundary',
                        fieldType:
                            _areFieldsEditable ? 'textInput' : 'fixedValue',
                        fieldValue:
                            '${widget.regionDocument['perimeter'].toStringAsFixed(2)} m',
                        dataType: 'double',
                        trailingText: 'm',
                        controller: _boundaryController,
                        fixedValueFontSize: 22.5,
                      ),
                    ),
                    InkWell(
                      onTap: isSuperAdmin
                          ? () => _handleFieldClick(context)
                          : null,
                      child: _buildFormField(
                        context,
                        fieldName: 'Area',
                        fieldType:
                            _areFieldsEditable ? 'textInput' : 'fixedValue',
                        fieldValue: AreaFormatter.formatArea(
                            widget.regionDocument['area'], false),
                        dataType: 'double',
                        trailingText: 'ha',
                        controller: _areaController,
                        fixedValueFontSize: 22.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Environmental Data
                Center(
                  child: Text(
                    'Suitability Criteria Data',
                    style: TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 19,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                _buildFormField(
                  context,
                  fieldName: 'Elevation',
                  fieldType: 'dropDown',
                  fieldOptions: _elevationValues,
                  dense: true,
                  fieldValue: _elevation,
                  onChanged: (String? value) {
                    setState(() {
                      _elevation = value!;
                    });
                  },
                ),
                SizedBox(height: 15),
                _buildFormField(
                  context,
                  fieldName: 'Slope',
                  fieldType: 'dropDown',
                  fieldOptions: _slopeValues,
                  dense: true,
                  fieldValue: _slope,
                  onChanged: (String? value) {
                    setState(() {
                      _slope = value!;
                    });
                  },
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFormField(
                      context,
                      fieldName: 'Aspect',
                      fieldType: 'dropDown',
                      fieldOptions: _aspectValues,
                      dense: true,
                      fieldValue: _aspect,
                      onChanged: (String? value) {
                        setState(() {
                          _aspect = value!;
                        });
                      },
                    ),
                    _buildFormField(
                      context,
                      fieldName: 'Soil Acidity',
                      fieldType: 'dropDown',
                      fieldOptions: _phValues,
                      dense: true,
                      fieldValue: _ph,
                      onChanged: (String? value) {
                        setState(() {
                          _ph = value!;
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 15),
                _buildFormField(
                  context,
                  fieldName: 'Maximum Temperature',
                  fieldType: 'dropDown',
                  fieldOptions: _maxTempValues,
                  dense: true,
                  fieldValue: _maxTemp,
                  onChanged: (String? value) {
                    setState(() {
                      _maxTemp = value!;
                    });
                  },
                ),
                if (!_isShade) ...[
                  const SizedBox(height: 15),
                  // Shade Type for Coffee
                  _buildFormField(context,
                      fieldName: 'Shade Status : Plants Per Acre',
                      fieldType: 'dropDown',
                      fieldOptions: _coffeeShadeTypes,
                      dense: true,
                      fieldValue: _shadeType, onChanged: (String? value) {
                    setState(() {
                      _shadeType = value!;
                    });
                  }),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    (_isShade) ? 'Shade Data' : 'Coffee Plantation Data',
                    style: TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 19,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                //Shade Field
                if (_isShade) ...[
                  // Shade Type
                  _buildFormField(context,
                      fieldName: 'Shade Variety',
                      fieldType: 'dropDown',
                      fieldOptions: List<String>.from(
                          widget.formDropDownData['shadeType']),
                      validation: true,
                      dense: true,
                      fieldValue: _shadeType, onChanged: (String? value) {
                    setState(() {
                      _shadeType = value!;
                    });
                  }),
                  const SizedBox(height: 15),
                ],
                //Plot Number and Khata Number Data
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFormField(
                      context,
                      fieldName: 'Plot Number',
                      fieldType: 'textInput',
                      dataType: 'string',
                      dense: true,
                      controller: _plotNumberController,
                    ),
                    _buildFormField(
                      context,
                      fieldName: 'Khata Number',
                      fieldType: 'textInput',
                      dataType: 'string',
                      dense: true,
                      controller: _khataNumberController,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                //Platation Year and Beneficiery Data
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFormField(
                      context,
                      fieldName: 'Plantation Year',
                      fieldType: 'dateInputYear',
                      validation: true,
                      dense: true,
                    ),
                    _buildFormField(
                      context,
                      fieldName: 'Beneficiaries',
                      fieldType: 'textInput',
                      dataType: 'integer',
                      controller: _beneficiariesCountController,
                      dense: true,
                    )
                  ],
                ),
                const SizedBox(height: 15),
                //Tree Height and Survival Percent
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFormField(
                      context,
                      fieldName: 'Survival Percent',
                      fieldType: 'textInput',
                      dataType: 'double',
                      trailingText: '%',
                      validation: true,
                      dense: true,
                      controller: _survivalPercentController,
                    ),
                    _buildFormField(
                      context,
                      fieldName: 'Average Height',
                      fieldType: 'textInput',
                      dataType: 'double',
                      trailingText: 'ft',
                      validation: true,
                      dense: true,
                      controller: _treeHeightController,
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                //Coffee Field
                if (!_isShade) ...[
                  // Plant Variety
                  _buildFormField(
                    context,
                    fieldName: 'Plant Variety',
                    fieldType: 'multiSelect',
                    fieldOptions: List<String>.from(
                        widget.formDropDownData['plantVariety']),
                    validation: true,
                  ),
                  const SizedBox(height: 15),
                  //Yield/Hectare
                  _buildFormField(
                    context,
                    fieldName: 'Average Yield',
                    fieldType: 'textInput',
                    dataType: 'double',
                    trailingText: 'kg/hectare',
                    validation: true,
                    dense: true,
                    controller: _yeildValueController,
                  ),
                  const SizedBox(height: 15),
                ],

                //Agency
                _buildFormField(context,
                    fieldName: 'Implementing Agency',
                    fieldType: 'dropDown',
                    fieldOptions:
                        List<String>.from(widget.formDropDownData['agency']),
                    validation: true,
                    dense: true,
                    fieldValue: _agencyValue, onChanged: (String? value) {
                  setState(() {
                    _agencyValue = value!;
                  });
                }),
                const SizedBox(height: 15),
                // Region category
                _buildFormField(context,
                    fieldName: 'Update Plantation Category',
                    fieldType: 'dropDown',
                    fieldOptions: (_isShade)
                        ? ["New Shade", "Old Shade", "Pre Survey Shade"]
                        : [
                            "Bearing Coffee",
                            "Non Bearing Coffee",
                            "Pre Survey Coffee",
                            "Private Plantation Coffee"
                          ],
                    validation: true,
                    dense: true,
                    fieldValue: _regionCategory, onChanged: (String? value) {
                  setState(() {
                    _regionCategory = value!;
                  });
                }),
                const SizedBox(height: 40),
                // Media
                _buildFormField(
                  context,
                  fieldType: 'imageCapture',
                ),
              ],
            ),
          ),
          if (_mediaList.isNotEmpty) ...[
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "Uploaded Media",
                style: TextStyle(
                  fontFamily: 'Gilroy-SemiBold',
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            SizedBox(height: 1),
            for (int indexCounter = 0;
                indexCounter < _mediaList.length;
                indexCounter++)
              ListTile(
                onTap: !_isImageUploading
                    ? () {
                        //print(_imagePath);
                        showDialog(
                          context: context,
                          builder: (context) =>
                              ImageModal(mediaPath: _mediaList[indexCounter]),
                        );
                      }
                    : null,
                title: Text(
                  "${_mediaList[indexCounter].split('/').last.replaceAll('%2F', '*').split('*').last.split('?alt').first}",
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
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    try {
                      setState(() {
                        _isImageDeleting = true;
                      });

                      if ((widget.insightsDocument['mediaURLs'] == null ||
                              widget.insightsDocument['mediaURLs']
                                      .toList()
                                      .length ==
                                  0) &&
                          _mediaList.isNotEmpty) {
                        final storageRef = FirebaseStorage.instance
                            .refFromURL(_mediaList[indexCounter]);

                        await storageRef.delete();
                      }

                      setState(() {
                        _mediaList.removeAt(indexCounter);
                        _totalMediaCount--;
                        _isImageDeleting = false;
                      });

                      _handleImageDelete("Media Deleted Successfully!");
                    } catch (e) {
                      _handleImageDelete("", e);
                      final errorContext = context;
                      if (!mounted) return;
                      if (errorContext.mounted) {
                        ScaffoldMessenger.of(errorContext).showSnackBar(
                          const SnackBar(
                            content: Text('Error deleting image!'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 35),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 75,
                    width: MediaQuery.of(context).size.width * 0.35,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Gilroy-SemiBold',
                            fontSize: 23,
                          ),
                          side: BorderSide(
                            width: 3,
                            color: Theme.of(context).colorScheme.error,
                          )),
                      onPressed:
                          (_isImageUploading) ? null : _deleteImageAndBack,
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: SizedBox(
                    height: 75,
                    width: MediaQuery.of(context).size.width * 0.35,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            side: BorderSide(
                              width: 3,
                              color: Theme.of(context).colorScheme.error,
                            )),
                        textStyle: const TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 23,
                        ),
                      ),
                      onPressed:
                          (_isImageUploading) ? null : _saveButtonOnPressed,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: (_isImageUploading)
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteImageAndBack() async {
    final currentContext = context;
    if (_mediaList.isNotEmpty) {
      List savedCloudMedia = widget.insightsDocument['mediaURLs'].toList();
      if (widget.insightsDocument['mediaURLs'] == null ||
          savedCloudMedia.isEmpty ||
          savedCloudMedia != _mediaList) {
        for (int i = 0; i < _mediaList.length; i++) {
          if (!savedCloudMedia.contains(_mediaList[i])) {
            await FirebaseStorage.instance.refFromURL(_mediaList[i]!).delete();
            _mediaList.removeAt(i);
          }
        }
      }
    }
    if (!mounted) return;
    if (currentContext.mounted) {
      Navigator.pop(currentContext);
    }
  }

  void _saveButtonOnPressed() {
    if (_formKey.currentState!.validate()) {
      final dialogContext = context;
      // 1. Show a progress indicator
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 2. Save the data to Firestore
      _saveDataToFirestore().then((_) {
        if (!mounted) return;
        if (dialogContext.mounted) {
          // 3. Hide the progress indicator
          Navigator.pop(dialogContext);

          // 4. Show a success message
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(
              content: Text(
                  _isShade ? 'Shade Updated!' : 'Coffee Plantation Updated!'),
              backgroundColor: Theme.of(dialogContext).highlightColor,
            ),
          );

          // 5. Navigate back to the previous screen
          Navigator.pop(dialogContext);
        }
      }).catchError((error) {
        if (!mounted) return;
        if (dialogContext.mounted) {
          // 6. Hide the progress indicator
          Navigator.pop(dialogContext);

          // 7. Show an error message
          _handleFirestoreError('saving data to Firestore', error);
        }
      });
    }
  }

  // Widget for individual form-field builder
  Widget _buildFormField(
    BuildContext context, {
    required String fieldType,
    String fieldName = "NA",
    String? fieldValue,
    String? fieldSideLabel,
    List<String>? fieldOptions,
    Function(String?)? onChanged,
    TextEditingController? controller,
    String? dataType,
    bool validation = false,
    bool dense = false,
    bool truncate = false,
    String trailingText = "NA",
    double fixedValueFontSize = 24,
  }) {
    // Generate list of last 5 years for plantation year dropdown
    if (fieldType == 'dateInputYear') {
      final currentYear = DateTime.now().year;
      fieldOptions =
          List.generate(5, (index) => (currentYear - index).toString());
      onChanged = (String? newValue) {
        setState(() {
          _plantationYear = newValue;
        });
      };
      fieldValue = _plantationYear;
    }

    Widget content = Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.39,
        decoration: BoxDecoration(
          color: (fieldType == "fixedValue" || fieldType == "imageCapture")
              ? Theme.of(context).cardColor
              : Theme.of(context).dialogTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                (fieldName == "NA")
                    ? SizedBox(height: 0.1)
                    : Text(
                        fieldName,
                        style: const TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                SizedBox(height: 2.5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: switch (fieldType) {
                    'fixedValue' => fieldName == 'Area'
                        ? AreaFormatter.getAreaWidget(
                            context,
                            widget.regionDocument['area'],
                            fontSize: fixedValueFontSize,
                          )
                        : Text(
                            fieldValue!,
                            style: TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: fixedValueFontSize,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).highlightColor,
                            ),
                          ),
                    'textInput' => _buildTextInputField(context,
                        controller: controller!,
                        dataType: dataType!,
                        validation: validation,
                        dense: dense,
                        trailingText: trailingText),
                    'textInputSideLabel' => _buildTextInputWithSideLabelField(
                        context,
                        controller: controller!,
                        dataType: dataType!,
                        validation: validation,
                        dense: dense,
                        fieldSideLabel: fieldSideLabel!),
                    'dropDown' || 'dateInputYear' => _buildDropdownField(
                        context,
                        items: fieldOptions!,
                        value: fieldValue,
                        validation: validation,
                        truncate: truncate,
                        dense: dense,
                        onChanged: onChanged!),
                    'dateInput' => _buildDateInputField(
                        context,
                        controller: controller!,
                      ),
                    'imageCapture' => _buildImageCaptureField(
                        context,
                      ),
                    'multiSelect' => _buildMultiSelectField(
                        context,
                        items: fieldOptions!,
                        selectedItems: _plantVariety,
                        validation: validation,
                      ),
                    _ => const SizedBox(height: 10),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap the entire content in a GestureDetector if it's an image capture field
    if (fieldType == 'imageCapture') {
      return GestureDetector(
        onTap: (_isImageUploading) ? null : () => _showMediaPicker(context),
        child: content,
      );
    }

    return content;
  }

  // Widget for the dropdown fields
  Widget _buildDropdownField(
    BuildContext context, {
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool validation = false,
    bool truncate = false,
    bool dense = false,
  }) {
    final isAdmin = context.read<AdminProvider>().isAdmin;

    // Ensure value exists in items list
    if (value != null && !items.contains(value)) {
      value = null; // Reset value if it's not in the items list
    }

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Theme.of(context).dialogTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
      ),
      child: DropdownButtonFormField<String>(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        isDense: false,
        decoration: InputDecoration(
          border: InputBorder.none,
          errorStyle: TextStyle(
            fontFamily: 'Gilroy-Medium',
            fontSize: 10,
            color: Theme.of(context).colorScheme.secondary,
          ),
          isDense: dense,
        ),
        borderRadius: BorderRadius.circular(3),
        focusColor: Theme.of(context).cardColor,
        dropdownColor: Theme.of(context).cardColor,
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Theme.of(context).highlightColor,
        ),
        isExpanded: true,
        // Customize the selected item display
        selectedItemBuilder: (!truncate)
            ? null
            : (BuildContext context) {
                return items.map<Widget>((String item) {
                  return Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.3,
                    ),
                    child: Text(
                      item.length > 6 ? '${item.substring(0, 6)}...' : item,
                      style: TextStyle(
                        fontFamily: 'Gilroy-Medium',
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).highlightColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList();
              },
        value: value,
        // Show full text in dropdown items
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                fontFamily: 'Gilroy-Medium',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).highlightColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          // Skip validation for admin users
          if (isAdmin) return null;

          if (!validation) {
            return null;
          }

          // Add validator for required field
          if (value == null || value.isEmpty) {
            return 'Please select a value';
          }
          return null;
        },
      ),
    );
  }

  // Widget for the textInput field
  Widget _buildTextInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String dataType,
    bool validation = false,
    bool dense = false,
    String trailingText = "NA",
  }) {
    final isAdmin = context.read<AdminProvider>().isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextFormField(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: controller,
        style: TextStyle(
          fontFamily: 'Gilroy-Medium',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).highlightColor,
        ),
        keyboardType: (dataType == "double")
            ? TextInputType.numberWithOptions(decimal: true)
            : ((dataType == "integer")
                ? TextInputType.number
                : ((dataType == "date")
                    ? TextInputType.datetime
                    : ((dataType == "string")
                        ? TextInputType.text
                        : TextInputType.none))),
        inputFormatters: [
          (dataType == "double")
              ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              : ((dataType == "integer")
                  ? FilteringTextInputFormatter.digitsOnly
                  : FilteringTextInputFormatter.allow(RegExp('.*'))),
        ],
        textAlign: (trailingText != "NA") ? TextAlign.end : TextAlign.start,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: dense,
          suffixStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          suffixText: (trailingText != "NA") ? ' $trailingText' : '',
          errorStyle: TextStyle(
            fontFamily: 'Gilroy-Medium',
            fontSize: 10,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        validator: (value) {
          // Skip validation for admin users
          if (isAdmin) return null;

          if (!validation) {
            return null;
          }

          // Add validator for required field
          if (value == null || value.isEmpty) {
            return 'Please enter a value';
          }

          if (trailingText == "%") {
            final percentage = double.tryParse(value);
            if (percentage == null) {
              return 'Please enter a valid %';
            }

            if (percentage < 0 || percentage > 100) {
              return 'Invalid % value!';
            }
          }

          // Add validation for elevation (max 3 digits before decimal, 2 after)
          if (trailingText == "m") {
            final elevation = double.tryParse(value);
            if (elevation == null) {
              return 'Please enter a valid elevation';
            }

            if (elevation < 0) {
              return 'Elevation cannot be negative';
            }

            final parts = value.split('.');
            if (parts[0].length > 3) {
              return 'Maximum 3 digits before decimal';
            }

            if (parts.length > 1 && parts[1].length > 2) {
              // Schedule the update for after the frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.text = elevation.toStringAsFixed(2);
              });
            }

            if (elevation > 999.99) {
              return 'Maximum elevation is 999.99m';
            }
          }

          // Add validation for max temp (max 2 digits before decimal, 2 after)
          if (trailingText == "°C") {
            final temp = double.tryParse(value);
            if (temp == null) {
              return 'Please enter a valid temperature';
            }

            final parts = value.split('.');
            if (parts[0].length > 2) {
              return 'Maximum 2 digits before decimal';
            }

            if (parts.length > 1 && parts[1].length > 2) {
              // Schedule the update for after the frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.text = temp.toStringAsFixed(2);
              });
            }

            if (temp > 99.99) {
              return 'Maximum temperature is 99.99°C';
            }
          }

          return null;
        },
      ),
    );
  }

  // Widget for the textInput field with side label
  Widget _buildTextInputWithSideLabelField(
    BuildContext context, {
    required TextEditingController controller,
    required String dataType,
    required String fieldSideLabel,
    bool validation = false,
    bool dense = false,
  }) {
    final isAdmin = context.read<AdminProvider>().isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.7),
      child: Row(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.15,
            child: TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: controller,
              readOnly: _isReadonlySideLabelField,
              focusNode: _focusNodeSideLabelField,
              style: TextStyle(
                fontFamily: 'Gilroy-Medium',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).highlightColor,
              ),
              keyboardType: (dataType == "double")
                  ? TextInputType.numberWithOptions(decimal: true)
                  : ((dataType == "integer")
                      ? TextInputType.number
                      : ((dataType == "date")
                          ? TextInputType.datetime
                          : ((dataType == "string")
                              ? TextInputType.text
                              : TextInputType.none))),
              inputFormatters: [
                (dataType == "double")
                    ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    : ((dataType == "integer")
                        ? FilteringTextInputFormatter.digitsOnly
                        : FilteringTextInputFormatter.allow(RegExp('.*'))),
              ],
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: dense,
                errorStyle: TextStyle(
                  fontFamily: 'Gilroy-Medium',
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              onTap: () {
                _focusNodeSideLabelField.requestFocus();
                setState(() {
                  _isReadonlySideLabelField = false;
                  _isSideLabelActive = true;
                });
              },
              onTapOutside: (event) {
                _focusNodeSideLabelField.unfocus();
                setState(() {
                  _isReadonlySideLabelField = true;
                  if (controller.text.isEmpty) {
                    _isSideLabelActive = false;
                  }
                });
              },
              validator: (value) {
                // Skip validation for admin users
                if (isAdmin) return null;

                if (!validation) {
                  return null;
                }

                // Add validator for required field
                if (value == null || value.isEmpty) {
                  return 'Invalid!';
                }
                return null;
              },
            ),
          ),
          SizedBox(width: 5),
          Text(
            (_isSideLabelActive) ? fieldSideLabel : '',
            style: TextStyle(
              fontFamily: 'Gilroy-Medium',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).highlightColor,
            ),
          ),
        ],
      ),
    );
  }

  // Widget for the dateInput field
  Widget _buildDateInputField(
    BuildContext context, {
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true, // Make the field read-only to prevent manual input
      keyboardType: TextInputType.datetime,
      onTap: () async {
        // Show a date picker when the field is tapped
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: (controller.text.isNotEmpty)
              ? DateFormat("dd-MM-yy").parse(controller.text)
              : DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          // Update the controller with the selected date
          setState(() {
            controller.text = _formatDate(Timestamp.fromDate(pickedDate));
          });
        }
      },
      style: TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).highlightColor,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.error, width: 0),
        ),
      ),
    );
  }

  // Add this widget for multi-select field
  Widget _buildMultiSelectField(
    BuildContext context, {
    required List<String> items,
    required List<String> selectedItems,
    bool validation = false,
  }) {
    return InkWell(
      onTap: () => _showMultiSelectDialog(context, items, selectedItems),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedItems.isEmpty ? '' : selectedItems.join(', '),
                style: TextStyle(
                  fontFamily: 'Gilroy-Medium',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).highlightColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).highlightColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMultiSelectDialog(
    BuildContext context,
    List<String> items,
    List<String> selectedItems,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).dialogTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select Plant Varieties',
                    style: TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      color: Theme.of(context).highlightColor,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: items.map((item) {
                      return CheckboxListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            fontFamily: 'Gilroy-Medium',
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        value: selectedItems.contains(item),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked!) {
                              selectedItems.add(item);
                            } else {
                              selectedItems.remove(item);
                            }
                          });
                          // Update parent state
                          this.setState(() {
                            _plantVariety = selectedItems;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.error,
                        checkColor: Theme.of(context).scaffoldBackgroundColor,
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                if (selectedItems.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedItems.clear();
                      });
                      // Update parent state
                      this.setState(() {
                        _plantVariety = selectedItems;
                      });
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        fontFamily: 'Gilroy-SemiBold',
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImageCaptureField(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isImageUploading || _isImageDeleting) ...[
            SizedBox(height: 13),
            SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(
                color: Theme.of(context).highlightColor,
              ),
            ),
            SizedBox(height: 15),
          ] else
            Icon(
              Icons.perm_media_outlined,
              size: 42,
              color: Theme.of(context).highlightColor,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              (_isImageUploading || _isImageDeleting)
                  ? ((_isImageDeleting) ? "Deleting..." : "Uploading...")
                  : "Upload Media",
              style: const TextStyle(
                fontFamily: 'Gilroy-SemiBold',
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaPicker(BuildContext context) {
    if (_totalMediaCount < 3) {
      _showPicker(context, [
        _pickerOption(context, Icons.photo_library, 'Select from Gallery',
            () => _showCameraModePicker(context, isGallery: true)),
        _pickerOption(context, Icons.camera, 'Capture Now',
            () => _showCameraModePicker(context, isGallery: false)),
      ]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot upload more than 3 media!')),
      );
    }
  }

  // Function to show options for Image or Video
  void _showCameraModePicker(
    BuildContext context, {
    required bool isGallery,
  }) {
    _showPicker(context, [
      _pickerOption(
        context,
        (isGallery) ? Icons.image_outlined : Icons.photo_camera_back,
        (isGallery) ? 'Choose an Image' : 'Take a Picture',
        () async {
          if (isGallery) {
            await _pickMedia(context,
                source: ImageSource.gallery, isVideo: false);
          } else {
            // Show custom image capture widget
            if (!mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ImageCaptureWidget(
                onImageCaptured: (String filePath) {
                  Navigator.pop(context);
                  _handleImageCaptured(context, filePath);
                },
                onCancel: () {
                  Navigator.pop(context);
                  _logger.info('Image capture cancelled by user');
                },
              ),
            );
          }
        },
      ),
      _pickerOption(
        context,
        (isGallery)
            ? Icons.video_collection_outlined
            : Icons.video_camera_back_outlined,
        (isGallery) ? 'Choose a Video' : 'Record a Video',
        () async {
          if (isGallery) {
            await _pickMedia(context,
                source: ImageSource.gallery, isVideo: true);
          } else {
            // Show custom video capture widget
            if (!mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => VideoCaptureWidget(
                onVideoRecorded: (String filePath) {
                  Navigator.pop(context);
                  _handleVideoRecorded(context, filePath);
                },
                onCancel: () {
                  Navigator.pop(context);
                  _logger.info('Video capture cancelled by user');
                },
              ),
            );
          }
        },
      ),
    ]);
  }

  void _showPicker(BuildContext context, List<Widget> options) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
            child: Wrap(
              children: options,
            ),
          ),
        );
      },
    );
  }

  Widget _pickerOption(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading:
          Icon(icon, color: AppConstants.highlightColor(context), size: 27),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Gilroy-SemiBold',
          fontSize: 17,
          color: AppConstants.secondaryColor(context),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // Media picker with compression logic
  Future<void> _pickMedia(BuildContext context,
      {required ImageSource source, bool isVideo = false}) async {
    final mediaContext = context;
    bool wasWidgetMounted = mounted;

    try {
      final picker = ImagePicker();
      final media = isVideo
          ? await picker.pickVideo(
              source: source, maxDuration: Duration(seconds: 30))
          : await picker.pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 1080, // Add max width to prevent oversized images
              maxHeight: 1920, // Add max height to prevent oversized images
            );

      if (media == null) {
        _logger.info('Media selection cancelled by user');
        return;
      }

      if (!mounted) return;
      setState(() {
        _isImageUploading = true;
      });

      final file = File(media.path);
      if (!await file.exists()) {
        throw Exception('Selected file does not exist');
      }

      final fileSize = await file.length();
      _logger.info('Selected file size: [36m${fileSize / 1024 / 1024}MB[0m');

      if (fileSize == 0) {
        throw Exception('Selected file is empty');
      }

      if (isVideo) {
        if (fileSize > 30 * 1024 * 1024) {
          throw Exception('File size too large. Maximum size is 30MB.');
        }
      } else {
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('File size too large. Maximum size is 10MB.');
        }
      }

      // Create a unique filename
      final mediaFilePathName =
          'plantations/${widget.regionDocument['regionName']}/regionMedia/${DateTime.now().millisecondsSinceEpoch.toString()}_${isVideo ? 'video' : 'image'}.${isVideo ? 'mp4' : 'jpg'}';

      final storageRef =
          FirebaseStorage.instance.ref().child(mediaFilePathName);

      // Set appropriate metadata
      final metadata = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        customMetadata: {
          'file-size': fileSize.toString(),
          'capture-timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Add retry logic for upload
      int retryCount = 0;
      const maxRetries = 3;
      String? downloadUrl;

      while (retryCount < maxRetries) {
        try {
          _logger.info(
              'Attempting upload (attempt ${retryCount + 1}/$maxRetries)');

          final uploadTask = storageRef.putFile(file, metadata);
          await uploadTask;

          downloadUrl = await storageRef.getDownloadURL();
          _logger.info('Upload successful: $downloadUrl');
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          _logger.warning('Upload attempt $retryCount failed: $e');

          if (retryCount == maxRetries) {
            rethrow; // Rethrow if all retries failed
          }
          // Wait before retrying with exponential backoff
          await Future.delayed(Duration(seconds: 1 * retryCount));
        }
      }

      // Only update state if widget is still mounted
      if (wasWidgetMounted && mounted) {
        setState(() {
          _isImageUploading = false;
          if (downloadUrl != null) {
            _mediaList.add(downloadUrl);
            _totalMediaCount++;
          }
        });

        // Only show snackbar if context is still valid
        if (mediaContext.mounted) {
          ScaffoldMessenger.of(mediaContext).showSnackBar(
            SnackBar(
              content:
                  Text('${isVideo ? 'Video' : 'Image'} uploaded successfully!'),
              backgroundColor: Theme.of(mediaContext).highlightColor,
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error during media upload: $e');
      if (wasWidgetMounted && mounted) {
        setState(() => _isImageUploading = false);
      }
      if (mediaContext.mounted) {
        ScaffoldMessenger.of(mediaContext).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Failed to upload media.'),
                TextButton(
                  onPressed: () => _pickMedia(mediaContext,
                      source: source, isVideo: isVideo),
                  child: Text('Retry'),
                ),
              ],
            ),
            backgroundColor: Theme.of(mediaContext).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleVideoRecorded(
      BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Video file does not exist');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }

      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Video file too large (max 50MB)');
      }

      // Store context and mounted state before async operations
      final uploadContext = context;
      bool wasWidgetMounted = mounted;

      // Create a new reference to the widget's document data
      final nurseryName = widget.regionDocument['regionName'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mediaFileName =
          'plantations/$nurseryName/regionMedia/${timestamp}_video.mp4';

      if (wasWidgetMounted) {
        setState(() {
          _isImageUploading = true;
        });
      }

      final storageRef = FirebaseStorage.instance.ref().child(mediaFileName);

      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'picked-file-path': filePath,
          'file-size': fileSize.toString(),
          'capture-timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Add retry logic for upload
      int retryCount = 0;
      const maxRetries = 3;
      String? downloadUrl;

      while (retryCount < maxRetries) {
        try {
          _logger.info(
              'Attempting upload (attempt ${retryCount + 1}/$maxRetries)');

          final uploadTask = storageRef.putFile(file, metadata);
          await uploadTask;

          downloadUrl = await storageRef.getDownloadURL();
          _logger.info('Upload successful: $downloadUrl');
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          _logger.warning('Upload attempt $retryCount failed: $e');

          if (retryCount == maxRetries) {
            rethrow; // Rethrow if all retries failed
          }
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      }

      // Only update state if widget is still mounted
      if (wasWidgetMounted && mounted) {
        setState(() {
          _isImageUploading = false;
          if (downloadUrl != null) {
            _mediaList.add(downloadUrl);
            _totalMediaCount++;
          }
        });

        // Only show snackbar if context is still valid
        if (uploadContext.mounted) {
          ScaffoldMessenger.of(uploadContext).showSnackBar(
            SnackBar(
              content: Text('Video uploaded successfully!'),
              backgroundColor: Theme.of(uploadContext).highlightColor,
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error handling recorded video: $e');
      rethrow;
    }
  }

  Future<void> _handleImageCaptured(
      BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      // Add image format validation
      final fileExtension = filePath.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(fileExtension)) {
        throw Exception(
            'Unsupported image format. Please use JPG, JPEG, or PNG.');
      }

      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image file too large (max 10MB)');
      }

      // Store context and mounted state before async operations
      final uploadContext = context;
      bool wasWidgetMounted = mounted;

      // Create a new reference to the widget's document data
      final nurseryName = widget.regionDocument['regionName'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mediaFileName =
          'plantations/$nurseryName/regionMedia/${timestamp}_image.jpg';

      if (wasWidgetMounted) {
        setState(() {
          _isImageUploading = true;
        });
      }

      final storageRef = FirebaseStorage.instance.ref().child(mediaFileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'picked-file-path': filePath,
          'file-size': fileSize.toString(),
          'capture-timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Add retry logic for upload
      int retryCount = 0;
      const maxRetries = 3;
      String? downloadUrl;

      while (retryCount < maxRetries) {
        try {
          _logger.info(
              'Attempting upload (attempt ${retryCount + 1}/$maxRetries)');

          final uploadTask = storageRef.putFile(file, metadata);
          await uploadTask;

          downloadUrl = await storageRef.getDownloadURL();
          _logger.info('Upload successful: $downloadUrl');
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          _logger.warning('Upload attempt $retryCount failed: $e');

          if (retryCount == maxRetries) {
            rethrow; // Rethrow if all retries failed
          }
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      }

      // Only update state if widget is still mounted
      if (wasWidgetMounted && mounted) {
        setState(() {
          _isImageUploading = false;
          if (downloadUrl != null) {
            _mediaList.add(downloadUrl);
            _totalMediaCount++;
          }
        });

        // Only show snackbar if context is still valid
        if (uploadContext.mounted) {
          ScaffoldMessenger.of(uploadContext).showSnackBar(
            SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Theme.of(uploadContext).highlightColor,
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error handling captured image: $e');
      rethrow;
    }
  }

  Future<void> _saveDataToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final dialogContext = context;
      var surveyStatus = !_isImageUploading;
      final regionDoc = widget.regionDocument.data() as Map;

      final insightsData = {
        'savedOn': FieldValue.serverTimestamp(),
        'savedBy': user.email,
        'updatedOn': FieldValue.serverTimestamp(),
        'surveyStatus': surveyStatus,
        'shadeType': _shadeType,
        'plotNumber': _plotNumberController.text.isEmpty
            ? null
            : _plotNumberController.text,
        'khataNumber': _khataNumberController.text.isEmpty
            ? null
            : _khataNumberController.text,
        'plantationYear':
            _plantationYear != null ? int.parse(_plantationYear!) : null,
        'beneficiaries': _beneficiariesCountController.text.isEmpty
            ? null
            : int.parse(_beneficiariesCountController.text),
        'agencyName': _agencyValue,
        'averageYield': _yeildValueController.text.isEmpty
            ? null
            : double.parse(_yeildValueController.text),
        'plantVarieties': _plantVariety.isEmpty ? null : _plantVariety,
        'survivalPercentage': _survivalPercentController.text.isEmpty
            ? null
            : double.parse(_survivalPercentController.text),
        'averageHeight': _treeHeightController.text.isEmpty
            ? null
            : double.parse(_treeHeightController.text),
        'mediaURLs': _mediaList.isEmpty ? null : _mediaList,
        'regionCategory': _regionCategory,
        'elevation': _elevation,
        'slope': _slope,
        'maxTemp': _maxTemp,
        'ph': _ph,
        'aspect': _aspect,
      };

      // If admin made changes to area/boundary
      if (_areFieldsEditable) {
        // Store original values if not already stored
        if (!insightsData.containsKey('originalShadeBoundary')) {
          insightsData['originalShadeBoundary'] = regionDoc['perimeter'];
          insightsData['originalShadeArea'] = regionDoc['area'];
        }

        // Convert hectares back to square meters and update values
        final newAreaInSquareMeters = double.parse(_areaController.text) *
            AreaFormatter.hectareConversion;
        insightsData['updatedArea'] = newAreaInSquareMeters;
        insightsData['updatedPerimeter'] =
            double.parse(_boundaryController.text);
      }

      final regionData = {
        'updatedOn': FieldValue.serverTimestamp(),
        //'savedBy': user.email,
        'surveyStatus': surveyStatus,
        'regionCategory': _regionCategory,
        'latestDataForDashboard': insightsData,
      };

      // If admin made changes to area/boundary
      if (_areFieldsEditable) {
        // Store original values if not already stored
        if (!regionDoc.containsKey('originalShadeBoundary')) {
          regionData['originalShadeBoundary'] = regionDoc['perimeter'];
          regionData['originalShadeArea'] = regionDoc['area'];
        }

        // Convert hectares back to square meters and update values
        final newAreaInSquareMeters = double.parse(_areaController.text) *
            AreaFormatter.hectareConversion;
        regionData['area'] = newAreaInSquareMeters;
        regionData['perimeter'] = double.parse(_boundaryController.text);
      }

      // Update the main region document
      await widget.regionDocument.reference.update(regionData).onError(
          (e, _) => _handleFirestoreError('updating region document', e));

      // Create a new timestamped document in regionInsights collection
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await widget.regionDocument.reference
          .collection('regionInsights')
          .doc(timestamp)
          .set(insightsData)
          .onError((e, _) =>
              _handleFirestoreError('creating new insights document', e));

      // Update the latestInformation document
      await widget.regionDocument.reference
          .collection('regionInsights')
          .doc('latestInformation')
          .set(insightsData)
          .onError((e, _) =>
              _handleFirestoreError('updating latest information', e));

      // Show success message and navigate
      if (!mounted) return;
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text('Data saved successfully!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _logger.severe('Error saving data to Firestore: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save data. Please try again.')),
        );
      }
    }
  }
}
