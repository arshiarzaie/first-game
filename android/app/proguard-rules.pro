# SOUL: DUSK RUN 3D — R8 rules
#
# The only class in the app is the launcher Activity, referenced from the
# manifest, but keep it explicitly so resource shrinking can never orphan it.
-keep class com.ghoroub.soulduskrun.MainActivity { *; }

# WebView + asset streaming are reached reflectively by the framework.
-keepclassmembers class * {
    native <methods>;
}
