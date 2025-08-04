#!/bin/bash

# BongoCat App Store Upload Script
# Uploads IPA file to App Store Connect using command line tools

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Get to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

APP_NAME="BongoCat"
BUNDLE_ID="com.leaptech.bongocat"

# Parse command line arguments
IPA_FILE=""
UPLOAD_METHOD="auto"
VERIFY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --ipa)
            IPA_FILE="$2"
            shift 2
            ;;
        --method)
            UPLOAD_METHOD="$2"
            shift 2
            ;;
        --verify)
            VERIFY_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--ipa <file>] [--method <altool|notarytool|auto>] [--verify] [--help]"
            echo ""
            echo "Options:"
            echo "  --ipa <file>     Specify IPA file to upload (auto-detects if not specified)"
            echo "  --method <tool>  Use specific upload method: altool, notarytool, or auto"
            echo "  --verify         Only verify credentials, don't upload"
            echo "  --help           Show this help message"
            echo ""
            echo "Environment variables required:"
            echo "  APPLE_ID         Your Apple ID email"
            echo "  APPLE_ID_PASSWORD Your app-specific password"
            echo "  TEAM_ID          Your Apple Developer Team ID"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🍎 BongoCat App Store Upload Script"
echo "==================================="
echo ""

# Check required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ]; then
    print_error "Apple ID credentials not set"
    echo ""
    echo "💡 Set environment variables:"
    echo "   export APPLE_ID='your-apple-id@example.com'"
    echo "   export APPLE_ID_PASSWORD='your-app-specific-password'"
    echo "   export TEAM_ID='your-team-id'"
    echo ""
    echo "📝 Note: Use an app-specific password if you have 2FA enabled"
    exit 1
fi

print_success "Apple ID credentials found: $APPLE_ID"

# Auto-detect IPA file if not specified
if [ -z "$IPA_FILE" ]; then
    echo "🔍 Auto-detecting IPA file..."

    # Look for the most recent IPA file
    IPA_FILE=$(find Build/ -name "BongoCat-*-AppStore.ipa" -type f | sort -r | head -1)

    if [ -z "$IPA_FILE" ]; then
        print_error "No IPA file found in Build/ directory"
        echo ""
        echo "💡 Create an IPA file first:"
        echo "   ./run.sh --app-store"
        echo "   ./Scripts/package_app.sh --app_store"
        exit 1
    fi

    print_success "Found IPA file: $IPA_FILE"
else
    if [ ! -f "$IPA_FILE" ]; then
        print_error "IPA file not found: $IPA_FILE"
        exit 1
    fi
    print_success "Using specified IPA file: $IPA_FILE"
fi

# Verify IPA file
echo ""
echo "🔍 Verifying IPA file..."
if [ -f "$IPA_FILE" ]; then
    file_size=$(du -h "$IPA_FILE" | cut -f1)
    print_success "IPA file exists: $file_size"

    # Check if it's a valid ZIP file
    if unzip -t "$IPA_FILE" >/dev/null 2>&1; then
        print_success "IPA file is valid ZIP archive"
    else
        print_error "IPA file is not a valid ZIP archive"
        exit 1
    fi

    # Check for Payload/BongoCat.app structure
    if unzip -l "$IPA_FILE" | grep -q "Payload/BongoCat.app"; then
        print_success "IPA contains valid app bundle structure"
    else
        print_warning "IPA may not contain expected app bundle structure"
    fi
else
    print_error "IPA file not found: $IPA_FILE"
    exit 1
fi

# Function to verify credentials
verify_credentials() {
    echo ""
    echo "🔐 Verifying Apple Developer credentials..."

    # Try altool first
    if command -v xcrun &> /dev/null; then
        print_info "Testing with altool..."
        if xcrun altool --list-providers -u "$APPLE_ID" -p "$APPLE_ID_PASSWORD" >/dev/null 2>&1; then
            print_success "altool credentials verified"
            return 0
        else
            print_warning "altool credentials failed"
        fi
    fi

    # Try notarytool
    if command -v xcrun &> /dev/null; then
        print_info "Testing with notarytool..."
        if xcrun notarytool info --apple-id "$APPLE_ID" --password "$APPLE_ID_PASSWORD" >/dev/null 2>&1; then
            print_success "notarytool credentials verified"
            return 0
        else
            print_warning "notarytool credentials failed"
        fi
    fi

    print_error "Could not verify credentials with any tool"
    return 1
}

