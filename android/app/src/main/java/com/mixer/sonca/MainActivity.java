package com.mixer.sonca;

import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.media.AudioAttributes;
import android.content.Context;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.mixer.sonca/haptic";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("vibrate")) {
                        triggerVibration();
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }

    private void triggerVibration() {
        android.util.Log.d("NativeHaptic", "triggerVibration called in Java!");
        try {
            Vibrator vibrator = null;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                VibratorManager vibratorManager = (VibratorManager) getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
                if (vibratorManager != null) {
                    vibrator = vibratorManager.getDefaultVibrator();
                }
            }
            if (vibrator == null) {
                vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            }

            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    AudioAttributes audioAttributes = new AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .build();
                    vibrator.vibrate(VibrationEffect.createOneShot(100, 255), audioAttributes);
                } else {
                    vibrator.vibrate(100);
                }
                android.util.Log.d("NativeHaptic", "Vibrator executed successfully!");
            } else {
                android.util.Log.d("NativeHaptic", "Vibrator is null or hasVibrator is false!");
            }
        } catch (Exception e) {
            android.util.Log.e("NativeHaptic", "Error in triggerVibration: " + e.getMessage());
        }
    }
}
