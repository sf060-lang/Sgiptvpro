#!/usr/bin/env bash
# Android ve Windows platform klasorlerini uretir ve gerekli ayarlari yapar.
# Kullanim (proje klasorunde):  bash tool/setup_platforms.sh
set -euo pipefail

flutter create --project-name iptv_pro --org com.iptvpro --platforms=android,windows .
rm -rf test   # sablon test dosyasi bu uygulamaya uymuyor

M=android/app/src/main/AndroidManifest.xml

# Internet izni + http (sifrelenmemis) yayinlara izin + uygulama adi
if ! grep -q 'android.permission.INTERNET' "$M"; then
  sed -i 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <application android:usesCleartextTraffic="true"|' "$M"
fi
sed -i 's|android:label="[^"]*"|android:label="IPTV Pro"|' "$M"

echo "Platform ayarlari tamam."
