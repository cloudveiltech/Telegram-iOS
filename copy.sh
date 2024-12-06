#!/bin/bash
rm -rf ./build/*
cp -rf "$1"/*.ipa ./build-ipa
cp -rf "$1"/*.dSYM ./build-ipa

