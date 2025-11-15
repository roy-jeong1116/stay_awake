# TFLite 핵심 라이브러리 클래스 유지 (GPU 위임 포함)
-keep class org.tensorflow.lite.** { *; }

# TFLite Support 라이브러리 클래스 유지 (권장)
-keep class org.tensorflow.lite.supprt.** { *; }

# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

