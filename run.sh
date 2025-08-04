#!/bin/bash

# BongoCat Build Menu Script
# Interactive menu to run different build and package commands

print_info "Sourcing .env file..."
source .env

# Function to show usage
show_usage() {
    echo "🐱 BongoCat Build Script"
    echo "========================"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --verify, -v          Verify setup and dependencies"
    echo "  --debug-run, -dr      Build debug app and run"
    echo "  --debug-package, -dp  Build debug app and package"
    echo "  --debug-install, -di  Build debug app, package and install locally"
    echo "  --release-run, -rr    Build release app and run"
    echo "  --release-package, -rp Build release app and package"
    echo "  --release-install, -ri Build release app, package and install locally"
    echo "  --deliver, -d         Bump version, build release, sign, notarize and deliver to GitHub"
    echo "  --deliver-push, -dp   Bump version with commit/push, build release, sign, notarize and deliver"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --verify"
    echo "  $0 --debug-run"
    echo "  $0 --release-package"
    echo "  $0 --deliver 1.3.0"
    echo ""
    echo "🔐 Code Signing & Notarization:"
    echo "  • Delivery options automatically sign and notarize the app"
    echo "  • Requires Apple Developer certificate for notarization"
    echo "  • Set APPLE_ID and APPLE_ID_PASSWORD for notarization"
    echo "  • Falls back to ad-hoc signing if no certificate available"
    echo ""
    echo "If no arguments are provided, the interactive menu will be shown."
}

# Function to check delivery prerequisites
check_delivery_prerequisites() {
    echo "🔍 Checking delivery prerequisites..."

    # Check for Apple ID credentials for notarization
    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
        echo "⚠️  Apple notarization credentials not fully set"
        if [ -z "$APPLE_ID" ]; then
            echo "   • APPLE_ID not set"
        fi
        if [ -z "$APPLE_ID_PASSWORD" ]; then
            echo "   • APPLE_ID_PASSWORD not set"
        fi
        if [ -z "$TEAM_ID" ]; then
            echo "   • TEAM_ID not set"
        fi
        echo "   • App will be delivered without notarization"
        echo "   • Users may see security warnings on first launch"
        echo "   • To enable notarization, set:"
        echo "     export APPLE_ID='your-apple-id@example.com'"
        echo "     export APPLE_ID_PASSWORD='your-app-specific-password'"
        echo "     export TEAM_ID='your-team-id'"
        echo ""
    else
        echo "✅ Apple ID credentials and Team ID found - notarization will be attempted"
    fi

    # Check for code signing certificate
    if [ -f "Scripts/code_sign.sh" ]; then
        source "Scripts/code_sign.sh"
        if check_developer_certificate; then
            echo "✅ Apple Developer certificate found"
        else
            echo "⚠️  No Apple Developer certificate found - will use ad-hoc signing"
        fi
    else
        echo "⚠️  Code signing script not found"
    fi

    echo ""
}

