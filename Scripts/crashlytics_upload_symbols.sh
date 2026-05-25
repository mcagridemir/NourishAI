#!/bin/bash
# Xcode Build Phase script — paste this verbatim into:
# Target: Sana → Build Phases → + New Run Script Phase
# Name: "Upload dSYMs to Crashlytics"
# Uncheck "Based on dependency analysis" so it runs every build.
#
# Place AFTER "Compile Sources" and AFTER "Link Binary with Libraries".

"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
