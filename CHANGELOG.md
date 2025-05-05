# Changelog

All notable changes to the Coffee Mapper Android app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2024-03-31

### Added
- New environmental data fields for both Coffee and Shade plantations:
  - Elevation (in meters) with validation for max 3 digits and 2 decimal places
  - Slope with predefined ranges ("< 45°", "45° - 60°", "> 60°")
  - Maximum Temperature (in °C) with validation for max 2 digits and 2 decimal places
  - PH Value with predefined ranges ("5.0 - 5.5", "5.5 - 6.0", "6.0 - 6.5", "6.5 - 7.0")
  - Aspect with cardinal/intercardinal directions (N, NE, E, SE, S, SW, W, NW)
- New Shade Type options specifically for Coffee plantations:
  - "Natural: 30 - 40/Ac"
  - "Silveroak: 500 - 600/Ac"
- Added prominent disclosure dialog for location permissions compliance with Google Play policies
  - Clear explanation of location data collection and usage
  - Explicit mention of background location tracking
  - User-friendly consent flow before requesting permissions

### Changed
- Modified Shade Type field to show different values based on plantation type
- Enhanced form field validation with automatic decimal place rounding
- Improved form layout with optimized field grouping
- Updated dropdown handling to prevent value mismatch errors
- Improved location permission request flow to comply with Google Play policies
- Enhanced user communication regarding location permission requirements
- Updated Play Core libraries to app-update 2.1.0 for Android 14 compatibility

### Fixed
- Dropdown value assertion errors in plantation category selection
- Form field state update issues during validation
- Text controller update timing in validation logic
- Google Play Store compliance issues with background location usage
- Android 14 compatibility issues with broadcast receivers in Play Core libraries

## [2.3.3] - 2024-03-31

### Added
- New plantation type categorization system with specific categories for each type
- Separate workflows for Coffee Nursery, Shade Plantation, and Coffee Plantation

### Changed
- Restructured plantation category selection based on plantation type
- Modified validation logic for different plantation types

### Fixed
- Null-related errors in plantation type selection
- Category validation issues in shade details form

## [2.0.0] - 2024-03-31

### Added
- Background location tracking functionality
- Coffee nursery tracking and management features
- Native debug symbols generation for better crash reporting
- SuperAdmin role operations
- New workflow steps for improved development process
- New plantation type categorization system with specific categories for each type
- Separate workflows for Coffee Nursery, Shade Plantation, and Coffee Plantation

### Changed
- Updated form field configurations
- Enhanced device width constraints for better UI
- Improved form data structure for Coffee Nursery tracking
- Updated Play Integrity configuration
- Optimized build settings
- Restructured plantation category selection based on plantation type
- Modified validation logic for different plantation types

### Fixed
- Various permission issues
- Minor bugs and workflow improvements
- Debug symbols structure for Play Store
- macOS metadata exclusion from debug symbols
- Recovery artifact handling
- Null-related errors in plantation type selection
- Category validation issues in shade details form

## [1.2.3] - 2024-03-19

### Fixed
- Resolved GitHub Actions cache conflicts in CI/CD pipelines
- Fixed context access permissions in GitHub workflows
- Improved Gradle caching mechanism for faster builds
- Enhanced workflow permissions for better GitHub Actions integration

### Changed
- Updated Kotlin version to 1.9.23
- Optimized CI/CD cache configurations
- Improved build system stability

## [1.1.0] - 2024-02-14

### Added
- Multiple image capture support with GPS location tagging
- Offline data persistence with automatic sync
- Interactive polygon drawing on map
- Admin dashboard for plantation management
- Role-based access control system
- Real-time area and perimeter calculations
- Support for shade tree documentation
- Detailed plantation information recording

### Changed
- Enhanced UI with Material Design 3
- Improved map interaction and GPS accuracy
- Optimized image compression and storage
- Better error handling and user feedback
- Updated Firebase security rules

### Fixed
- GPS accuracy improvements in low-signal areas
- Data synchronization issues in offline mode
- Memory optimization for large plantation areas
- Image upload and storage optimizations
- Map rendering performance in polygon mode

## [1.0.0] - 2024-01-01

### Added
- Initial release
- GPS-based plantation area mapping
- Google Maps integration with satellite view
- Firebase Authentication with email/password
- Cloud Firestore integration for data storage
- Basic plantation management features
- Offline capability
- Image capture and storage
- Area and perimeter calculations 