# Function to execute the selected option
execute_option() {
    local choice=$1
    local version=$2

    case $choice in
        0)
            echo "🔍 Verifying setup and dependencies..."
            echo ""

            # Check if we're on macOS
            if [[ "$OSTYPE" != "darwin"* ]]; then
                echo "❌ Error: This script is designed for macOS only"
                exit 1
            fi
            echo "✅ macOS detected"

            # Check if Xcode Command Line Tools are installed
            if ! command -v xcodebuild &> /dev/null; then
                echo "❌ Error: Xcode Command Line Tools not found"
                echo "   Please install with: xcode-select --install"
                exit 1
            fi
            echo "✅ Xcode Command Line Tools found"

            # Check Swift version
            if ! command -v swift &> /dev/null; then
                echo "❌ Error: Swift not found"
                exit 1
            fi
            echo "✅ Swift found: $(swift --version | head -n 1)"

            # Check if we're in the right directory
            if [ ! -f "Package.swift" ]; then
                echo "❌ Error: Package.swift not found. Please run this script from the BongoCat-mac directory"
                exit 1
            fi
            echo "✅ Package.swift found"

            # Check if required scripts exist
            required_scripts=("Scripts/build.sh" "Scripts/package_app.sh" "Scripts/bump_version.sh")
            for script in "${required_scripts[@]}"; do
                if [ ! -f "$script" ]; then
                    echo "❌ Error: Required script not found: $script"
                    exit 1
                fi
            done
            echo "✅ All required scripts found"

            # Check if source files exist
            if [ ! -f "Sources/BongoCat/main.swift" ]; then
                echo "❌ Error: Main source file not found: Sources/BongoCat/main.swift"
                exit 1
            fi
            echo "✅ Main source file found"

            # Check if cat images exist
            if [ ! -f "Sources/BongoCat/Resources/Images/base.png" ]; then
                echo "❌ Error: Cat image resources not found"
                exit 1
            fi
            echo "✅ Cat image resources found"

            # Check if Info.plist exists
            if [ ! -f "Info.plist" ]; then
                echo "❌ Error: Info.plist not found"
                exit 1
            fi
            echo "✅ Info.plist found"

            # Try to resolve dependencies
            echo "📦 Resolving Swift Package dependencies..."
            if swift package resolve; then
                echo "✅ Dependencies resolved successfully"
            else
                echo "❌ Error: Failed to resolve dependencies"
                exit 1
            fi

            # Check if we can build the project
            echo "🔨 Testing build process..."
            if swift build --configuration debug; then
                echo "✅ Debug build successful"
            else
                echo "❌ Error: Debug build failed"
                exit 1
            fi

            echo ""
            echo "🎉 All checks passed! Your BongoCat development environment is ready."
            echo "   You can now proceed with building and packaging the app."
            echo ""
            echo "🔐 Code Signing Check:"
            # Source the code signing script to check certificate availability
            if [ -f "Scripts/code_sign.sh" ]; then
                source "Scripts/code_sign.sh"
                if check_developer_certificate; then
                    echo "✅ Apple Developer certificate found - notarization will be available"
                else
                    echo "⚠️  No Apple Developer certificate found - will use ad-hoc signing"
                    echo "   • Users will need to right-click and select 'Open' on first launch"
                    echo "   • Consider getting an Apple Developer certificate for distribution"
                fi
            else
                echo "⚠️  Code signing script not found - signing status unknown"
            fi
            ;;
        1)
            echo "🔨 Building debug app and running..."
            rm -rf ./build; ./Scripts/build.sh; swift run
            ;;
        2)
            echo "📦 Building debug app and packaging..."
            rm -rf ./build; rm -rf ./Build; ./Scripts/build.sh; ./Scripts/package_app.sh --debug
            ;;
        3)
            echo "📦 Building debug app, packaging and installing locally..."
            rm -rf ./build; rm -rf ./Build; ./Scripts/build.sh; ./Scripts/package_app.sh --debug --install_local
            ;;
        4)
            echo "🚀 Building release app and running..."
            rm -rf ./build; ./Scripts/build.sh -r; swift run --configuration release
            ;;
        5)
            echo "🚀 Building release app and packaging..."
            rm -rf ./build; rm -rf ./Build; ./Scripts/build.sh -r; ./Scripts/package_app.sh
            ;;
        6)
            echo "🚀 Building release app, packaging and installing locally..."
            rm -rf ./build; rm -rf ./Build; ./Scripts/build.sh -r; ./Scripts/package_app.sh --install_local
            ;;
        7)
            if [ -z "$version" ]; then
                echo "❌ Version number is required for deliver option!"
                echo "   Usage: $0 --deliver <version>"
                exit 1
            fi
            check_delivery_prerequisites
            echo "🏷️  Bumping version to $version, building release, signing, notarizing and delivering..."
            rm -rf ./build; rm -rf ./Build; ./Scripts/bump_version.sh $version; ./Scripts/build.sh -r; ./Scripts/package_app.sh --deliver --verify --sign-certificate
            ;;
        8)
            if [ -z "$version" ]; then
                echo "❌ Version number is required for deliver-push option!"
                echo "   Usage: $0 --deliver-push <version>"
                exit 1
            fi
            check_delivery_prerequisites
            echo "🏷️  Bumping version to $version with commit/push, building release, signing, notarizing and delivering..."
            rm -rf ./build; rm -rf ./Build; ./Scripts/bump_version.sh $version --push --commit; ./Scripts/build.sh -r; ./Scripts/package_app.sh --deliver --verify --sign-certificate
            ;;
        *)
            echo "❌ Invalid option."
            exit 1
            ;;
    esac
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    # No arguments provided, show interactive menu
    echo "🐱 BongoCat Build Menu"
    echo "======================"
    echo ""
    echo "Please select an option:"
    echo ""
    echo "0) Verify setup and dependencies"
    echo "1) Build debug app and run"
    echo "2) Build debug app and package"
    echo "3) Build debug app, package and install locally"
    echo "4) Build release app and run"
    echo "5) Build release app and package"
    echo "6) Build release app, package and install locally"
    echo "7) Bump version, build release, sign, notarize and deliver to GitHub"
    echo "8) Bump version with commit/push, build release, sign, notarize and deliver"
    echo "9) Exit"
    echo ""

    read -p "Enter your choice (0-9): " choice

    case $choice in
        0|1|2|3|4|5|6)
            execute_option $choice
            ;;
        7)
            read -p "Enter version number (e.g., 1.3.0): " version
            if [ -z "$version" ]; then
                echo "❌ Version number is required!"
                exit 1
            fi
            execute_option 7 "$version"
            ;;
        8)
            read -p "Enter version number (e.g., 1.3.0): " version
            if [ -z "$version" ]; then
                echo "❌ Version number is required!"
                exit 1
            fi
            execute_option 8 "$version"
            ;;
        9)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please choose 0-9."
            exit 1
            ;;
    esac
else
    # Parse command line arguments
    case "$1" in
        --verify|-v)
            execute_option 0
            ;;
        --debug-run|-dr)
            execute_option 1
            ;;
        --debug-package|-dp)
            execute_option 2
            ;;
        --debug-install|-di)
            execute_option 3
            ;;
        --release-run|-rr)
            execute_option 4
            ;;
        --release-package|-rp)
            execute_option 5
            ;;
        --release-install|-ri)
            execute_option 6
            ;;
        --deliver|-d)
            if [ -z "$2" ]; then
                echo "❌ Version number is required for deliver option!"
                echo "   Usage: $0 --deliver <version>"
                exit 1
            fi
            execute_option 7 "$2"
            ;;
        --deliver-push|-dp)
            if [ -z "$2" ]; then
                echo "❌ Version number is required for deliver-push option!"
                echo "   Usage: $0 --deliver-push <version>"
                exit 1
            fi
            execute_option 8 "$2"
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
fi

echo ""
echo "✅ Operation completed!"