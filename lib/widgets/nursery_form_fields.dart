import 'dart:io';
import 'dart:async';
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
import 'video_capture_widget.dart';
import 'image_capture_widget.dart';

class NurseryFormFields extends StatefulWidget {
  final DocumentSnapshot nurseryDocument;

  const NurseryFormFields({
    super.key,
    required this.nurseryDocument,
  });

  @override
  State<NurseryFormFields> createState() => _NurseryFormFieldsState();
}

class _NurseryFormFieldsState extends State<NurseryFormFields> {
  final _formKey = GlobalKey<FormState>();
  final _logger = AppLogger.getLogger('NurseryFormFields');

  // Controllers for numeric fields
  final _seedlingsRaisedController = TextEditingController();
  final _seedsQuantityController = TextEditingController();
  final _coffeeVarietyController = TextEditingController();
  final _areaController = TextEditingController();
  final _boundaryController = TextEditingController();

  // Controllers for date fields
  final _sowingDateController = TextEditingController();
  final _transplantingDateController = TextEditingController();
  final _firstPairLeavesController = TextEditingController();
  final _secondPairLeavesController = TextEditingController();
  final _thirdPairLeavesController = TextEditingController();
  final _fourthPairLeavesController = TextEditingController();
  final _fifthPairLeavesController = TextEditingController();
  final _sixthPairLeavesController = TextEditingController();

  // Media handling
  List _mediaList = [];
  bool _isImageUploading = false;
  bool _isImageDeleting = false;

  // Admin field editing
  bool _areFieldsEditable = false;

  @override
  void initState() {
    super.initState();
    _initializeFormFields();
  }

