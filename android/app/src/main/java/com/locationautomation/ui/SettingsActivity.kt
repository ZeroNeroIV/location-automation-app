package com.locationautomation.ui

import android.content.Context
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SwitchCompat
import com.locationautomation.R

class SettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)

        findViewById<View>(R.id.btnBack).setOnClickListener {
            onBackPressedDispatcher.onBackPressed()
        }

        findViewById<SwitchCompat>(R.id.switchNotifications).apply {
            isChecked = prefs.getBoolean("notifications_enabled", true)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("notifications_enabled", isChecked).apply()
            }
        }

        findViewById<SwitchCompat>(R.id.switchSound).apply {
            isChecked = prefs.getBoolean("sound_enabled", true)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("sound_enabled", isChecked).apply()
            }
        }

        findViewById<SwitchCompat>(R.id.switchDebug).apply {
            isChecked = prefs.getBoolean("debug_mode", false)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("debug_mode", isChecked).apply()
            }
        }
    }
}