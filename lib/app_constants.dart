import 'package:flutter/material.dart';

class AppConstants {
  static Color scaffoldColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static double buttonWidth(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.35;

  static double buttonHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.09;

  static TextStyle themeFontTextWithColor(BuildContext context) =>
      TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: 15,
        color: Theme.of(context).highlightColor,
      );

  static Color primaryColor(BuildContext context) => Theme.of(context).primaryColor;
  static Color errorColor(BuildContext context) => Theme.of(context).colorScheme.error;
  static Color secondaryColor(BuildContext context) => Theme.of(context).colorScheme.secondary;
  static Color highlightColor(BuildContext context) => Theme.of(context).highlightColor;
  static Color cardColor(BuildContext context) => Theme.of(context).cardColor;
  static Color themeBGColor(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  static Color dialogBGColor(BuildContext context) => Theme.of(context).dialogBackgroundColor;
}