  void _initializeFormFields() {
    final nurseryData = widget.nurseryDocument.data() as Map;

    // Initialize area and boundary controllers
    _areaController.text =
        (nurseryData['area'] / AreaFormatter.hectareConversion)
            .toStringAsFixed(3);
    _boundaryController.text = nurseryData['perimeter'].toStringAsFixed(2);

    // Initialize other fields if they exist
    if (nurseryData['seedlingsRaised'] != null) {
      _seedlingsRaisedController.text =
          nurseryData['seedlingsRaised'].toString();
    }
    if (nurseryData['seedsQuantity'] != null) {
      _seedsQuantityController.text = nurseryData['seedsQuantity'].toString();
    }
    if (nurseryData['coffeeVariety'] != null) {
      _coffeeVarietyController.text = nurseryData['coffeeVariety'];
    }
    if (nurseryData['sowingDate'] != null) {
      _sowingDateController.text = _formatDate(nurseryData['sowingDate']);
    }
    if (nurseryData['transplantingDate'] != null) {
      _transplantingDateController.text =
          _formatDate(nurseryData['transplantingDate']);
    }
    if (nurseryData['firstPairLeaves'] != null) {
      _firstPairLeavesController.text =
          _formatDate(nurseryData['firstPairLeaves']);
    }
    if (nurseryData['secondPairLeaves'] != null) {
      _secondPairLeavesController.text =
          _formatDate(nurseryData['secondPairLeaves']);
    }
    if (nurseryData['thirdPairLeaves'] != null) {
      _thirdPairLeavesController.text =
          _formatDate(nurseryData['thirdPairLeaves']);
    }
    if (nurseryData['fourthPairLeaves'] != null) {
      _fourthPairLeavesController.text =
          _formatDate(nurseryData['fourthPairLeaves']);
    }
    if (nurseryData['fifthPairLeaves'] != null) {
      _fifthPairLeavesController.text =
          _formatDate(nurseryData['fifthPairLeaves']);
    }
    if (nurseryData['sixthPairLeaves'] != null) {
      _sixthPairLeavesController.text =
          _formatDate(nurseryData['sixthPairLeaves']);
    }
    if (nurseryData['mediaURLs'] != null) {
      _mediaList = List<String>.from(nurseryData['mediaURLs']);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        final seconds = timestamp['_seconds'];
        if (seconds == null) return '';
        dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } else {
        return '';
      }

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString().substring(2);
      return '$day-$month-$year';
    } catch (e) {
      _logger.warning('Error formatting date: $e');
      return '';
    }
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
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Range Name
          Text(
            'SHG/SC Range Name : ',
            style: TextStyle(
              fontFamily: 'Gilroy-SemiBold',
              fontSize: 16,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          Text(
            '${widget.nurseryDocument['regionName']}',
            style: TextStyle(
              fontFamily: 'Gilroy-SemiBold',
              fontSize: 21,
              color: Theme.of(context).highlightColor,
            ),
          ),
          SizedBox(height: 15),

          // Area and Boundary Fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: isSuperAdmin ? () => _handleFieldClick(context) : null,
                child: _buildFormField(
                  context,
                  fieldName: 'Boundary',
                  fieldType: _areFieldsEditable ? 'textInput' : 'fixedValue',
                  fieldValue:
                      '${widget.nurseryDocument['perimeter'].toStringAsFixed(2)} m',
                  dataType: 'double',
                  trailingText: 'm',
                  controller: _boundaryController,
                  fixedValueFontSize: 22.5,
                ),
              ),
              InkWell(
                onTap: isSuperAdmin ? () => _handleFieldClick(context) : null,
                child: _buildFormField(
                  context,
                  fieldName: 'Area',
                  fieldType: _areFieldsEditable ? 'textInput' : 'fixedValue',
                  fieldValue: AreaFormatter.formatArea(
                      widget.nurseryDocument['area'], false),
                  dataType: 'double',
                  trailingText: 'ha',
                  controller: _areaController,
                  fixedValueFontSize: 22.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Nursery Data Section
          Center(
            child: Text(
              'Nursery Data',
              style: TextStyle(
                fontFamily: 'Gilroy-SemiBold',
                fontSize: 19,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFormField(
                context,
                fieldName: 'Sowing Date',
                fieldType: 'dateInput',
                controller: _sowingDateController,
              ),
              _buildFormField(
                context,
                fieldName: 'Transplant Date',
                fieldType: 'dateInput',
                controller: _transplantingDateController,
              ),
            ],
          ),
          SizedBox(height: 15),
          // Nursery Form Fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFormField(
                context,
                fieldName: 'Seedlings Raised',
                fieldType: 'textInput',
                dataType: 'integer',
                controller: _seedlingsRaisedController,
                dense: true,
                validation: true,
              ),
              _buildFormField(
                context,
                fieldName: 'Seeds Quantity',
                fieldType: 'textInput',
                dataType: 'integer',
                controller: _seedsQuantityController,
                dense: true,
                validation: true,
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildFormField(
            context,
            fieldName: 'Coffee Variety',
            fieldType: 'textInput',
            dataType: 'string',
            controller: _coffeeVarietyController,
            dense: true,
            validation: true,
          ),
          
          SizedBox(height: 20),
          Center(
            child: Text(
              'Leaves Data',
              style: TextStyle(
                fontFamily: 'Gilroy-SemiBold',
                fontSize: 19,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFormField(
                context,
                fieldName: 'First Pair',
                fieldType: 'dateInput',
                controller: _firstPairLeavesController,
              ),
              _buildFormField(
                context,
                fieldName: 'Second Pair',
                fieldType: 'dateInput',
                controller: _secondPairLeavesController,
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFormField(
                context,
                fieldName: 'Third Pair',
                fieldType: 'dateInput',
                controller: _thirdPairLeavesController,
              ),
              _buildFormField(
                context,
                fieldName: 'Fourth Pair',
                fieldType: 'dateInput',
                controller: _fourthPairLeavesController,
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFormField(
                context,
                fieldName: 'Fifth Pair',
                fieldType: 'dateInput',
                controller: _fifthPairLeavesController,
              ),
              _buildFormField(
                context,
                fieldName: 'Sixth Pair',
                fieldType: 'dateInput',
                controller: _sixthPairLeavesController,
              ),
            ],
          ),
          SizedBox(height: 40),

          // Media Upload Section
          _buildFormField(
            context,
            fieldType: 'imageCapture',
          ),

          // Display Uploaded Media
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

                      setState(() {
                        _mediaList.removeAt(indexCounter);
                        _isImageDeleting = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Image removed from list')),
                      );
                    } catch (e) {
                      _logger.warning('Error removing image from list: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error removing image')),
                      );
                    }
                  },
                ),
              ),
          ],

          // Bottom Buttons
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
                        ),
                      ),
                      onPressed: (_isImageUploading)
                          ? null
                          : () => Navigator.pop(context),
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
                          ),
                        ),
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

  // Form Field Builder
  Widget _buildFormField(
    BuildContext context, {
    required String fieldType,
    String fieldName = "NA",
    String? fieldValue,
    TextEditingController? controller,
    String? dataType,
    bool validation = false,
    bool dense = false,
    String trailingText = "NA",
    double fixedValueFontSize = 24,
  }) {
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
                            widget.nurseryDocument['area'],
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
                    'textInput' => _buildTextInputField(
                        context,
                        controller: controller!,
                        dataType: dataType!,
                        validation: validation,
                        dense: dense,
                        trailingText: trailingText,
                      ),
                    'dateInput' => _buildDateInputField(
                        context,
                        controller: controller!,
                      ),
                    'imageCapture' => _buildImageCaptureField(context),
                    _ => const SizedBox(height: 10),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (fieldType == 'imageCapture') {
      return GestureDetector(
        onTap: (_isImageUploading) ? null : () => _showMediaPicker(context),
        child: content,
      );
    }

    return content;
  }

  // Text Input Field Builder
  Widget _buildTextInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String dataType,
    bool validation = false,
    bool dense = false,
    String trailingText = "NA",
  }) {
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
                : TextInputType.text),
        inputFormatters: [
          if (dataType == "double")
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,8}(\.\d{0,2})?$'))
          else if (dataType == "integer")
            FilteringTextInputFormatter.digitsOnly
          else
            FilteringTextInputFormatter.allow(RegExp('.*')),
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
          if (!validation) return null;

          if (value == null || value.isEmpty) {
            return null; // Not mandatory
          }

          if (dataType == "integer" && value.length > 8) {
            return 'Maximum 8 digits...';
          }

          if (dataType == "double") {
            final parts = value.split('.');
            if (parts[0].length > 8) {
              return 'Maximum 8 digits...';
            }
            if (parts.length > 1 && parts[1].length > 2) {
              return 'Max 2 digits after decimal...';
            }
          }

          if (dataType == "string" && value.length > 45) {
            return 'Max 45 characters...';
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

          return null;
        },
      ),
    );
  }

  // Date Input Field Builder
  Widget _buildDateInputField(
    BuildContext context, {
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      keyboardType: TextInputType.datetime,
      onTap: () async {
        DateTime? selectedDate = (controller.text.isNotEmpty)
            ? DateFormat("dd-MM-yy").parse(controller.text)
            : DateTime.now();
            
        final DateTime? pickedDate = await showDialog<DateTime?>(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Date'),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 300,
                    height: 300,
                    child: CalendarDatePicker(
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onDateChanged: (DateTime value) {
                        setState(() {
                          selectedDate = value;
                        });
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          controller.clear();
                        });
                        Navigator.pop(context);
                      },
                      child: Text('Clear',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'Gilroy-SemiBold',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, selectedDate),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: Theme.of(context).highlightColor,
                          fontFamily: 'Gilroy-SemiBold',
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (pickedDate != null) {
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 0),
        ),
      ),
    );
  }

  // Image Capture Field Builder
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

  // Media Picker Methods
  void _showMediaPicker(BuildContext context) {
    _showPicker(context, [
      _pickerOption(context, Icons.photo_library, 'Select from Gallery',
          () => _showCameraModePicker(context, isGallery: true)),
      _pickerOption(context, Icons.camera, 'Capture Now',
          () => _showCameraModePicker(context, isGallery: false)),
    ]);
  }

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
                source: ImageSource.gallery,
                isVideo: false);
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
                source: ImageSource.gallery,
                isVideo: true);
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

  Future<void> _pickMedia(BuildContext context,
      {required ImageSource source, bool isVideo = false}) async {
    final mediaContext = context;
    bool wasWidgetMounted = mounted;

    try {
      final picker = ImagePicker();
      
      // Add a small delay before picking media to ensure the camera is ready
      await Future.delayed(Duration(milliseconds: 500));
      
      _logger.info('Starting media capture: ${isVideo ? 'video' : 'image'} from ${source == ImageSource.camera ? 'camera' : 'gallery'}');
      
      final media = isVideo
          ? await Future.delayed(Duration(milliseconds: 500), () async {
              _logger.info('Starting video capture after delay');
              try {
                final video = await picker.pickVideo(
                  source: source,
                  maxDuration: Duration(seconds: 30),
                  preferredCameraDevice: CameraDevice.rear,
                ).timeout(
                  Duration(seconds: 35),
                  onTimeout: () {
                    _logger.warning('Video capture timed out');
                    throw TimeoutException('Video capture timed out');
                  },
                );

                if (video == null) {
                  _logger.info('Video capture cancelled by user');
                  return null;
                }

                return video;
              } catch (e) {
                _logger.severe('Error during video capture: $e');
                rethrow;
              }
            })
          : await picker.pickImage(
              source: source,
              imageQuality: 80,
              preferredCameraDevice: CameraDevice.rear,
            );

      if (media == null) {
        _logger.info('Media capture cancelled by user');
        return;
      }

      _logger.info('Media captured successfully: ${media.path}');

      // Verify the file exists and is valid
      final file = File(media.path);
      if (!await file.exists()) {
        _logger.severe('Captured file does not exist: ${media.path}');
        throw Exception('Failed to save media file');
      }

      final fileSize = await file.length();
      _logger.info('Captured file size: ${fileSize / 1024 / 1024}MB');

      if (fileSize == 0) {
        _logger.severe('Captured file is empty: ${media.path}');
        throw Exception('Media file is empty');
      }

      if (fileSize > 50 * 1024 * 1024) { // 50MB limit
        _logger.warning('File size too large: ${fileSize / 1024 / 1024}MB');
        throw Exception('File size too large. Maximum size is 50MB.');
      }

      // Store nursery name before async operations
      final nurseryName = widget.nurseryDocument['regionName'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mediaFileName = 'nurseries/$nurseryName/nurseryMedia/${timestamp}_${isVideo ? 'video' : 'image'}.${isVideo ? 'mp4' : 'jpg'}';

      if (wasWidgetMounted && mounted) {
        setState(() {
          _isImageUploading = true;
        });
      }

      final storageRef = FirebaseStorage.instance.ref().child(mediaFileName);

      final metadata = isVideo
          ? SettableMetadata(
              contentType: 'video/mp4',
              customMetadata: {
                'picked-file-path': media.path,
                'file-size': fileSize.toString(),
                'capture-timestamp': DateTime.now().toIso8601String(),
              },
            )
          : SettableMetadata(contentType: 'image/jpeg');

      // Add retry logic for upload
      int retryCount = 0;
      const maxRetries = 3;
      String? downloadUrl;
      
      while (retryCount < maxRetries) {
        try {
          _logger.info('Attempting upload (attempt ${retryCount + 1}/$maxRetries)');
          
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
          }
        });

        // Only show snackbar if context is still valid
        if (mediaContext.mounted) {
          ScaffoldMessenger.of(mediaContext).showSnackBar(
            SnackBar(
              content: Text('${isVideo ? 'Video' : 'Image'} uploaded successfully!'),
              backgroundColor: Theme.of(mediaContext).highlightColor,
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error in media capture/upload: $e');
      if (wasWidgetMounted && mounted) {
        setState(() => _isImageUploading = false);
      }
      if (mediaContext.mounted) {
        String errorMessage = 'Failed to upload ${isVideo ? 'video' : 'image'}: ';
        if (e is TimeoutException) {
          errorMessage += 'Video capture timed out. Please try again.';
        } else if (e.toString().contains('NullPointerException')) {
          errorMessage += 'Failed to save video. Please try again.';
        } else {
          errorMessage += e.toString();
        }
        
        ScaffoldMessenger.of(mediaContext).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(errorMessage)),
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

  Future<void> _handleVideoRecorded(BuildContext context, String filePath) async {
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
      final nurseryName = widget.nurseryDocument['regionName'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mediaFileName = 'nurseries/$nurseryName/nurseryMedia/${timestamp}_video.mp4';

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
          _logger.info('Attempting upload (attempt ${retryCount + 1}/$maxRetries)');
          
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

  Future<void> _handleImageCaptured(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image file too large (max 10MB)');
      }

      // Store context and mounted state before async operations
      final uploadContext = context;
      bool wasWidgetMounted = mounted;

      // Create a new reference to the widget's document data
      final nurseryName = widget.nurseryDocument['regionName'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mediaFileName = 'nurseries/$nurseryName/nurseryMedia/${timestamp}_image.jpg';

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
          _logger.info('Attempting upload (attempt ${retryCount + 1}/$maxRetries)');
          
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

  void _saveButtonOnPressed() {
    if (_formKey.currentState!.validate()) {
      final dialogContext = context;
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      _saveDataToFirestore().then((_) {
        if (!mounted) return;
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(
              content: Text('Nursery data updated successfully!'),
              backgroundColor: Theme.of(dialogContext).highlightColor,
            ),
          );
          Navigator.pop(dialogContext);
        }
      }).catchError((error) {
        if (!mounted) return;
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
          _logger.severe('Error saving data to Firestore: $error');
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text('Failed to save data. Please try again.')),
          );
        }
      });
    }
  }

  Future<void> _saveDataToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final nurseryData = {
        'updatedOn': FieldValue.serverTimestamp(),
        'updatedBy': user.email,
      };

      // Add area and boundary if edited by admin
      if (_areFieldsEditable) {
        final newAreaInSquareMeters = double.parse(_areaController.text) *
            AreaFormatter.hectareConversion;
        nurseryData['area'] = newAreaInSquareMeters;
        nurseryData['perimeter'] = double.parse(_boundaryController.text);
      }

      // Add form fields if they have values
      if (_seedlingsRaisedController.text.isNotEmpty) {
        nurseryData['seedlingsRaised'] =
            int.parse(_seedlingsRaisedController.text);
      }
      if (_seedsQuantityController.text.isNotEmpty) {
        nurseryData['seedsQuantity'] = int.parse(_seedsQuantityController.text);
      }
      if (_coffeeVarietyController.text.isNotEmpty) {
        nurseryData['coffeeVariety'] = _coffeeVarietyController.text;
      }
      if (_sowingDateController.text.isNotEmpty) {
        nurseryData['sowingDate'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_sowingDateController.text));
      }
      if (_transplantingDateController.text.isNotEmpty) {
        nurseryData['transplantingDate'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_transplantingDateController.text));
      }
      if (_firstPairLeavesController.text.isNotEmpty) {
        nurseryData['firstPairLeaves'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_firstPairLeavesController.text));
      }
      if (_secondPairLeavesController.text.isNotEmpty) {
        nurseryData['secondPairLeaves'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_secondPairLeavesController.text));
      }
      if (_thirdPairLeavesController.text.isNotEmpty) {
        nurseryData['thirdPairLeaves'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_thirdPairLeavesController.text));
      }
      if (_fourthPairLeavesController.text.isNotEmpty) {
        nurseryData['fourthPairLeaves'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_fourthPairLeavesController.text));
      }
      if (_fifthPairLeavesController.text.isNotEmpty) {
        nurseryData['fifthPairLeaves'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_fifthPairLeavesController.text));
      }
      if (_sixthPairLeavesController.text.isNotEmpty) {
        nurseryData['sixthPairLeaves'] = Timestamp.fromDate(
            DateFormat("dd-MM-yy").parse(_sixthPairLeavesController.text));
      }

      // Add media URLs if any
      if (_mediaList.isNotEmpty) {
        nurseryData['mediaURLs'] = _mediaList;
      }

      await widget.nurseryDocument.reference.update(nurseryData);
    } catch (e) {
      _logger.severe('Error saving data to Firestore: $e');
      rethrow;
    }
  }
}
