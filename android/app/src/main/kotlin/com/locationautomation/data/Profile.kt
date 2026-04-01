package com.locationautomation.data

data class Profile(
    val id: String,
    val name: String,
    val ringtoneEnabled: Boolean = true,
    val vibrateEnabled: Boolean = true,
    val unmuteEnabled: Boolean = false,
    val dndEnabled: Boolean = false,
    val alarmsEnabled: Boolean = true,
    val timersEnabled: Boolean = true
)