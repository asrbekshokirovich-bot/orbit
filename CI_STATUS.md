# Orbit CI status
date: Thu Jul 16 09:26:53 UTC 2026
APK_OK: yes

## analyze (tail)
Analyzing orbit...                                              

   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart' • lib/voice.dart:4:8 • unnecessary_import
   info • Uses 'await' on an instance of 'Stream<Uint8List>', which is not a subtype of 'Future' • lib/voice.dart:64:16 • await_only_futures

2 issues found. (ran in 10.2s)

## test (tail)

✅ pcmToWav writes a valid 44-byte RIFF/WAVE header
✅ pcmToWav preserves sample bytes after the header

🎉 2 tests passed.

## build (tail)

Support for Android x86 targets will be removed in the next stable release after 3.27. See https://github.com/flutter/flutter/issues/157543 for details.
Running Gradle task 'assembleDebug'...                          
Checking the license for package Android SDK Build-Tools 33.0.1 in /usr/local/lib/android/sdk/licenses
License for package Android SDK Build-Tools 33.0.1 accepted.
Preparing "Install Android SDK Build-Tools 33.0.1 v.33.0.1".
"Install Android SDK Build-Tools 33.0.1 v.33.0.1" ready.
Installing Android SDK Build-Tools 33.0.1 in /usr/local/lib/android/sdk/build-tools/33.0.1
"Install Android SDK Build-Tools 33.0.1 v.33.0.1" complete.
"Install Android SDK Build-Tools 33.0.1 v.33.0.1" finished.
Checking the license for package Android SDK Platform 33 in /usr/local/lib/android/sdk/licenses
License for package Android SDK Platform 33 accepted.
Preparing "Install Android SDK Platform 33 (revision 3)".
"Install Android SDK Platform 33 (revision 3)" ready.
Installing Android SDK Platform 33 in /usr/local/lib/android/sdk/platforms/android-33
"Install Android SDK Platform 33 (revision 3)" complete.
"Install Android SDK Platform 33 (revision 3)" finished.
Note: /home/runner/.pub-cache/hosted/pub.dev/mic_stream-0.7.2/android/src/main/java/com/code/aaron/micstream/MicStreamPlugin.java uses or overrides a deprecated API.
Note: Recompile with -Xlint:deprecation for details.
Note: /home/runner/.pub-cache/hosted/pub.dev/mic_stream-0.7.2/android/src/main/java/com/code/aaron/micstream/MicStreamPlugin.java uses unchecked or unsafe operations.
Note: Recompile with -Xlint:unchecked for details.
Running Gradle task 'assembleDebug'...                            210.9s
✓ Built build/app/outputs/flutter-apk/app-debug.apk

## apk
-rw-r--r-- 1 runner runner 190200505 Jul 16 09:26 out/Orbit.apk
