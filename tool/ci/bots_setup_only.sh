#!/bin/bash

# Copyright 2026 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Temporary bisect helper: runs only the shared CI setup (which includes
# `dt generate-code`, where the macOS `flutter pub get` hang occurs).
set -ex
source ./tool/ci/setup.sh
echo "SETUP_COMPLETED"
