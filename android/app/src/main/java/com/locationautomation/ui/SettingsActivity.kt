package com.locationautomation.ui

import android.content.Context
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SwitchCompat

class SettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }
        
        val title = TextView(this).apply {
            text = "Settings"
            textSize = 24f
        }
        layout.addView(title)
        
        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
        
        val notificationsLabel = TextView(this).apply {
            text = "Notifications"
            textSize = 16f
        }
        layout.addView(notificationsLabel)
        
        val notificationsSwitch = SwitchCompat(this).apply {
            isChecked = prefs.getBoolean("notifications_enabled", true)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("notifications_enabled", isChecked).apply()
            }
        }
        layout.addView(notificationsSwitch)
        
        val soundLabel = TextView(this).apply {
            text = "Sound"
            textSize = 16f
            setPadding(0, 24, 0, 0)
        }
        layout.addView(soundLabel)
        
        val soundSwitch = SwitchCompat(this).apply {
            isChecked = prefs.getBoolean("sound_enabled", true)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("sound_enabled", isChecked).apply()
            }
        }
        layout.addView(soundSwitch)
        
        val versionLabel = TextView(this).apply {
            text = "Version: 1.0.0"
            textSize = 14f
            setTextColor(android.graphics.Color.GRAY)
            setPadding(0, 48, 0, 0)
        }
        layout.addView(versionLabel)
        
        setContentView(layout)
    }
}