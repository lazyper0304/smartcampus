# ML Kit Text Recognition - optional language packs not bundled
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
# Prevent R8 from failing on missing optional dependencies
-ignorewarnings

# yibinu-connect gomobile AAR：go.Seq 通过 JNI 按名回调，禁止混淆
-keep class go.** { *; }
-keep class mobile.** { *; }
-dontwarn go.**
-dontwarn mobile.**
