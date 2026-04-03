package com.locationautomation.data

/**
 * Represents a geographical zone with location-based automation capabilities.
 * 
 * Constraints:
 * - Name: 1-50 characters, cannot be empty or whitespace only
 * - Latitude: -90.0 to 90.0 degrees
 * - Longitude: -180.0 to 180.0 degrees
 * - Radius: 10.0 to 5000.0 meters (practical minimum/maximum for geofencing)
 */
data class Zone(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val radius: Double,
    val detectionMethods: List<String>,
    val profileId: String,
    val wifiSSID: String? = null,
    val bluetoothAddress: String? = null,
    val bluetoothName: String? = null,
    val isManuallyTriggered: Boolean = false
) {
    companion object {
        private const val MIN_LATITUDE = -90.0
        private const val MAX_LATITUDE = 90.0
        private const val MIN_LONGITUDE = -180.0
        private const val MAX_LONGITUDE = 180.0
        private const val MIN_RADIUS = 10.0
        private const val MAX_RADIUS = 5000.0
        private const val MIN_NAME_LENGTH = 1
        private const val MAX_NAME_LENGTH = 50

        /**
         * Validates a Zone object against all constraints.
         * 
         * @param zone The zone to validate
         * @return Empty string if valid, error message if invalid
         */
        fun validate(zone: Zone): String {
            // Validate name
            val trimmedName = zone.name.trim()
            if (trimmedName.isEmpty()) {
                return "Zone name cannot be empty"
            }
            if (trimmedName.length < MIN_NAME_LENGTH) {
                return "Zone name must be at least $MIN_NAME_LENGTH character"
            }
            if (trimmedName.length > MAX_NAME_LENGTH) {
                return "Zone name cannot exceed $MAX_NAME_LENGTH characters"
            }
            
            // Validate latitude
            if (zone.latitude < MIN_LATITUDE || zone.latitude > MAX_LATITUDE) {
                return "Latitude must be between $MIN_LATITUDE and $MAX_LATITUDE degrees"
            }
            
            // Validate longitude
            if (zone.longitude < MIN_LONGITUDE || zone.longitude > MAX_LONGITUDE) {
                return "Longitude must be between $MIN_LONGITUDE and $MAX_LONGITUDE degrees"
            }
            
            // Validate radius
            if (zone.radius < MIN_RADIUS || zone.radius > MAX_RADIUS) {
                return "Radius must be between $MIN_RADIUS and $MAX_RADIUS meters"
            }
            
            return "" // Valid
        }
    }
}