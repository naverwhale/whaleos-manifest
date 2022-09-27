#!/bin/bash

# Copyright (c) 2021 NAVER Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -e

if [[ -z "$BOARD" ]]; then
  echo "BOARD should be defined"
  exit -1
fi

echo_help() {
  echo "Usage: path/to/manifest> ./build_whaleos.sh [args...]"
  echo "* Optional parameters:"
  echo "  @No parameter: Build packages only"
  echo "  @Available param 1: base, dev, test, jenkins"
  echo "      base: Build base image after building packages"
  echo "      dev: Build dev image after building packages"
  echo "      test: Build test image after building packages"
  exit 0
}
if [[ $1 == "-h" ]]; then
  echo_help
fi
if [[ ! -z $1 && ! $1 =~ ^(base|dev|test)$ ]]; then
  echo_help
fi

if [[ ${CHROME_REV} == "" ]]; then
  CHROME_REV="R96"
fi

WHALEOS_ROOT_PATH="$PWD/.."
UPDATE_SERVER=""
DEV_SERVER=""

WHALEOS_VERSION=$(head -n 1 VERSION)
IMAGE_DIR_PREFIX=${CHROME_REV}-${WHALEOS_VERSION}

# MUST add package as full name.
WORKON_PACKAGES=(
  'chromeos-base/chrome-icu'
  'chromeos-base/chromeos-chrome'
  'chromeos-base/chromeos-init'
  'chromeos-base/chromeos-installer'
  'chromeos-base/chromeos-login'
  'chromeos-base/chromiumos-assets'
  'chromeos-base/common-assets'
  'chromeos-base/crash-reporter'
  'chromeos-base/cryptohome'
  'chromeos-base/factory'
  'chromeos-base/factory_installer'
  'chromeos-base/gestures-conf'
  'chromeos-base/libbrillo'
  'chromeos-base/power_manager'
  'chromeos-base/system_api'
  'chromeos-base/tpm_manager'
  'chromeos-base/tpm_manager-client'
  'chromeos-base/vpd'
  'media-libs/cros-camera-hal-usb'
  'media-sound/adhd'
  'net-misc/tlsdate'
  'net-wireless/bluez'
  'sys-apps/flashrom'
  'sys-apps/frecon'
  'virtual/target-chromium-os'
  'sys-kernel/chromeos-kernel-5_10'
)

echo "** Setup for image building **"
cd $WHALEOS_ROOT_PATH
cros_sdk -- setup_board --board=${BOARD}

PACKAGES_WORKON_STARTED=$(cros_sdk -- cros_workon --board=${BOARD} list)
TO_STOP=($(comm -13 <(printf '%s\n' "${WORKON_PACKAGES[@]}" | LC_ALL=C sort) \
    <(printf '%s\n' "${PACKAGES_WORKON_STARTED[@]}" | LC_ALL=C sort)))
TO_START=($(comm -23 <(printf '%s\n' "${WORKON_PACKAGES[@]}" | LC_ALL=C sort) \
    <(printf '%s\n' "${PACKAGES_WORKON_STARTED[@]}" | LC_ALL=C sort)))
if [[ ${#TO_STOP[@]} -gt 0 ]]; then
  cros_sdk -- cros_workon --board=${BOARD} stop ${TO_STOP[@]}
fi
if [[ ${#TO_START[@]} -gt 0 ]]; then
  cros_sdk -- cros_workon --board=${BOARD} start ${TO_START[@]}
fi

echo "** Build packages **"
cros_sdk -- ./build_packages --board=${BOARD}
cros_sdk -- emerge-${BOARD} ${WORKON_PACKAGES[@]}

if [[ -z "$1" ]]; then
  echo "Build packages only done."
  exit 0
fi

if [[ $1 =~ ^(base|dev|test)$ ]]; then
  echo "** Make $1 image **"
  if [[ $1 == "test" ]]; then
    EXTRA_COMMANDS="--noenable_rootfs_verification"
  fi
  cros_sdk FLAGS_version=${WHALEOS_VERSION} \
      CHROMEOS_VERSION_DEVSERVER=${DEV_SERVER} \
      CHROMEOS_VERSION_AUSERVER=${UPDATE_SERVER} \
      -- ./build_image --board=${BOARD} ${EXTRA_COMMANDS} \
      $1 --replace
  exit 0
fi

