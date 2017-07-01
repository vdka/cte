#!/bin/bash

set -e

case "$1" in
xcode)
    swift package generate-xcodeproj 
;;

sourcery)
    ./tools/genAccessors.sh
;;

*)
    swift build -Xswiftc -DDEBUG
    cp .build/debug/cte /usr/local/bin/
esac

echo "done"
