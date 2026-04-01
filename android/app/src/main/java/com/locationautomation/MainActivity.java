package com.locationautomation;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import com.google.android.material.card.MaterialCardView;
import com.locationautomation.ui.ZoneListActivity;
import com.locationautomation.ui.SettingsActivity;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        MaterialCardView cardZones = findViewById(R.id.cardZones);
        MaterialCardView cardSettings = findViewById(R.id.cardSettings);

        cardZones.setOnClickListener(v -> {
            startActivity(new Intent(this, ZoneListActivity.class));
        });

        cardSettings.setOnClickListener(v -> {
            startActivity(new Intent(this, SettingsActivity.class));
        });
    }
}