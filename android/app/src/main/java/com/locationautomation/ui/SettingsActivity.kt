package com.locationautomation.ui

import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.Toast
import androidx.appcompat.app.AppCompatDelegate
import androidx.appcompat.widget.SwitchCompat
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.button.MaterialButton
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.textfield.TextInputEditText
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

        findViewById<View>(R.id.settingDefaultState).setOnClickListener {
            showDefaultStateDialog()
        }
    }

    private fun showPasswordDialog(onResult: (Boolean) -> Unit) {
        val bottomSheet = BottomSheetDialog(this)
        val sheetView = layoutInflater.inflate(R.layout.bottom_sheet_password, null)
        bottomSheet.setContentView(sheetView)
        bottomSheet.setCanceledOnTouchOutside(true)

        val input = sheetView.findViewById<TextInputEditText>(R.id.passwordInput)
        val btnUnlock = sheetView.findViewById<MaterialButton>(R.id.btnUnlock)

        btnUnlock.setOnClickListener {
            if (input.text.toString() == "zeromama") {
                onResult(true)
                bottomSheet.dismiss()
            } else {
                Toast.makeText(this, "Incorrect password", Toast.LENGTH_SHORT).show()
                input.text?.clear()
            }
        }

        bottomSheet.show()
    }

    private fun showDefaultStateDialog() {
        val bottomSheet = BottomSheetDialog(this)
        val sheetView = layoutInflater.inflate(R.layout.bottom_sheet_default_state, null)
        bottomSheet.setContentView(sheetView)
        bottomSheet.setCanceledOnTouchOutside(true)

        val prefs = getSharedPreferences("default_phone_state", Context.MODE_PRIVATE)

        val ringtone = prefs.getBoolean("default_ringtone", true)
        val vibrate = prefs.getBoolean("default_vibrate", true)
        val dnd = prefs.getBoolean("default_dnd", false)
        val alarms = prefs.getBoolean("default_alarms", true)
        val timers = prefs.getBoolean("default_timers", true)
        val wifi = prefs.getBoolean("default_wifi", true)
        val bluetooth = prefs.getBoolean("default_bluetooth", true)
        val mobileData = prefs.getBoolean("default_mobile_data", true)

        val switchRingtone = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultRingtone)
        val switchVibrate = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultVibrate)
        val switchDnd = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultDnd)
        val switchAlarms = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultAlarms)
        val switchTimers = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultTimers)
        val switchWifi = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultWifi)
        val switchBluetooth = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultBluetooth)
        val switchMobileData = sheetView.findViewById<SwitchCompat>(R.id.switchDefaultMobileData)

        switchRingtone.isChecked = ringtone
        switchVibrate.isChecked = vibrate
        switchDnd.isChecked = dnd
        switchAlarms.isChecked = alarms
        switchTimers.isChecked = timers
        switchWifi.isChecked = wifi
        switchBluetooth.isChecked = bluetooth
        switchMobileData.isChecked = mobileData

        sheetView.findViewById<LinearLayout>(R.id.defaultRingtone).setOnClickListener {
            switchRingtone.isChecked = !switchRingtone.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultVibrate).setOnClickListener {
            switchVibrate.isChecked = !switchVibrate.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultDnd).setOnClickListener {
            switchDnd.isChecked = !switchDnd.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultAlarms).setOnClickListener {
            switchAlarms.isChecked = !switchAlarms.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultTimers).setOnClickListener {
            switchTimers.isChecked = !switchTimers.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultWifi).setOnClickListener {
            switchWifi.isChecked = !switchWifi.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultBluetooth).setOnClickListener {
            switchBluetooth.isChecked = !switchBluetooth.isChecked
        }
        sheetView.findViewById<LinearLayout>(R.id.defaultMobileData).setOnClickListener {
            switchMobileData.isChecked = !switchMobileData.isChecked
        }

        sheetView.findViewById<MaterialButton>(R.id.btnSaveDefault).setOnClickListener {
            prefs.edit()
                .putBoolean("default_ringtone", switchRingtone.isChecked)
                .putBoolean("default_vibrate", switchVibrate.isChecked)
                .putBoolean("default_dnd", switchDnd.isChecked)
                .putBoolean("default_alarms", switchAlarms.isChecked)
                .putBoolean("default_timers", switchTimers.isChecked)
                .putBoolean("default_wifi", switchWifi.isChecked)
                .putBoolean("default_bluetooth", switchBluetooth.isChecked)
                .putBoolean("default_mobile_data", switchMobileData.isChecked)
                .apply()
            Toast.makeText(this, "Default state saved", Toast.LENGTH_SHORT).show()
            bottomSheet.dismiss()
        }

        bottomSheet.show()
    }
}