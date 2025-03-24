import 'package:flutter/material.dart';
import 'package:coffee_mapper/app_constants.dart';
import 'package:coffee_mapper/widgets/header.dart';
import 'package:coffee_mapper/widgets/nursery_form_fields.dart';

class UpdateNurseryDetailsScreen extends StatelessWidget {
  final dynamic nurseryDocument;

  const UpdateNurseryDetailsScreen({
    super.key,
    required this.nurseryDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldColor(context),
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
                    'Update Nursery Data',
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
                padding: const EdgeInsets.fromLTRB(30, 5, 30, 20),
                child: NurseryFormFields(
                  nurseryDocument: nurseryDocument,
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