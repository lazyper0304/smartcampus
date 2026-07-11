"""Patch flutter_inappwebview_android's deprecated proguard reference."""
import sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace(
    "getDefaultProguardFile('proguard-android.txt')",
    "getDefaultProguardFile('proguard-android-optimize.txt')",
)
content = content.replace(
    'getDefaultProguardFile("proguard-android.txt")',
    'getDefaultProguardFile("proguard-android-optimize.txt")',
)

with open(filepath, 'w') as f:
    f.write(content)
print(f'Patched proguard reference in {filepath}')
