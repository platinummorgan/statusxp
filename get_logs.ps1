# Run this after opening games list:
adb logcat -d | Select-String -Pattern "DEBUG:|ERROR|Last trophy"
