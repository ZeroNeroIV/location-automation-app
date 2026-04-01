package com.locationautomation;

import android.content.Intent;
import android.os.Bundle;
import android.widget.LinearLayout;
import androidx.appcompat.app.AppCompatActivity;
import com.locationautomation.ui.ZoneListActivity;
import com.locationautomation.ui.SettingsActivity;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        LinearLayout cardZones = findViewById(R.id.cardZones);
        LinearLayout cardSettings = findViewById(R.id.cardSettings);

        cardZones.setOnClickListener(v -> {
            startActivity(new Intent(this, ZoneListActivity.class));
        });

        cardSettings.setOnClickListener(v -> {
            startActivity(new Intent(this, SettingsActivity.class));
        });
    }
}