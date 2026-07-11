#!/usr/bin/env python3
"""Patch flutter_inappwebview_android build.gradle to use proguard-android-optimize.txt."""

import sys

if __name__ == '__main__':
    path = sys.argv[1]
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(
        "getDefaultProguardFile('proguard-android.txt')",
        "getDefaultProguardFile('proguard-android-optimize.txt')",
    )
    with open(path, 'w') as f:
        f.write(content)
    print(f"Patched {path}")
