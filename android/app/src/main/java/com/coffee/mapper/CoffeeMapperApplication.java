package com.coffee.mapper;

import android.app.Application;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;

public class CoffeeMapperApplication extends Application {
    private FlutterEngine flutterEngine;

    @Override
    public void onCreate() {
        super.onCreate();
        // Create a FlutterEngine instance
        flutterEngine = new FlutterEngine(this);

        // Start executing Dart code in the FlutterEngine
        flutterEngine.getDartExecutor().executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        );
    }

    public FlutterEngine getFlutterEngine() {
        return flutterEngine;
    }
} 