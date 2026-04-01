package com.locationautomation;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import com.google.android.material.switchmaterial.SwitchMaterial;
import com.locationautomation.data.Zone;
import com.locationautomation.data.ZoneDatabase;
import com.locationautomation.location.LocationForegroundService;
import com.locationautomation.ui.SettingsActivity;
import com.locationautomation.ui.ZoneListActivity;
import com.locationautomation.util.SoundManager;

import java.util.List;

public class MainActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "location_automation_prefs";
    private static final String KEY_AUTOMATION_ENABLED = "automation_enabled";
    private static final String STATE_PREFS = "automation_state";

    private final ActivityResultLauncher<String[]> notificationPermissionLauncher = registerForActivityResult(
        new ActivityResultContracts.RequestMultiplePermissions(),
        result -> {
            Boolean notificationsGranted = result.get(Manifest.permission.POST_NOTIFICATIONS);
            if (notificationsGranted != null && notificationsGranted) {
                android.util.Log.d("MainActivity", "Notification permission granted");
            }
        }
    );

    private final ActivityResultLauncher<Intent> dndPermissionLauncher = registerForActivityResult(
        new ActivityResultContracts.StartActivityForResult(),
        result -> {
            updateAutomationSwitchState();
        }
    );

    private SharedPreferences prefs;
    private SharedPreferences statePrefs;
    private SwitchMaterial automationSwitch;
    private TextView automationStatus;
    private TextView automationTimer;
    private LinearLayout debugTriggers;
    private LinearLayout debugButtonsContainer;
    private Handler timerHandler;
    private Runnable timerRunnable;
    private ZoneDatabase database;

    private final BroadcastReceiver stateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            updateTimerDisplay();
            updateDebugButtons();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        statePrefs = getSharedPreferences(STATE_PREFS, MODE_PRIVATE);
        database = new ZoneDatabase(this);
        timerHandler = new Handler(Looper.getMainLooper());

        requestNotificationPermission();
        setupViews();
        setupTimer();
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateAutomationSwitchState();
        updateTimerDisplay();
        updateDebugButtons();

        IntentFilter filter = new IntentFilter(LocationForegroundService.BROADCAST_STATE_CHANGED);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stateReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(stateReceiver, filter);
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        try {
            unregisterReceiver(stateReceiver);
        } catch (IllegalArgumentException e) {
        }
    }

    private void setupViews() {
        LinearLayout cardZones = findViewById(R.id.cardZones);
        LinearLayout cardSettings = findViewById(R.id.cardSettings);
        automationSwitch = findViewById(R.id.switchAutomation);
        automationStatus = findViewById(R.id.automationStatus);
        automationTimer = findViewById(R.id.automationTimer);
        debugTriggers = findViewById(R.id.debugTriggers);
        debugButtonsContainer = findViewById(R.id.debugButtonsContainer);

        cardZones.setOnClickListener(v -> {
            startActivity(new Intent(this, ZoneListActivity.class));
        });

        cardSettings.setOnClickListener(v -> {
            startActivity(new Intent(this, SettingsActivity.class));
        });

        automationSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                if (checkDndPermission()) {
                    enableAutomation();
                } else {
                    requestDndPermission();
                    automationSwitch.setChecked(false);
                }
            } else {
                disableAutomation();
            }
        });
    }

    private void setupTimer() {
        timerRunnable = new Runnable() {
            @Override
            public void run() {
                updateTimerDisplay();
                timerHandler.postDelayed(this, 1000);
            }
        };
        timerHandler.post(timerRunnable);
    }

    private void updateAutomationSwitchState() {
        boolean isEnabled = prefs.getBoolean(KEY_AUTOMATION_ENABLED, false);
        automationSwitch.setChecked(isEnabled);
        if (isEnabled) {
            automationStatus.setText(R.string.automation_on);
        } else {
        automationStatus.setText(R.string.automation_off);
        SoundManager.INSTANCE.playSound(getApplicationContext(), R.raw.error_bleep_5);
        }

        boolean debugMode = getSharedPreferences("app_prefs", MODE_PRIVATE).getBoolean("debug_mode", false);
        debugTriggers.setVisibility(debugMode && isEnabled ? LinearLayout.VISIBLE : LinearLayout.GONE);
        if (debugMode && isEnabled) {
            updateDebugButtons();
        }
    }

    private void updateTimerDisplay() {
        long entryTime = statePrefs.getLong("zone_entry_time", 0);
        String zoneName = statePrefs.getString("current_zone", "");

        if (entryTime > 0 && !zoneName.isEmpty()) {
            long elapsed = System.currentTimeMillis() - entryTime;
            automationTimer.setVisibility(TextView.VISIBLE);
            automationTimer.setText(formatDuration(elapsed) + " in " + zoneName);
        } else {
            automationTimer.setVisibility(TextView.GONE);
        }
    }

    private void updateDebugButtons() {
        if (!prefs.getBoolean(KEY_AUTOMATION_ENABLED, false)) return;

        List<Zone> zones = database.getAllZones();
        debugButtonsContainer.removeAllViews();

        for (int i = 0; i < zones.size(); i++) {
            final Zone zone = zones.get(i);
            final int index = i;
            Button btn = new Button(this);
            btn.setText(zone.getName());
            btn.setTextSize(12);
            btn.setPadding(24, 12, 24, 12);
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            );
            params.setMargins(0, 0, 8, 0);
            btn.setLayoutParams(params);
            btn.setOnClickListener(v -> {
                LocationForegroundService.debugTrigger(getApplicationContext(), index);
            });
            debugButtonsContainer.addView(btn);
        }
    }

    private String formatDuration(long millis) {
        long seconds = millis / 1000;
        long minutes = seconds / 60;
        long hours = minutes / 60;
        seconds %= 60;
        minutes %= 60;

        if (hours > 0) {
            return String.format("%02d:%02d:%02d", hours, minutes, seconds);
        }
        return String.format("%02d:%02d", minutes, seconds);
    }

    private boolean checkDndPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.app.NotificationManager notificationManager =
                (android.app.NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            return notificationManager.isNotificationPolicyAccessGranted();
        }
        return true;
    }

    private void requestDndPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS);
            dndPermissionLauncher.launch(intent);
        }
    }

    private void enableAutomation() {
        prefs.edit().putBoolean(KEY_AUTOMATION_ENABLED, true).apply();
        LocationForegroundService.start(getApplicationContext());
        automationStatus.setText(R.string.automation_on);
        updateAutomationSwitchState();
    }

    private void disableAutomation() {
        prefs.edit().putBoolean(KEY_AUTOMATION_ENABLED, false).apply();
        LocationForegroundService.stop(getApplicationContext());
        automationStatus.setText(R.string.automation_off);
        automationTimer.setVisibility(TextView.GONE);
        debugTriggers.setVisibility(LinearLayout.GONE);
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
