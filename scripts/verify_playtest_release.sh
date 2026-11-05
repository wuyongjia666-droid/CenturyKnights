#!/usr/bin/env bash
# Verify GitHub Release for a short tip has BOTH Android APK + Windows zip + SHA256.
# Usage: bash scripts/verify_playtest_release.sh [shortsha=35024036]
set -euo pipefail
SHORT="${1:-35024036}"
REPO="${GH_REPO:-wuyongjia666-droid/CenturyKnights}"
TAG="main-${SHORT}"
echo "verify release ${TAG} on ${REPO}"
json="$(gh release view "${TAG}" -R "${REPO}" --json tagName,targetCommitish,assets,url)"
echo "$json" | jq '{tag:.tagName,target:.targetCommitish,url,assets:[.assets[].name]}'
apk="CenturyKnights-android-${SHORT}.apk"
zip="CenturyKnights-windows-${SHORT}.zip"
sha="SHA256-${SHORT}.txt"
names="$(echo "$json" | jq -r '.assets[].name')"
echo "$names" | grep -qx "$apk" || { echo "MISSING $apk"; exit 1; }
echo "$names" | grep -qx "$zip" || { echo "MISSING $zip"; exit 1; }
echo "$names" | grep -qx "$sha" || { echo "MISSING $sha"; exit 1; }
echo "PLAYTEST RELEASE DUAL ASSETS OK tip=${SHORT}"
