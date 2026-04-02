package com.locationautomation.ui

import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatDelegate
import com.google.android.material.materialswitch.MaterialSwitch
import com.locationautomation.R

class SettingsActivity : BaseActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)

        findViewById<View>(R.id.btnBack).setOnClickListener {
            onBackPressedDispatcher.onBackPressed()
        }

        findViewById<MaterialSwitch>(R.id.switchNotifications).apply {
            isChecked = prefs.getBoolean("notifications_enabled", true)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("notifications_enabled", isChecked).apply()
            }
        }

        findViewById<MaterialSwitch>(R.id.switchSound).apply {
            isChecked = prefs.getBoolean("sound_enabled", true)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("sound_enabled", isChecked).apply()
            }
        }

        findViewById<MaterialSwitch>(R.id.switchDarkMode).apply {
            isChecked = prefs.getBoolean("dark_mode", false)
            setOnCheckedChangeListener { _, isChecked ->
                prefs.edit().putBoolean("dark_mode", isChecked).apply()
                AppCompatDelegate.setDefaultNightMode(
                    if (isChecked) AppCompatDelegate.MODE_NIGHT_YES
                    else AppCompatDelegate.MODE_NIGHT_NO
                )
            }
        }

        findViewById<MaterialSwitch>(R.id.switchDebug).apply {
            isChecked = prefs.getBoolean("dev_mode", false)
            setOnCheckedChangeListener { _, isChecked ->
                if (isChecked) {
                    showPasswordDialog { correct ->
                        if (correct) {
                            prefs.edit().putBoolean("dev_mode", true).apply()
                        } else {
                            setChecked(false)
                        }
                    }
                } else {
                    prefs.edit().putBoolean("dev_mode", false).apply()
                }
            }
        }
    }

    private fun showPasswordDialog(onResult: (Boolean) -> Unit) {
        val input = EditText(this).apply {
            hint = "Enter password"
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        AlertDialog.Builder(this)
            .setTitle("Developer Mode")
            .setMessage("Enter password to enable")
            .setView(input)
            .setPositiveButton("OK") { _, _ ->
                if (input.text.toString() == "zeromama") {
                    onResult(true)
                } else {
                    Toast.makeText(this, "Incorrect password", Toast.LENGTH_SHORT).show()
                    onResult(false)
                }
            }
            .setNegativeButton("Cancel") { _, _ ->
                onResult(false)
            }
            .show()
    }
}