# Function to upload with altool
upload_with_altool() {
    echo ""
    echo "📤 Uploading with altool..."

    if ! command -v xcrun &> /dev/null; then
        print_error "xcrun not available"
        return 1
    fi

    print_info "Starting upload with altool..."

    # For macOS, we need to use the app bundle directly, not IPA
    print_warning "altool expects app bundle for macOS, not IPA file"
    print_info "Using app bundle for macOS upload..."

    local app_bundle="Build/package/${APP_NAME}.app"
    if [ ! -d "$app_bundle" ]; then
        print_error "App bundle not found: $app_bundle"
        echo ""
        echo "💡 Create the app bundle first:"
        echo "   ./run.sh --app-store"
        return 1
    fi

    # Create a temporary zip for upload
    local temp_zip="/tmp/${APP_NAME}-upload.zip"
    print_info "Creating temporary zip for upload..."
    ditto -c -k --keepParent "$app_bundle" "$temp_zip"

        # Upload the app
    print_info "Uploading to App Store Connect..."
    print_warning "Note: App must exist in App Store Connect first"

    upload_output=$(xcrun altool --upload-app \
        --type macos \
        --file "$temp_zip" \
        --username "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --verbose 2>&1)

    upload_exit_code=$?

    # Clean up temp file
    rm -f "$temp_zip"

    if [ $upload_exit_code -eq 0 ] && echo "$upload_output" | grep -q "No errors uploading"; then
        print_success "Upload completed successfully with altool!"
        echo ""
        echo "📋 Upload details:"
        echo "$upload_output" | grep -E "(No errors|RequestUUID|Product ID)"
        return 0
    elif echo "$upload_output" | grep -q "No suitable application records were found"; then
        print_error "App not found in App Store Connect"
        echo ""
        echo "💡 Solution: Create the app in App Store Connect first"
        echo ""
        echo "📋 Steps to create the app:"
        echo "   1. Go to https://appstoreconnect.apple.com"
        echo "   2. Click 'My Apps'"
        echo "   3. Click '+' to add a new app"
        echo "   4. Select 'macOS' as platform"
        echo "   5. Enter app details:"
        echo "      • Name: BongoCat"
        echo "      • Bundle ID: $BUNDLE_ID"
        echo "      • SKU: bongocat-macos (or any unique identifier)"
        echo "   6. Click 'Create'"
        echo "   7. Run this script again"
        return 1
    elif echo "$upload_output" | grep -q "ERROR ITMS-"; then
        print_error "Upload failed with ITMS error:"
        echo "$upload_output" | grep "ERROR ITMS-"
        echo ""
        echo "💡 Common solutions:"
        echo "   1. Create the app in App Store Connect first"
        echo "   2. Check that Bundle ID matches: $BUNDLE_ID"
        echo "   3. Verify app metadata in App Store Connect"
        return 1
    else
        print_error "Upload failed with altool:"
        echo "$upload_output"
        return 1
    fi
}

# Function to upload with notarytool
upload_with_notarytool() {
    echo ""
    echo "📤 Uploading with notarytool..."

    if ! command -v xcrun &> /dev/null; then
        print_error "xcrun not available"
        return 1
    fi

    print_info "Starting upload with notarytool..."

    # Get team ID if not set
    if [ -z "$TEAM_ID" ]; then
        print_info "Getting team ID automatically..."
        team_info=$(xcrun notarytool info --apple-id "$APPLE_ID" --password "$APPLE_ID_PASSWORD" 2>/dev/null)
        if echo "$team_info" | grep -q "team_id:"; then
            TEAM_ID=$(echo "$team_info" | grep "team_id:" | awk '{print $2}')
            print_success "Found Team ID: $TEAM_ID"
        else
            print_error "Could not automatically determine Team ID"
            echo "💡 Please set your Team ID:"
            echo "   export TEAM_ID='your-team-id'"
            return 1
        fi
    fi

    # Submit for notarization (this is different from App Store upload)
    print_warning "notarytool is for notarization, not App Store upload"
    print_info "Using notarytool for notarization instead..."

    # Create temporary zip for notarization
    temp_zip="/tmp/${APP_NAME}-notarize.zip"
    print_info "Creating temporary zip for notarization..."
    ditto -c -k --keepParent "Build/package/${APP_NAME}.app" "$temp_zip"

    # Submit for notarization
    upload_output=$(xcrun notarytool submit "$temp_zip" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" 2>&1)

    if echo "$upload_output" | grep -q "id:"; then
        submission_id=$(echo "$upload_output" | grep -m1 "id:" | awk '{print $2}')
        print_success "Notarization submitted! ID: $submission_id"

        echo "⏳ Waiting for notarization to complete..."
        echo "   This can take 5-15 minutes..."

        # Wait for completion
        while true; do
            status_output=$(xcrun notarytool wait "$submission_id" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_ID_PASSWORD" \
                --team-id "$TEAM_ID" 2>&1)

            if echo "$status_output" | grep -q "status: Accepted"; then
                print_success "Notarization completed successfully!"
                break
            elif echo "$status_output" | grep -q "status: Invalid"; then
                print_error "Notarization failed!"
                log_output=$(xcrun notarytool log "$submission_id" \
                    --apple-id "$APPLE_ID" \
                    --password "$APPLE_ID_PASSWORD" \
                    --team-id "$TEAM_ID" 2>&1)
                echo "$log_output"
                return 1
            else
                echo "⏳ Still processing... (checking again in 30 seconds)"
                sleep 30
            fi
        done

        # Clean up
        rm -f "$temp_zip"
        return 0
    else
        print_error "Notarization submission failed:"
        echo "$upload_output"
        rm -f "$temp_zip"
        return 1
    fi
}

# Function to auto-detect best upload method
auto_upload() {
    echo ""
    echo "🤖 Auto-detecting best upload method..."

    # Try altool first (for App Store upload)
    if command -v xcrun &> /dev/null; then
        if xcrun altool --list-providers -u "$APPLE_ID" -p "$APPLE_ID_PASSWORD" >/dev/null 2>&1; then
            print_info "Using altool for App Store upload"
            upload_with_altool
            return $?
        fi
    fi

    # Fall back to notarytool (for notarization)
    if command -v xcrun &> /dev/null; then
        print_info "Falling back to notarytool for notarization"
        upload_with_notarytool
        return $?
    fi

    print_error "No suitable upload method found"
    return 1
}

# Main execution
if [ "$VERIFY_ONLY" = true ]; then
    verify_credentials
    exit $?
fi

# Verify credentials first
if ! verify_credentials; then
    print_error "Credential verification failed"
    exit 1
fi

# Upload based on method
case $UPLOAD_METHOD in
    "altool")
        upload_with_altool
        ;;
    "notarytool")
        upload_with_notarytool
        ;;
    "auto")
        auto_upload
        ;;
    *)
        print_error "Unknown upload method: $UPLOAD_METHOD"
        echo "Valid methods: altool, notarytool, auto"
        exit 1
        ;;
esac

upload_result=$?

echo ""
if [ $upload_result -eq 0 ]; then
    print_success "Upload process completed successfully!"
    echo ""
    echo "🎉 Next steps:"
    echo "   1. Check App Store Connect for your uploaded build"
    echo "   2. Complete the submission process in App Store Connect"
    echo "   3. Add metadata, screenshots, and descriptions"
    echo "   4. Submit for review"
else
    print_error "Upload process failed"
    echo ""
    echo "💡 Alternative upload methods:"
    echo "   • Use Transporter app (download from App Store)"
    echo "   • Use Xcode Organizer (Window > Organizer)"
    echo "   • Use Application Loader (legacy)"
fi