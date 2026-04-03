package com.locationautomation;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.location.LocationManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.widget.Button;
import android.widget.Toast;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.location.Geocoder;
import java.util.Locale;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.switchmaterial.SwitchMaterial;
import com.locationautomation.data.Zone;
import com.locationautomation.data.ZoneDatabase;
import com.locationautomation.location.LocationForegroundService;
import com.locationautomation.ui.SettingsActivity;
import com.locationautomation.ui.ZoneListActivity;
import com.locationautomation.ui.ZoneTimeGraphView;
import com.locationautomation.util.SoundManager;
import org.osmdroid.config.Configuration;
import org.osmdroid.tileprovider.tilesource.TileSourceFactory;
import org.osmdroid.util.GeoPoint;
import org.osmdroid.views.MapView;
import org.osmdroid.views.overlay.Marker;
import org.osmdroid.views.overlay.Polygon;

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
    private Button btnBackToNormal;
    private Button btnDefaultNormal;
    private Handler timerHandler;
    private Runnable timerRunnable;
    private ZoneDatabase database;
    private ZoneTimeGraphView zoneTimeGraph;
    private MaterialButton btnDayView;
    private MaterialButton btnWeekView;
    private boolean showWeekly = false;

    private MapView minimapView;
    private LocationManager minimapLocationManager;
    private GeoPoint minimapUserLocation;
    private Marker minimapUserMarker;
    private TextView locationText;
    private TextView addressText;
    private android.location.Location currentLocation;
    private final android.location.LocationListener minimapLocationListener = new android.location.LocationListener() {
        @Override
        public void onLocationChanged(android.location.Location location) {
            updateMinimapLocation(location);
        }
        @Override public void onProviderEnabled(String provider) {}
        @Override public void onProviderDisabled(String provider) {}
    };

    private final BroadcastReceiver stateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            updateTimerDisplay();
            updateDebugButtons();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        SharedPreferences appPrefs = getSharedPreferences("app_prefs", MODE_PRIVATE);
        boolean darkMode = appPrefs.getBoolean("dark_mode", false);
        AppCompatDelegate.setDefaultNightMode(
            darkMode ? AppCompatDelegate.MODE_NIGHT_YES : AppCompatDelegate.MODE_NIGHT_NO
        );
        
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        statePrefs = getSharedPreferences(STATE_PREFS, MODE_PRIVATE);
        database = new ZoneDatabase(this);
        timerHandler = new Handler(Looper.getMainLooper());

        // Request all necessary permissions on first launch
        if (!appPrefs.getBoolean("has_requested_permissions", false)) {
            requestAllPermissions();
            appPrefs.edit().putBoolean("has_requested_permissions", true).apply();
        } else {
            requestNotificationPermission();
        }
        setupViews();
        setupTimer();
        setupMinimap();

        // Restart service if automation was enabled but service isn't running
        boolean automationEnabled = prefs.getBoolean(KEY_AUTOMATION_ENABLED, false);
        if (automationEnabled) {
            LocationForegroundService.start(getApplicationContext());
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateAutomationSwitchState();
        updateTimerDisplay();
        updateDebugButtons();
        loadZoneTimeData();
        startMinimapLocationUpdates();

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
        stopMinimapLocationUpdates();
    }

    private void setupViews() {
        LinearLayout cardZones = findViewById(R.id.cardZones);
        LinearLayout cardSettings = findViewById(R.id.cardSettings);
        automationSwitch = findViewById(R.id.switchAutomation);
        automationStatus = findViewById(R.id.automationStatus);
        automationTimer = findViewById(R.id.automationTimer);
        debugTriggers = findViewById(R.id.debugTriggers);
        debugButtonsContainer = findViewById(R.id.debugButtonsContainer);
        btnBackToNormal = findViewById(R.id.btnBackToNormal);
        btnDefaultNormal = findViewById(R.id.btnDefaultNormal);
        zoneTimeGraph = findViewById(R.id.zoneTimeGraph);
        btnDayView = findViewById(R.id.btnDayView);
        btnWeekView = findViewById(R.id.btnWeekView);
        locationText = findViewById(R.id.locationText);
        addressText = findViewById(R.id.addressText);

        btnDayView.setOnClickListener(v -> {
            showWeekly = false;
            updateGraphButtons();
            loadZoneTimeData();
        });
        btnWeekView.setOnClickListener(v -> {
            showWeekly = true;
            updateGraphButtons();
            loadZoneTimeData();
        });

        updateGraphButtons();

        btnBackToNormal.setOnClickListener(v -> {
            disableAutomation();
            prefs.edit().putBoolean("dev_mode", false).apply();
            debugTriggers.setVisibility(LinearLayout.GONE);
        });

        btnDefaultNormal.setOnClickListener(v -> {
            LocationForegroundService.triggerNormalProfile(this);
            Toast.makeText(this, "Back to Normal", Toast.LENGTH_SHORT).show();
        });

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
        }

        boolean debugMode = getSharedPreferences("app_prefs", MODE_PRIVATE).getBoolean("dev_mode", false);
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
        SoundManager.INSTANCE.playSound(getApplicationContext(), R.raw.error_bleep_5);
        statePrefs.edit()
            .remove("current_zone")
            .remove("current_profile")
            .remove("zone_entry_time")
            .apply();
        automationTimer.setVisibility(TextView.GONE);
        debugTriggers.setVisibility(LinearLayout.GONE);
    }

    private void requestAllPermissions() {
        ActivityCompat.requestPermissions(this,
                new String[]{
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                        Manifest.permission.BLUETOOTH,
                        Manifest.permission.POST_NOTIFICATIONS
                },
                1001);
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                notificationPermissionLauncher.launch(new String[]{Manifest.permission.POST_NOTIFICATIONS});
            }
        }
    }

    private void updateGraphButtons() {
        if (showWeekly) {
            btnWeekView.setStrokeWidth(0);
            btnDayView.setStrokeWidth(1);
        } else {
            btnDayView.setStrokeWidth(0);
            btnWeekView.setStrokeWidth(1);
        }
    }

    private void loadZoneTimeData() {
        new Thread(() -> {
            var buckets = showWeekly ? database.getWeeklyZoneTime() : database.getDailyZoneTime();
            runOnUiThread(() -> {
                zoneTimeGraph.setData(buckets);
            });
        }).start();
    }

    private void setupMinimap() {
        Configuration.getInstance().load(
            getApplicationContext(),
            getApplicationContext().getSharedPreferences("osmdroid_minimap", MODE_PRIVATE)
        );
        Configuration.getInstance().setUserAgentValue(getPackageName());

        minimapView = findViewById(R.id.minimapView);
        minimapView.setTileSource(TileSourceFactory.MAPNIK);
        minimapView.setMultiTouchControls(false);
        minimapView.setClickable(false);
        minimapView.setEnabled(false);
        minimapView.setFocusable(false);
        minimapView.setBuiltInZoomControls(false);
        minimapView.getController().setZoom(16.0);
        minimapLocationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
    }

    private void startMinimapLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
            && ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        try {
            minimapLocationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER, 10000L, 100f, minimapLocationListener
            );
        } catch (Exception e) {
            android.util.Log.e("MainActivity", "Minimap location request failed", e);
        }
    }

    private void stopMinimapLocationUpdates() {
        try {
            minimapLocationManager.removeUpdates(minimapLocationListener);
        } catch (Exception e) {
            android.util.Log.e("MainActivity", "Minimap location removal failed", e);
        }
    }

    private void updateMinimapLocation(android.location.Location location) {
        currentLocation = location;
        double lat = location.getLatitude();
        double lng = location.getLongitude();
        
        runOnUiThread(() -> {
            minimapUserLocation = new GeoPoint(lat, lng);
            
            if (addressText != null) {
                addressText.setText(String.format(Locale.US, "%.5f, %.5f", lat, lng));
            }
            
            renderMinimap();
        });
        
        updateAddress(lat, lng);
    }
    
    private void updateAddress(double lat, double lng) {
        if (locationText == null) return;
        
        try {
            Geocoder geocoder = new Geocoder(this, Locale.getDefault());
            @SuppressWarnings("deprecation")
            List<android.location.Address> addresses = geocoder.getFromLocation(lat, lng, 1);
            if (addresses != null && !addresses.isEmpty()) {
                final String address = addresses.get(0).getAddressLine(0);
                runOnUiThread(() -> locationText.setText(address));
            } else {
                runOnUiThread(() -> locationText.setText(String.format(Locale.US, "%.4f, %.4f", lat, lng)));
            }
        } catch (Exception e) {
            runOnUiThread(() -> locationText.setText(String.format(Locale.US, "%.4f, %.4f", lat, lng)));
        }
    }

    private void renderMinimap() {
        minimapView.getOverlays().clear();

        if (minimapUserLocation != null) {
            minimapView.getController().setCenter(minimapUserLocation);

            minimapUserMarker = new Marker(minimapView);
            minimapUserMarker.setPosition(minimapUserLocation);
            minimapUserMarker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER);
            minimapUserMarker.setIcon(
                ContextCompat.getDrawable(this, android.R.drawable.ic_menu_mylocation)
            );
            minimapView.getOverlays().add(minimapUserMarker);
        }

        List<Zone> zones = database.getAllZones();
        for (Zone zone : zones) {
            GeoPoint center = new GeoPoint(zone.getLatitude(), zone.getLongitude());
            int fillColor = Color.argb(32, 13, 148, 136);
            int strokeColor = Color.parseColor("#0D9488");

            Polygon circle = new Polygon();
            circle.setPoints(calculateCirclePoints(zone.getLatitude(), zone.getLongitude(), zone.getRadius()));
            circle.getFillPaint().setColor(fillColor);
            circle.getOutlinePaint().setColor(strokeColor);
            circle.getOutlinePaint().setStrokeWidth(2f);
            minimapView.getOverlays().add(circle);
        }

        minimapView.invalidate();
    }

    private java.util.List<GeoPoint> calculateCirclePoints(double centerLat, double centerLng, double radiusMeters) {
        java.util.List<GeoPoint> points = new java.util.ArrayList<>();
        int numPoints = 36;
        for (int i = 0; i < numPoints; i++) {
            double angle = Math.toRadians(i * 360.0 / numPoints);
            double lat = centerLat + (radiusMeters / 111320.0) * Math.cos(angle);
            double lng = centerLng + (radiusMeters / (111320.0 * Math.cos(Math.toRadians(centerLat)))) * Math.sin(angle);
            points.add(new GeoPoint(lat, lng));
        }
        return points;
    }
}
