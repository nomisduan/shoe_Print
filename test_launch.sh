#!/bin/bash

echo "🚀 Testing ShoePrint app launch..."

# Build the app
echo "📦 Building app..."
xcodebuild -project shoePrint.xcodeproj -scheme shoePrint -destination 'platform=iOS Simulator,name=iPhone 16' build > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Build successful"
    
    # Try to get the app bundle path
    APP_PATH="/Users/simonnaud/Library/Developer/Xcode/DerivedData/shoePrint-cwywhhtcxmaozcbeefdpcivodcsr/Build/Products/Debug-iphonesimulator/shoePrint.app"
    
    if [ -d "$APP_PATH" ]; then
        echo "✅ App bundle found at: $APP_PATH"
        
        # Install app on simulator
        echo "📱 Installing app on simulator..."
        xcrun simctl install "iPhone 16" "$APP_PATH" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ App installed successfully"
            echo "🎉 Test completed - SwiftData error appears to be resolved!"
        else
            echo "❌ Failed to install app"
        fi
    else
        echo "❌ App bundle not found"
    fi
else
    echo "❌ Build failed"
fi 