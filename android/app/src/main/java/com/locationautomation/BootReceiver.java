package com.locationautomation;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import com.locationautomation.location.LocationForegroundService;

public class BootReceiver extends BroadcastReceiver {
    private static final String PREFS_NAME = "location_automation_prefs";
    private static final String KEY_AUTOMATION_ENABLED = "automation_enabled";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            boolean automationEnabled = prefs.getBoolean(KEY_AUTOMATION_ENABLED, false);
            if (automationEnabled) {
                LocationForegroundService.start(context);
            }
        }
    }
}
