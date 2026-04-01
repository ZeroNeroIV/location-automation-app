package com.locationautomation;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.widget.LinearLayout;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import com.locationautomation.ui.ZoneListActivity;
import com.locationautomation.ui.SettingsActivity;

public class MainActivity extends AppCompatActivity {

    private final ActivityResultLauncher<String[]> notificationPermissionLauncher = registerForActivityResult(
        new ActivityResultContracts.RequestMultiplePermissions(),
        result -> {
            Boolean notificationsGranted = result.get(Manifest.permission.POST_NOTIFICATIONS);
            if (notificationsGranted != null && notificationsGranted) {
                android.util.Log.d("MainActivity", "Notification permission granted");
            }
        }
    );

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        requestNotificationPermission();

        LinearLayout cardZones = findViewById(R.id.cardZones);
        LinearLayout cardSettings = findViewById(R.id.cardSettings);

        cardZones.setOnClickListener(v -> {
            startActivity(new Intent(this, ZoneListActivity.class));
        });

        cardSettings.setOnClickListener(v -> {
            startActivity(new Intent(this, SettingsActivity.class));
        });
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) 
                    != PackageManager.PERMISSION_GRANTED) {
                notificationPermissionLauncher.launch(new String[]{Manifest.permission.POST_NOTIFICATIONS});
            }
        }
    }
}