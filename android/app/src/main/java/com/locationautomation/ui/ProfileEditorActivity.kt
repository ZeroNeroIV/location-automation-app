package com.locationautomation.ui

import android.content.Context
import android.os.Bundle
import android.widget.Toast
import com.google.android.material.button.MaterialButton
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import com.locationautomation.R
import com.locationautomation.data.Profile
import com.locationautomation.data.ZoneDatabase
import java.util.UUID

class ProfileEditorActivity : BaseActivity() {

    private lateinit var database: ZoneDatabase
    private var profileId: String? = null
    private var existingProfile: Profile? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_profile_editor)

        database = ZoneDatabase(this)
        profileId = intent.getStringExtra("profile_id")

        setupToolbar()
        setupViews()
    }

    private fun setupToolbar() {
        supportActionBar?.apply {
            title = if (profileId != null) "Edit Profile" else "New Profile"
            setDisplayHomeAsUpEnabled(true)
        }
    }

    private fun setupViews() {
        val nameLayout = findViewById<TextInputLayout>(R.id.profileNameLayout)
        val nameInput = findViewById<TextInputEditText>(R.id.profileNameInput)
        val switchRingtone = findViewById<MaterialSwitch>(R.id.switchRingtone)
        val switchVibrate = findViewById<MaterialSwitch>(R.id.switchVibrate)
        val switchUnmute = findViewById<MaterialSwitch>(R.id.switchUnmute)
        val switchDnd = findViewById<MaterialSwitch>(R.id.switchDnd)
        val switchAlarms = findViewById<MaterialSwitch>(R.id.switchAlarms)
        val switchTimers = findViewById<MaterialSwitch>(R.id.switchTimers)
        val saveButton = findViewById<MaterialButton>(R.id.saveButton)

        // Load existing profile if editing
        if (profileId != null) {
            try {
                existingProfile = database.getProfile(profileId!!)
                existingProfile?.let { profile ->
                    nameInput?.setText(profile.name)
                    switchRingtone.isChecked = profile.ringtoneEnabled
                    switchVibrate.isChecked = profile.vibrateEnabled
                    switchUnmute.isChecked = profile.unmuteEnabled
                    switchDnd.isChecked = profile.dndEnabled
                    switchAlarms.isChecked = profile.alarmsEnabled
                    switchTimers.isChecked = profile.timersEnabled
                }
            } catch (e: Exception) {
                android.util.Log.e("ProfileEditor", "Failed to load profile", e)
            }
        }

        saveButton.setOnClickListener {
            val name = nameInput?.text?.toString()?.trim()
            if (name.isNullOrEmpty()) {
                nameLayout?.error = "Profile name is required"
                return@setOnClickListener
            }

            val profile = Profile(
                id = profileId ?: UUID.randomUUID().toString(),
                name = name,
                ringtoneEnabled = switchRingtone.isChecked,
                vibrateEnabled = switchVibrate.isChecked,
                unmuteEnabled = switchUnmute.isChecked,
                dndEnabled = switchDnd.isChecked,
                alarmsEnabled = switchAlarms.isChecked,
                timersEnabled = switchTimers.isChecked
            )

            try {
                database.saveProfile(profile)
                Toast.makeText(this, "Profile saved: $name", Toast.LENGTH_SHORT).show()
                setResult(RESULT_OK)
                finish()
            } catch (e: Exception) {
                android.util.Log.e("ProfileEditor", "Failed to save profile", e)
                Toast.makeText(this, "Failed to save profile", Toast.LENGTH_SHORT).show()
            }
        }

    }

    override fun onSupportNavigateUp(): Boolean {
        onBackPressedDispatcher.onBackPressed()
        return true
    }
}
