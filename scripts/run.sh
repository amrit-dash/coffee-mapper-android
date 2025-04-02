#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [dev|prod]"
    echo "  dev  - Run app in development mode"
    echo "  prod - Run app in production mode"
    exit 1
}

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to check device
check_device() {
    # Get list of devices
    DEVICES=$(flutter devices)
    if [[ $DEVICES == *"No devices available"* ]]; then
        handle_error "No devices connected. Please connect a device or start an emulator."
    fi
    
    echo "Available devices:"
    echo "$DEVICES"
    echo ""
}

# Check if argument is provided
if [ $# -ne 1 ]; then
    usage
fi

# Set environment based on argument
ENV=$1

case $ENV in
    "dev")
        echo "Running in development mode..."
        BUILD_TYPE="--debug"
        ENV_FLAG=""
        FIREBASE_CONFIG="google-services-dev.json"
        MAPS_API_KEY="AIzaSyBGfU3qCOTfqg52zENVopgHNTL0riF_zrg"
        ;;
    "prod")
        echo "Running in production mode..."
        BUILD_TYPE="--release"
        ENV_FLAG="--dart-define=ENVIRONMENT=production"
        FIREBASE_CONFIG="google-services-prod.json"
        MAPS_API_KEY="AIzaSyAyye03zRtYOKOHFdtOvo99MnyHxzm6wBg"
        ;;
    *)
        usage
        ;;
esac

# Check for connected devices
check_device

# Check if Firebase config exists
if [ ! -f "android/app/${FIREBASE_CONFIG}" ]; then
    handle_error "Firebase configuration file not found: android/app/${FIREBASE_CONFIG}"
fi

# Copy Firebase configuration
echo "Copying Firebase configuration..."
cp "android/app/${FIREBASE_CONFIG}" "android/app/google-services.json" || handle_error "Failed to copy Firebase config"

# Update Maps API key
echo "Updating Maps API key for ${ENV} environment..."
cat > "android/app/src/main/res/values/strings.xml" << EOL
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="maps_api_key">${MAPS_API_KEY}</string>
</resources>
EOL

# Run the app
echo "Running app in ${ENV} environment..."
echo "Build type: ${BUILD_TYPE}"
echo "Environment flags: ${ENV_FLAG}"
echo ""
echo "Note: Use 'r' to hot-reload, 'R' to restart, or 'q' to quit"
echo "-----------------------------------------------------------"

flutter run $BUILD_TYPE $ENV_FLAG || handle_error "Failed to run app" 