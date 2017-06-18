#!/bin/bash

if !(which sourcery); then
    echo 'sourcery not found'
    exit 1
fi

sourcery --sources Sources/ --templates tools/ --output Sources/cte/generated/Accessors.swift

