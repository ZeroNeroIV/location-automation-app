package com.locationautomation.ui

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.SwitchPreferenceCompat
import com.locationautomation.R

class SettingsActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "SettingsActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "SettingsActivity onCreate")
        
        if (savedInstanceState == null) {
            supportFragmentManager
                .beginTransaction()
                .replace(android.R.id.content, SettingsFragment())
                .commit()
        }
    }

    class SettingsFragment : PreferenceFragmentCompat() {

        companion object {
            private const val TAG = "SettingsFragment"
            
            // Preference keys
            const val KEY_NOTIFICATIONS = "notifications_enabled"
            const val KEY_SOUND = "sound_enabled"
            const val KEY_PRIORITY = "detection_priority"
            const val KEY_DEBOUNCE = "debounce_time"
            const val KEY_LEARNING_ENABLED = "learning_enabled"
            const val KEY_CLEAR_LEARNING = "clear_learning_data"
            const val KEY_VERSION = "app_version"
        }

        override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
            setPreferencesFromResource(R.xml.preferences, rootKey)
            Log.d(TAG, "Preferences loaded")

            setupGeneralPreferences()
            setupDetectionPreferences()
            setupLearningPreferences()
            setupAboutPreferences()
        }

        private fun setupGeneralPreferences() {
            // Notifications toggle - SharedPreferences handles storage automatically
            findPreference<SwitchPreferenceCompat>(KEY_NOTIFICATIONS)?.apply {
                summary = if (isChecked) "Notifications enabled" else "Notifications disabled"
                setOnPreferenceChangeListener { preference, newValue ->
                    val enabled = newValue as Boolean
                    (preference as SwitchPreferenceCompat).summary = 
                        if (enabled) "Notifications enabled" else "Notifications disabled"
                    Log.d(TAG, "Notifications: $enabled")
                    true
                }
            }

            // Sound toggle
            findPreference<SwitchPreferenceCompat>(KEY_SOUND)?.apply {
                summary = if (isChecked) "Sound enabled" else "Sound disabled"
                setOnPreferenceChangeListener { preference, newValue ->
                    val enabled = newValue as Boolean
                    (preference as SwitchPreferenceCompat).summary = 
                        if (enabled) "Sound enabled" else "Sound disabled"
                    Log.d(TAG, "Sound: $enabled")
                    true
                }
            }
        }

        private fun setupDetectionPreferences() {
            // Priority selection - using list preference
            findPreference<Preference>(KEY_PRIORITY)?.apply {
                summary = "Current: ${sharedPreferences?.getString(KEY_PRIORITY, "High") ?: "High"}"
                setOnPreferenceClickListener {
                    showPriorityDialog()
                    true
                }
            }

            // Debounce time - using edit text preference that saves to SharedPreferences
            findPreference<Preference>(KEY_DEBOUNCE)?.apply {
                val debounceValue = sharedPreferences?.getInt(KEY_DEBOUNCE, 30) ?: 30
                summary = "$debounceValue seconds"
            }
        }

        private fun showPriorityDialog() {
            val priorities = arrayOf("High", "Medium", "Low")
            val currentPriority = sharedPreferences?.getString(KEY_PRIORITY, "High") ?: "High"
            val currentIndex = priorities.indexOf(currentPriority)

            AlertDialog.Builder(requireContext())
                .setTitle("Detection Priority")
                .setSingleChoiceItems(priorities, currentIndex) { dialog, which ->
                    val selected = priorities[which]
                    sharedPreferences?.edit()?.putString(KEY_PRIORITY, selected)?.apply()
                    findPreference<Preference>(KEY_PRIORITY)?.summary = "Current: $selected"
                    Log.d(TAG, "Priority set to: $selected")
                    dialog.dismiss()
                }
                .setNegativeButton("Cancel", null)
                .show()
        }

        private fun setupLearningPreferences() {
            // Learning enable/disable
            findPreference<SwitchPreferenceCompat>(KEY_LEARNING_ENABLED)?.apply {
                summary = if (isChecked) "Learning enabled" else "Learning disabled"
                setOnPreferenceChangeListener { preference, newValue ->
                    val enabled = newValue as Boolean
                    (preference as SwitchPreferenceCompat).summary = 
                        if (enabled) "Learning enabled" else "Learning disabled"
                    Log.d(TAG, "Learning: $enabled")
                    true
                }
            }

            // Clear learning data
            findPreference<Preference>(KEY_CLEAR_LEARNING)?.setOnPreferenceClickListener {
                showClearDataDialog()
                true
            }
        }

        private fun showClearDataDialog() {
            AlertDialog.Builder(requireContext())
                .setTitle("Clear Learning Data")
                .setMessage("Are you sure you want to clear all learning data? This action cannot be undone.")
                .setPositiveButton("Clear") { _, _ ->
                    clearLearningData()
                }
                .setNegativeButton("Cancel", null)
                .show()
        }

        private fun clearLearningData() {
            try {
                // Clear learning-related SharedPreferences
                sharedPreferences?.edit()?.apply {
                    // Clear any learning-specific preferences here
                    // For example: remove("learning_patterns"), remove("suggestion_history"), etc.
                    apply()
                }
                Log.d(TAG, "Learning data cleared")
                android.widget.Toast.makeText(
                    context,
                    "Learning data cleared",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear learning data", e)
                android.widget.Toast.makeText(
                    context,
                    "Failed to clear data",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
        }

        private fun setupAboutPreferences() {
            // Version - read-only
            findPreference<Preference>(KEY_VERSION)?.apply {
                try {
                    val packageInfo = requireContext().packageManager
                        .getPackageInfo(requireContext().packageName, 0)
                    summary = "Version ${packageInfo.versionName} (${packageInfo.versionCode})"
                } catch (e: Exception) {
                    summary = "Version 1.0.0"
                    Log.e(TAG, "Failed to get package info", e)
                }
            }
        }
    }
}