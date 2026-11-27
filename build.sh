#!/bin/bash
# Construit BeloteDuSoir.apk (outils : aapt, javac, dalvik-exchange, zipalign, apksigner)
set -euo pipefail
cd "$(dirname "$0")"
AJ=${ANDROID_JAR:-/usr/lib/android-sdk/platforms/android-23/android.jar}
rm -rf build; mkdir -p build/gen build/classes
aapt package -f -m -J build/gen -M AndroidManifest.xml -S res -I "$AJ"
javac -nowarn -Xlint:-options -source 8 -target 8 -bootclasspath "$AJ" -d build/classes $(find src build/gen -name '*.java')
dalvik-exchange --dex --min-sdk-version=23 --output=build/classes.dex build/classes
aapt package -f -M AndroidManifest.xml -S res -A assets -I "$AJ" -F build/unsigned.apk
(cd build && aapt add unsigned.apk classes.dex >/dev/null && zipalign -f -p 4 unsigned.apk aligned.apk)
[ -f belote.keystore ] || keytool -genkeypair -keystore belote.keystore -alias belote -keyalg RSA -keysize 2048 -validity 10000 -storepass belote2026 -keypass belote2026 -dname "CN=Belote du Soir, C=FR"
apksigner sign --ks belote.keystore --ks-pass pass:belote2026 --ks-key-alias belote --out build/BeloteDuSoir.apk build/aligned.apk
apksigner verify build/BeloteDuSoir.apk && echo "OK : build/BeloteDuSoir.apk"
