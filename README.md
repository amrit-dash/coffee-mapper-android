# Coffee Mapper

<div align="center">

![Coffee Mapper Logo](https://i.ibb.co/zWyCyM2x/logo-white.png)

[![Flutter](https://img.shields.io/badge/Flutter-3.5.4-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.5.0-blue.svg)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/yourusername/coffee_mapper/graphs/commit-activity)
[![Made with Love](https://img.shields.io/badge/Made%20with-❤️-red.svg)](https://about.me/amritdash)

An Android application for Coffee Development Trust, Koraput to track and manage Coffee Plantations.

[Features](#features) • [Installation](#installation) • [Environment Setup](#environment-setup) • [Usage](#usage) • [Contributing](#contributing) • [License](#license) • [Download](#download)

---

### 🚀 Quick Links

[![Development Build](https://img.shields.io/badge/Download-Development%20Build-blue.svg)](https://drive.google.com/drive/folders/1C8NwMaO70dq4D4__WbDC1XxzWfgl8KTY?usp=drive_link)
[![Production Build](https://img.shields.io/badge/Download-Production%20Build-green.svg)](https://drive.google.com/drive/folders/1Dkw3vWBz7sl_wriKBSacS3obYar-UhYu?usp=drive_link)

![App Screenshots](https://i.ibb.co/b5C6mh6f/1.png)

</div>

## ✨ Features

🗺️ **Interactive Mapping**
- Plot coffee plantation areas using GPS coordinates
- Real-time area and perimeter calculations
- Satellite view integration with Google Maps
- Support for multiple image captures with location tagging

📱 **User-Friendly Interface**
- Clean and modern Material Design
- Intuitive navigation
- Responsive layout
- Offline capability with data sync

🔐 **Secure Authentication**
- Firebase Authentication integration
- Role-based access control
- Admin dashboard for user management

📊 **Plantation Management**
- Detailed plantation information recording
- Image capture and storage
- Historical data tracking
- Area-wise categorization

🔄 **Sync & Backup**
- Automatic data synchronization
- Offline data persistence
- Secure cloud storage for images
- Real-time updates

## 📥 Installation

### Prerequisites

1. Flutter SDK (^3.5.4)
2. Android Studio
3. Java Development Kit (JDK)
4. Firebase Account
5. Google Maps API Key

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/coffee_mapper.git
   cd coffee_mapper
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Follow the [Environment Setup](#environment-setup) instructions below.

## ⚙️ Environment Setup

This project uses separate environments for development and production. Each environment has its own:
- Firebase project
- Google Maps API key
- Package name

### Initial Setup

When setting up the project for the first time:

1. Create necessary directories and copy template files:
   ```bash
   # Create directories
   mkdir -p android/app/src/debug/res/values/
   mkdir -p android/app/src/main/res/values/
   
   # Copy API Key templates
   cp templates/strings.xml.template android/app/src/main/res/values/strings.xml
   cp templates/strings.debug.xml.template android/app/src/debug/res/values/strings.xml
   
   # Copy keystore configuration template
   cp templates/key.properties.template android/key.properties
   ```

2. Update the copied files with your actual values:
   - Add your Maps API keys to both `strings.xml` files
   - Update `key.properties` with your keystore details

### Firebase Configuration

1. Place your Firebase configuration files:
   - Development: `android/app/google-services-dev.json`
   - Production: `android/app/google-services-prod.json`

2. Enable required Firebase services:
   - Authentication
   - Cloud Firestore
   - Cloud Storage
   - Crashlytics
   - App Check

### Google Maps Configuration

Configure Google Maps API keys in:
1. Native Android configuration:
   - Debug: `android/app/src/debug/res/values/strings.xml`
   - Release: `android/app/src/main/res/values/strings.xml`
2. Dart configuration in `lib/config/app_config.dart`

## 🚀 Usage

### Building the App

Use the provided build scripts:

```bash
# Development build
./scripts/build.sh dev 1.0.0

# Production build
./scripts/build.sh prod 1.0.0
```

### Running the App

Use the run script for development:

```bash
# Run development version
./scripts/run.sh dev

# Production version
./scripts/run.sh prod
```

### Security Notes

The following files contain sensitive information and should not be committed to version control:
- `google-services-dev.json`
- `google-services-prod.json`
- `key.properties`
- `*.jks` (keystore files)
- `android/app/src/*/res/values/strings.xml`

## 📱 Download

You can download the latest APK builds from the following links:

- [Development Build](https://drive.google.com/drive/folders/1C8NwMaO70dq4D4__WbDC1XxzWfgl8KTY?usp=drive_link) - For testing and development purposes
- [Production Build](https://drive.google.com/drive/folders/1Dkw3vWBz7sl_wriKBSacS3obYar-UhYu?usp=drive_link) - For end users

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a new branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test thoroughly
5. Create a pull request

Please read our [Contributing Guidelines](CONTRIBUTING.md) for more details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter Team for the amazing framework
- Firebase for the robust backend services
- Google Maps Platform for mapping services
- Coffee Development Trust, Koraput for their support

## 👨‍💻 Author

**Amrit Dash**
- Website: [about.me/amritdash](https://about.me/amritdash)
- Twitter: [@amritdash](https://twitter.com/amritdash)
- Email: [amrit.dash60@gmail.com](mailto:amrit.dash60@gmail.com)

## 📞 Support

If you need help or have any questions, please email us at [geospatialtech.production@gmail.com](mailto:geospatialtech.production@gmail.com)

---

<div align="center">

Made with ❤️ for Coffee Development Trust, Koraput

<sub>If you found this project helpful, please consider giving it a ⭐️</sub>

</div>
