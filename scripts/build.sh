#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [dev|prod] [version]"
    echo "  dev  - Build debug APK with development configuration"
    echo "  prod - Build release APK with production configuration"
    echo "  version - Version number (e.g., 1.0.0)"
    exit 1
}

# Function to handle errors
handle_error() {
    echo "Error: $1"
    # Restore pubspec if error occurs
    if [ -f "pubspec.yaml.bak" ]; then
        mv pubspec.yaml.bak pubspec.yaml
    fi
    exit 1
}

# Function to update pubspec version
update_pubspec_version() {
    local version=$1
    # Create backup of original pubspec
    cp pubspec.yaml pubspec.yaml.bak || handle_error "Failed to backup pubspec.yaml"
    
    # Update version in pubspec.yaml
    sed -i '' "s/^version: .*/version: $version/" pubspec.yaml || handle_error "Failed to update version in pubspec.yaml"
    
    echo "Updated pubspec.yaml version to $version"
}

# Function to restore pubspec
restore_pubspec() {
    if [ -f "pubspec.yaml.bak" ]; then
        mv pubspec.yaml.bak pubspec.yaml || handle_error "Failed to restore pubspec.yaml"
        echo "Restored original pubspec.yaml"
    fi
}

# Function to convert version to build number
version_to_build_number() {
    local version=$1
    # Remove dots and convert to integer
    echo "${version//./}"
}

# Check if arguments are provided
if [ $# -lt 1 ]; then
    usage
fi

# Set environment based on argument
ENV=$1
VERSION=${2:-"1.0.0"}  # Use provided version or default to 1.0.0
BUILD_NUMBER=$(version_to_build_number $VERSION)
BUILD_DIR="builds/${ENV}"

# Create builds directory if it doesn't exist
mkdir -p "$BUILD_DIR"

case $ENV in
    "dev")
        echo "Building development APK..."
        OUTPUT_NAME="coffee_mapper_dev_${VERSION}"
        BUILD_TYPE="--debug"
        ENV_FLAG=""
        FIREBASE_CONFIG="google-services-dev.json"
        MAPS_API_KEY="AIzaSyBGfU3qCOTfqg52zENVopgHNTL0riF_zrg"
        ;;
    "prod")
        echo "Building production APK and AAB..."
        OUTPUT_NAME="coffee_mapper_${VERSION}"
        BUILD_TYPE="--release"
        ENV_FLAG="--dart-define=ENVIRONMENT=production"
        FIREBASE_CONFIG="google-services-prod.json"
        MAPS_API_KEY="AIzaSyAyye03zRtYOKOHFdtOvo99MnyHxzm6wBg"
        ;;
    *)
        usage
        ;;
esac

# Check if Firebase config exists
if [ ! -f "android/app/${FIREBASE_CONFIG}" ]; then
    handle_error "Firebase configuration file not found: android/app/${FIREBASE_CONFIG}"
fi

# Clean the project
echo "Cleaning project..."
flutter clean || handle_error "Failed to clean project"

# Update pubspec version
update_pubspec_version "$VERSION"

# Copy Firebase configuration
echo "Copying Firebase configuration..."
cp "android/app/${FIREBASE_CONFIG}" "android/app/google-services.json" || handle_error "Failed to copy Firebase config"

# Update Maps API key
echo "Updating Maps API key for ${ENV} environment..."
mkdir -p "android/app/src/main/res/values"
cat > "android/app/src/main/res/values/strings.xml" << EOL
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="maps_api_key">${MAPS_API_KEY}</string>
</resources>
EOL

# Build APK
echo "Building APK..."
flutter build apk $BUILD_TYPE $ENV_FLAG --build-name="$VERSION" --build-number="$BUILD_NUMBER" || handle_error "Failed to build APK"

# For production builds, also generate AAB and debug symbols
if [ $ENV == "prod" ]; then
    echo "Building AAB..."
    flutter build appbundle $BUILD_TYPE $ENV_FLAG --build-name="$VERSION" --build-number="$BUILD_NUMBER" || handle_error "Failed to build AAB"
    
    echo "Generating debug symbols..."
    ./scripts/generate_symbols.sh release || handle_error "Failed to generate debug symbols"
    
    # Copy AAB to builds directory
    cp "build/app/outputs/bundle/release/app-release.aab" "${BUILD_DIR}/${OUTPUT_NAME}.aab" || handle_error "Failed to copy AAB to builds directory"
    
    # Copy debug symbols to builds directory
    cp "build/symbols_release.zip" "${BUILD_DIR}/${OUTPUT_NAME}_symbols.zip" || handle_error "Failed to copy debug symbols to builds directory"
fi

# Copy and rename the APK
if [ $ENV == "dev" ]; then
    SOURCE_APK="build/app/outputs/flutter-apk/app-debug.apk"
else
    SOURCE_APK="build/app/outputs/flutter-apk/app-release.apk"
fi

# Check if source APK exists
if [ ! -f "$SOURCE_APK" ]; then
    handle_error "Built APK not found at: $SOURCE_APK"
fi

# Copy APK to builds directory
cp "$SOURCE_APK" "${BUILD_DIR}/${OUTPUT_NAME}.apk" || handle_error "Failed to copy APK to builds directory"

# Restore original pubspec
restore_pubspec

echo "Build completed successfully!"
echo "Build directory: ${BUILD_DIR}"
echo "Environment: ${ENV}"
echo "Version: ${VERSION}"
echo "Build number: ${BUILD_NUMBER}"

if [ $ENV == "prod" ]; then
    echo "Generated files:"
    echo "- APK: ${OUTPUT_NAME}.apk"
    echo "- AAB: ${OUTPUT_NAME}.aab"
    echo "- Debug Symbols: ${OUTPUT_NAME}_symbols.zip"
else
    echo "Generated file:"
    echo "- APK: ${OUTPUT_NAME}.apk"
fi 