package com.coffee.mapper;

import android.content.Context;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    @Override
    public FlutterEngine provideFlutterEngine(@NonNull Context context) {
        return ((CoffeeMapperApplication) getApplication()).getFlutterEngine();
    }
} 