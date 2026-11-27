#!/bin/bash
# Construit BeloteDuSoir.apk sur GitHub Actions
set -euo pipefail
cd "$(dirname "$0")"

# Localiser le SDK et les build-tools
ANDROID_SDK="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
BUILD_TOOLS=$(ls -d "$ANDROID_SDK/build-tools/"* | sort -V | tail -n 1)
AJ=$(find "$ANDROID_SDK/platforms" -name "android.jar" | sort -V | tail -n 1)

if [ -z "$AJ" ] || [ ! -f "$AJ" ]; then
    echo "Erreur : android.jar introuvable !"
    exit 1
fi

echo "Utilisation de android.jar : $AJ"
echo "Utilisation de build-tools : $BUILD_TOOLS"

rm -rf build; mkdir -p build/gen build/classes

# 1. Compilation des ressources avec aapt
"$BUILD_TOOLS/aapt" package -f -m -J build/gen -M AndroidManifest.xml -S res -I "$AJ"

# 2. Compilation Java
javac -nowarn -Xlint:-options -source 8 -target 8 -bootclasspath "$AJ" -d build/classes $(find src build/gen -name '*.java')

# 3. Conversion en Dalvik dex (d8 remplace dx dans les versions récentes)
if [ -f "$BUILD_TOOLS/d8" ]; then
    "$BUILD_TOOLS/d8" --min-api 23 --output build/ $(find build/classes -name '*.class')
elif [ -f "$BUILD_TOOLS/dx" ]; then
    "$BUILD_TOOLS/dx" --dex --output=build/classes.dex build/classes
else
    dalvik-exchange --dex --min-sdk-version=23 --output=build/classes.dex build/classes
fi

# 4. Packaging de l'APK non signé
"$BUILD_TOOLS/aapt" package -f -M AndroidManifest.xml -S res -A assets -I "$AJ" -F build/unsigned.apk
(cd build && "$BUILD_TOOLS/aapt" add unsigned.apk classes.dex >/dev/null && "$BUILD_TOOLS/zipalign" -f -p 4 unsigned.apk aligned.apk)

# 5. Création de la keystore si elle n'existe pas
[ -f belote.keystore ] || keytool -genkeypair -keystore belote.keystore -alias belote -keyalg RSA -keysize 2048 -validity 10000 -storepass belote2026 -keypass belote2026 -dname "CN=Belote du Soir, C=FR"

# 6. Signature et vérification
"$BUILD_TOOLS/apksigner" sign --ks belote.keystore --ks-pass pass:belote2026 --ks-key-alias belote --out build/BeloteDuSoir.apk build/aligned.apk
"$BUILD_TOOLS/apksigner" verify build/BeloteDuSoir.apk && echo "OK : build/BeloteDuSoir.apk"
