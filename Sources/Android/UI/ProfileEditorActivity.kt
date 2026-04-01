package com.locationautomation.ui

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.locationautomation.data.Profile
import com.locationautomation.data.ZoneDatabase
import com.locationautomation.databinding.ActivityProfileEditorBinding
import java.util.UUID

class ProfileEditorActivity : AppCompatActivity() {

    private lateinit var binding: ActivityProfileEditorBinding
    private lateinit var database: ZoneDatabase
    private var profileId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityProfileEditorBinding.inflate(layoutInflater)
        setContentView(binding.root)

        database = ZoneDatabase(this)

        profileId = intent.getStringExtra(EXTRA_PROFILE_ID)
        profileId?.let { loadProfile(it) }

        binding.saveButton.setOnClickListener {
            saveProfile()
        }
    }

    private fun loadProfile(id: String) {
        val profile = database.getProfile(id)
        profile?.let {
            binding.profileNameInput.setText(it.name)
            binding.switchRingtone.isChecked = it.ringtoneEnabled
            binding.switchVibrate.isChecked = it.vibrateEnabled
            binding.switchUnmute.isChecked = it.unmuteEnabled
            binding.switchDnd.isChecked = it.dndEnabled
            binding.switchAlarms.isChecked = it.alarmsEnabled
            binding.switchTimers.isChecked = it.timersEnabled
        }
    }

    private fun saveProfile() {
        val name = binding.profileNameInput.text.toString().trim()
        if (name.isEmpty()) {
            Toast.makeText(this, "Please enter a profile name", Toast.LENGTH_SHORT).show()
            return
        }

        val profile = Profile(
            id = profileId ?: UUID.randomUUID().toString(),
            name = name,
            ringtoneEnabled = binding.switchRingtone.isChecked,
            vibrateEnabled = binding.switchVibrate.isChecked,
            unmuteEnabled = binding.switchUnmute.isChecked,
            dndEnabled = binding.switchDnd.isChecked,
            alarmsEnabled = binding.switchAlarms.isChecked,
            timersEnabled = binding.switchTimers.isChecked
        )

        try {
            database.saveProfile(profile)
            Toast.makeText(this, "Profile saved: ${profile.name}", Toast.LENGTH_SHORT).show()
            finish()
        } catch (e: Exception) {
            android.util.Log.e("ProfileEditorActivity", "Failed to save profile", e)
            Toast.makeText(this, "Failed to save profile", Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        const val EXTRA_PROFILE_ID = "extra_profile_id"
    }
}