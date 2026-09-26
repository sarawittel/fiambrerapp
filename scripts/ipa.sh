#!/bin/sh
# Genera build/Fiambrera.ipa sin firmar (Release), para instalarlo con iloader, que lo firma con tu Apple ID.
set -e
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project GK2Guia.xcodeproj -scheme GK2Guia -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet build
rm -rf build/ipa build/Fiambrera.ipa
mkdir -p build/ipa/Payload
cp -R build/Build/Products/Release-iphoneos/GK2Guia.app build/ipa/Payload/
(cd build/ipa && zip -qry ../Fiambrera.ipa Payload)
rm -rf build/ipa
echo "IPA listo: $(pwd)/build/Fiambrera.ipa"
