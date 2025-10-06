#!/bin/bash

# Android Emulator Network Fix Script for Safe Voice Firebase App

echo "🔧 Android Emulator Network Diagnostics & Fix"
echo "=============================================="

# Check if emulator is running
adb devices | grep emulator
if [ $? -ne 0 ]; then
    echo "❌ No Android emulator detected. Please start your emulator first."
    exit 1
fi

echo "📱 Android emulator detected!"

# Test basic connectivity
echo "🌐 Testing basic connectivity..."
adb shell ping -c 3 8.8.8.8 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Basic internet connectivity: OK"
else
    echo "❌ Basic internet connectivity: FAILED"
    echo "   Trying to restart network..."
    adb shell svc wifi disable
    sleep 2
    adb shell svc wifi enable
    sleep 5
fi

# Test DNS resolution
echo "🔍 Testing DNS resolution..."
adb shell ping -c 2 google.com 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ DNS resolution: OK"
else
    echo "❌ DNS resolution: FAILED"
    echo "   Setting DNS servers..."
    adb shell settings put global private_dns_mode hostname
    adb shell settings put global private_dns_specifier dns.google
fi

# Test Firebase endpoints
echo "🔥 Testing Firebase endpoints..."
adb shell ping -c 2 firestore.googleapis.com 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Firestore endpoint: OK"
else
    echo "❌ Firestore endpoint: FAILED"
fi

adb shell ping -c 2 firebase.googleapis.com 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Firebase Storage endpoint: OK"
else
    echo "❌ Firebase Storage endpoint: FAILED"
fi

# Cold boot recommendation
echo ""
echo "💡 If tests still fail, try cold booting the emulator:"
echo "   1. Close the emulator completely"
echo "   2. In Android Studio AVD Manager, click the down arrow next to your emulator"
echo "   3. Select 'Cold Boot Now'"
echo "   4. Wait for the emulator to fully boot"
echo "   5. Run this script again"

echo ""
echo "🚀 Network diagnostics complete!"
echo "   If Firebase endpoints are reachable, try the Firebase test button in the app."
