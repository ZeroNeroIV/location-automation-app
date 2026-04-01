package com.locationautomation.data

data class Zone(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val radius: Double,
    val detectionMethods: List<String>,
    val profileId: String
)