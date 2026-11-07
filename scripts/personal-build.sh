#!/bin/bash
# Local build only: never signs in, installs, or accesses a developer key.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="${1:-$repo_dir/../build}"
mkdir -p "$work_dir"
work_dir="$(cd "$work_dir" && pwd)"
for program in xcodebuild ldid ditto unzip shasum; do
    command -v "$program" >/dev/null || { echo "Missing build dependency: $program" >&2; exit 1; }
done

archive="$work_dir/SideStore-personal.xcarchive"
cd "$repo_dir"
xcodebuild archive -archivePath "$archive" \
    -derivedDataPath "$work_dir/SideStoreDerivedData" \
    -clonedSourcePackagesDirPath "$work_dir/SideStoreSourcePackages" \
    -project AltStore.xcodeproj -scheme SideStore -sdk iphoneos \
    -configuration Release -destination 'generic/platform=iOS' \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_REQUIRED=NO AD_HOC_CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM=XYZ0123456 ORG_IDENTIFIER=com.SideStore

stage="$(mktemp -d "$work_dir/ipa-stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload"
app="$stage/Payload/SideStore.app"
ditto "$archive/Products/Applications/SideStore.app" "$app"

# Same entitlement-preserving preparation as the official Makefile.
# A real development identity and profiles are still required to install it.
ldid -SAltStore/Resources/ReleaseEntitlements.plist "$app/SideStore"
ldid -SAltWidget/Resources/ReleaseEntitlements.plist "$app/PlugIns/AltWidgetExtension.appex/AltWidgetExtension"
mkdir -p "$stage/sidebackup"
unzip -q "$app/SideBackup.ipa" -d "$stage/sidebackup"
ldid -SSideBackup/SideBackup.entitlements "$stage/sidebackup/Payload/SideBackup.app/SideBackup"
rm "$app/SideBackup.ipa"
ditto -c -k --keepParent "$stage/sidebackup/Payload" "$app/SideBackup.ipa"
ditto -c -k --keepParent "$stage/Payload" "$stage/SideStore-personal.ipa"
mv "$stage/SideStore-personal.ipa" "$work_dir/SideStore-personal.ipa"
shasum -a 256 "$work_dir/SideStore-personal.ipa"
