package com.doraty.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15/SDK 35+
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
