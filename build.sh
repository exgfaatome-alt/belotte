#!/bin/bash
# Construit BeloteDuSoir.apk sur GitHub Actions / Linux
set -euo pipefail
cd "$(dirname "$0")"

# Recherche automatique de android.jar sur les runners Ubuntu
if [ -d "/usr/lib/android-sdk" ]; then
    AJ=$(find /usr/lib/android-sdk -name "android.jar" | head -n 1)
elif [ -n "${ANDROID_HOME:-}" ]; then
    AJ=$(find "$ANDROID_HOME" -name "android.jar" | head -n 1)
else
    AJ=${ANDROID_JAR:-/usr/lib/android-sdk/platforms/android-23/android.jar}
fi

echo "Utilisation de android.jar : $AJ"

rm -rf build; mkdir -p build/gen build/classes

# 1. Compilation des ressources avec aapt
aapt package -f -m -J build/gen -M AndroidManifest.xml -S res -I "$AJ"

# 2. Compilation Java
javac -nowarn -Xlint:-options -source 8 -target 8 -bootclasspath "$AJ" -d build/classes $(find src build/gen -name '*.java')

# 3. Conversion en Dalvik dex (Note : sur Ubuntu, l'outil s'appelle souvent 'dx' ou 'd8', 'dalvik-exchange' n'existe pas par défaut)
if command -v dx &> /dev/null; then
    dx --dex --output=build/classes.dex build/classes
elif command -v dalvik-exchange &> /dev/null; then
    dalvik-exchange --dex --min-sdk-version=23 --output=build/classes.dex build/classes
else
    # Fallback si dx est dans le SDK Android
    ${ANDROID_HOME:-}/build-tools/*/dx --dex --output=build/classes.dex build/classes
fi

# 4. Packaging de l'APK non signé
aapt package -f -M AndroidManifest.xml -S res -A assets -I "$AJ" -F build/unsigned.apk
(cd build && aapt add unsigned.apk classes.dex >/dev/null && zipalign -f -p 4 unsigned.apk aligned.apk)

# 5. Création de la keystore si elle n'existe pas
[ -f belote.keystore ] || keytool -genkeypair -keystore belote.keystore -alias belote -keyalg RSA -keysize 2048 -validity 10000 -storepass belote2026 -keypass belote2026 -dname "CN=Belote du Soir, C=FR"

# 6. Signature et vérification
apksigner sign --ks belote.keystore --ks-pass pass:belote2026 --ks-key-alias belote --out build/BeloteDuSoir.apk build/aligned.apk
apksigner verify build/BeloteDuSoir.apk && echo "OK : build/BeloteDuSoir.apk"
