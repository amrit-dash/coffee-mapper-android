import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:coffee_mapper/widgets/header.dart';
import 'package:coffee_mapper/widgets/form_fields.dart';

class UpdateShadeDetailsScreen extends StatefulWidget {
  final DocumentSnapshot regionDocument;
  final DocumentSnapshot insightsDocument;
  final DocumentSnapshot formDropDownData;

  const UpdateShadeDetailsScreen({
    super.key,
    required this.regionDocument,
    required this.insightsDocument,
    required this.formDropDownData,
  });

  @override
  State<UpdateShadeDetailsScreen> createState() =>
      _UpdateShadeDetailsScreenState();
}

class _UpdateShadeDetailsScreenState extends State<UpdateShadeDetailsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            SizedBox(height: MediaQuery.of(context).size.height * 0.017),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (widget.regionDocument['regionCategory'].toString().toLowerCase().contains("shade")) ? 'Update shade data' : 'Update plantation data',
                    style: TextStyle(
                      fontFamily: 'Gilroy-SemiBold',
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.018),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 5, 30, 20),
                  child: FormFields(
                    insightsDocument: widget.insightsDocument,
                    regionDocument: widget.regionDocument,
                    formDropDownData: widget.formDropDownData,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
