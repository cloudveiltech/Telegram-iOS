#!/bin/bash
rm -rf ./build/*
cp -rf "$1"/*.ipa ./build-app
cp -rf "$1"/*.dSYM ./build-app
