#!/bin/bash

set -e

case "$1" in
xcode)
    swift package generate-xcodeproj $FLAGS
;;
*)
    swift build
    cp .build/debug/cte /usr/local/bin/
esac

echo "done"