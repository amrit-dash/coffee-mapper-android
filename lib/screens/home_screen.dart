import 'package:flutter/material.dart';

import 'plot_polygon.dart';
import 'view_saved_regions.dart';
import 'view_coffee_nurseries.dart';
import '../widgets/header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo, title, and logout button
            Header(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(35.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 65),
                      const Text(
                        'Hello,',
                        style: TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 55,
                        ),
                      ),
                      const Text(
                        'What would you like to do?',
                        style: TextStyle(
                          fontFamily: 'Gilroy-SemiBold',
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildMenuButton(
                        context,
                        icon: Icons.add_location_alt_outlined,
                        title: 'Insert plantation by GPS',
                        onTap: () {
                          // Navigate to the PlotPolygonScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PlotPolygonScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        context,
                        icon: Icons.fact_check_outlined,
                        title: 'Update plantation details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ViewSavedRegionsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        context,
                        icon: Icons.eco_outlined,
                        title: 'Update coffee nursery',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ViewCoffeeNurseriesScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        context,
                        icon: Icons.upload_file,
                        title: 'Insert plantation by KML',
                        onTap: () {

                        },
                        disabled: "yes"
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for the menu buttons
  Widget _buildMenuButton(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        disabled,
      }) {
    return SizedBox(
      height: 80,
      child: FilledButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(128),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0), // Reduce corner radius to 8 pixels
          ),
          padding: const EdgeInsets.symmetric(vertical: 5),
          textStyle: TextStyle(
            fontFamily: 'Gilroy-SemiBold',
            fontSize: 17,
          ),
        ),
        onPressed: (disabled == "yes") ? null : onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 20),
            Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.error.withAlpha(128),
            ),
            const SizedBox(width: 20),
            Text(title, style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 16.5,
            ),
            ),
          ],
        ),
      ),
    );
  }
}