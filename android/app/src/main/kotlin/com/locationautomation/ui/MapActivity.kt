package com.locationautomation.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.view.View
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.locationautomation.R
import com.locationautomation.data.Profile
import com.locationautomation.data.Zone
import com.locationautomation.data.ZoneDatabase
import com.locationautomation.util.SoundManager
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import java.util.UUID

class MapActivity : AppCompatActivity() {

    companion object {
        private const val DEFAULT_RADIUS_METERS = 100.0
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private lateinit var mapView: MapView
    private lateinit var database: ZoneDatabase
    private var userLocation: GeoPoint? = null
    private var zones: List<Zone> = emptyList()
    private var userLocationMarker: Marker? = null
    private lateinit var locationManager: LocationManager
    private lateinit var longPressOverlay: org.osmdroid.views.overlay.Overlay
    private var debugMode = false
    private var selectedZoneForMove: Zone? = null
    private val locationListener = object : android.location.LocationListener {
        override fun onLocationChanged(location: android.location.Location) {
            updateUserLocation(location)
        }
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    private val locationPermissionRequest = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineLocationGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        val coarseLocationGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false
        
        when {
            fineLocationGranted || coarseLocationGranted -> {
                centerOnUserLocation()
            }
            else -> {
                Toast.makeText(this, "Location permission required", Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Configuration.getInstance().apply {
            userAgentValue = packageName
            load(this@MapActivity, getSharedPreferences("osmdroid", Context.MODE_PRIVATE))
        }
        
        setContentView(R.layout.activity_map)
        
        database = ZoneDatabase(this)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        debugMode = getSharedPreferences("app_prefs", Context.MODE_PRIVATE).getBoolean("debug_mode", false)
        
        mapView = findViewById(R.id.mapView)
        mapView.setTileSource(TileSourceFactory.MAPNIK)
        mapView.setMultiTouchControls(true)
        mapView.controller.setZoom(17.0)
        
        findViewById<com.google.android.material.floatingactionbutton.FloatingActionButton>(R.id.btnBack).setOnClickListener {
            finish()
        }
        
        findViewById<com.google.android.material.floatingactionbutton.FloatingActionButton>(R.id.btnMyLocation).setOnClickListener {
            userLocation?.let {
                mapView.controller.animateTo(it)
                mapView.controller.setZoom(17.0)
            } ?: Toast.makeText(this, "Waiting for location...", Toast.LENGTH_SHORT).show()
        }
        
        findViewById<View>(R.id.btnDismissHint).setOnClickListener {
            findViewById<View>(R.id.hintCard).visibility = View.GONE
        }
        
        longPressOverlay = object : org.osmdroid.views.overlay.Overlay() {
            override fun onLongPress(e: android.view.MotionEvent?, mapView: MapView?): Boolean {
                if (e != null && mapView != null) {
                    val projection = mapView.projection
                    val geoPoint = projection.fromPixels(e.x.toInt(), e.y.toInt()) as GeoPoint
                    showCreateZoneDialog(geoPoint)
                    return true
                }
                return false
            }

            override fun onSingleTapConfirmed(e: android.view.MotionEvent?, mapView: MapView?): Boolean {
                if (debugMode && selectedZoneForMove != null && e != null && mapView != null) {
                    val projection = mapView.projection
                    val geoPoint = projection.fromPixels(e.x.toInt(), e.y.toInt()) as GeoPoint
                    moveZone(selectedZoneForMove!!, geoPoint.latitude, geoPoint.longitude)
                    selectedZoneForMove = null
                    return true
                }
                return false
            }
        }
        mapView.overlays.add(longPressOverlay)
        
        checkPermissionsAndLoad()
        
        val zoneId = intent.getStringExtra("zone_id")
        if (zoneId != null) {
            focusOnZone(zoneId)
        }
    }

    private fun checkPermissionsAndLoad() {
        if (hasLocationPermission()) {
            loadZones()
            centerOnUserLocation()
        } else {
            requestLocationPermissions()
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestLocationPermissions() {
        locationPermissionRequest.launch(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )
    }

    private fun centerOnUserLocation() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                30000L,
                10f,
                locationListener,
                Looper.getMainLooper()
            )
            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                30000L,
                10f,
                locationListener,
                Looper.getMainLooper()
            )
            
            val location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            
            if (location != null) {
                updateUserLocation(location)
            }
        }
    }
    
    private fun updateUserLocation(location: android.location.Location) {
        userLocation = GeoPoint(location.latitude, location.longitude)
        
        renderZones()
        
        if (mapView.controller != null && mapView.mapCenter == null) {
            mapView.controller.setCenter(userLocation)
        }
    }

    private fun loadZones() {
        try {
            zones = database.getAllZones()
            renderZones()
        } catch (e: Exception) {
            android.util.Log.e("MapActivity", "Failed to load zones", e)
        }
    }

    private fun focusOnZone(zoneId: String) {
        val zone = zones.find { it.id == zoneId } ?: database.getZone(zoneId)
        if (zone != null) {
            val center = GeoPoint(zone.latitude, zone.longitude)
            mapView.controller.animateTo(center)
            mapView.controller.setZoom(17.0)
            showZoneOptionsDialog(zone)
        }
    }

    private fun renderZones() {
        mapView.overlays.clear()
        mapView.overlays.add(longPressOverlay)
        
        zones.forEach { zone ->
            addZoneMarker(zone)
        }
        
        userLocation?.let {
            userLocationMarker = Marker(mapView).apply {
                position = it
                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                title = "Your Location"
                icon = ContextCompat.getDrawable(this@MapActivity, android.R.drawable.ic_menu_mylocation)?.apply {
                    setTint(ContextCompat.getColor(this@MapActivity, R.color.primary))
                }
            }
            mapView.overlays.add(userLocationMarker)
        }
        
        mapView.invalidate()
    }

    private fun addZoneMarker(zone: Zone) {
        val center = GeoPoint(zone.latitude, zone.longitude)
        
        val circle = Polygon().apply {
            points = calculateCirclePoints(zone.latitude, zone.longitude, zone.radius)
            fillPaint.color = Color.argb(32, 13, 148, 136)
            outlinePaint.color = Color.parseColor("#0D9488")
            outlinePaint.strokeWidth = 2f
        }
        mapView.overlays.add(circle)
        
        val marker = Marker(mapView).apply {
            position = center
            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            title = zone.name
            snippet = "Radius: ${zone.radius.toInt()}m"
            
            setOnMarkerClickListener { _, _ ->
                showZoneOptionsDialog(zone)
                true
            }
        }
        mapView.overlays.add(marker)
    }

    private fun calculateCirclePoints(centerLat: Double, centerLng: Double, radiusMeters: Double): List<GeoPoint> {
        val points = mutableListOf<GeoPoint>()
        val numPoints = 60
        
        for (i in 0 until numPoints) {
            val angle = Math.toRadians((i * 360.0 / numPoints))
            val lat = centerLat + (radiusMeters / 111320.0) * Math.cos(angle)
            val lng = centerLng + (radiusMeters / (111320.0 * Math.cos(Math.toRadians(centerLat)))) * Math.sin(angle)
            points.add(GeoPoint(lat, lng))
        }
        
        return points
    }

    private fun showCreateZoneDialog(location: GeoPoint) {
        val dialogView = layoutInflater.inflate(R.layout.dialog_create_zone, null)
        val nameInput = dialogView.findViewById<EditText>(R.id.zoneNameInput)
        val radiusInput = dialogView.findViewById<EditText>(R.id.zoneRadiusInput)
        val profileGroup = dialogView.findViewById<android.widget.RadioGroup>(R.id.profileGroup)
        
        radiusInput.setText(DEFAULT_RADIUS_METERS.toInt().toString())
        
        AlertDialog.Builder(this)
            .setTitle("Create New Zone")
            .setView(dialogView)
            .setPositiveButton("Create") { _, _ ->
                val name = nameInput.text.toString().trim()
                val radius = radiusInput.text.toString().toDoubleOrNull() ?: DEFAULT_RADIUS_METERS
                
                val profileType = when (profileGroup.checkedRadioButtonId) {
                    R.id.profileNormal -> "normal"
                    R.id.profileSilent -> "silent"
                    R.id.profileVibrate -> "vibrate"
                    R.id.profileDnd -> "dnd"
                    else -> "normal"
                }
                
                if (name.isNotEmpty()) {
                    createZone(name, location.latitude, location.longitude, radius, profileType)
                } else {
                    Toast.makeText(this, "Please enter a zone name", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun createZone(name: String, latitude: Double, longitude: Double, radius: Double, profileType: String) {
        val profileId = UUID.randomUUID().toString()
        
        val profile = Profile(
            id = profileId,
            name = when (profileType) {
                "normal" -> "Normal"
                "silent" -> "Silent"
                "vibrate" -> "Vibrate"
                "dnd" -> "Do Not Disturb"
                else -> "Normal"
            },
            ringtoneEnabled = profileType == "normal",
            vibrateEnabled = profileType == "normal" || profileType == "vibrate",
            unmuteEnabled = false,
            dndEnabled = profileType == "dnd",
            alarmsEnabled = profileType != "silent",
            timersEnabled = profileType != "silent"
        )
        
        val zone = Zone(
            id = UUID.randomUUID().toString(),
            name = name,
            latitude = latitude,
            longitude = longitude,
            radius = radius,
            detectionMethods = listOf("gps"),
            profileId = profileId
        )
        
        try {
            database.saveProfile(profile)
            database.saveZone(zone)
            zones = database.getAllZones()
            renderZones()
            Toast.makeText(this, "Zone created: $name", Toast.LENGTH_SHORT).show()
            SoundManager.playSound(this, R.raw.error_bleep_3)
        } catch (e: Exception) {
            android.util.Log.e("MapActivity", "Failed to create zone", e)
            Toast.makeText(this, "Failed to create zone", Toast.LENGTH_SHORT).show()
        }
    }

    private fun showDeleteZoneDialog(zone: Zone) {
        AlertDialog.Builder(this)
            .setTitle("Delete Zone")
            .setMessage("Are you sure you want to delete '${zone.name}'?")
            .setPositiveButton("Delete") { _, _ ->
                deleteZone(zone)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showZoneOptionsDialog(zone: Zone) {
        val sheetView = layoutInflater.inflate(R.layout.bottom_sheet_zone_options, null)
        val bottomSheet = BottomSheetDialog(this)
        bottomSheet.setContentView(sheetView)

        sheetView.findViewById<TextView>(R.id.sheetZoneName).text = zone.name
        sheetView.findViewById<TextView>(R.id.sheetZoneDetails).text =
            "Radius: ${zone.radius.toInt()}m • Profile: ${getProfileName(zone.profileId)}"

        if (debugMode) {
            sheetView.findViewById<View>(R.id.actionMove).visibility = View.VISIBLE
        }

        sheetView.findViewById<View>(R.id.actionEdit).setOnClickListener {
            bottomSheet.dismiss()
            showEditZoneDialog(zone)
        }

        sheetView.findViewById<View>(R.id.actionMove).setOnClickListener {
            bottomSheet.dismiss()
            selectedZoneForMove = zone
            Toast.makeText(this, "Tap on the map to move '${zone.name}'", Toast.LENGTH_LONG).show()
        }

        sheetView.findViewById<View>(R.id.actionDelete).setOnClickListener {
            bottomSheet.dismiss()
            showDeleteZoneDialog(zone)
        }

        bottomSheet.show()
    }

    private fun getProfileName(profileId: String): String {
        return try {
            database.getProfile(profileId)?.name ?: "Normal"
        } catch (e: Exception) {
            "Normal"
        }
    }

    private fun showEditZoneDialog(zone: Zone) {
        val dialogView = layoutInflater.inflate(R.layout.dialog_create_zone, null)
        val nameInput = dialogView.findViewById<EditText>(R.id.zoneNameInput)
        val radiusInput = dialogView.findViewById<EditText>(R.id.zoneRadiusInput)
        val profileGroup = dialogView.findViewById<android.widget.RadioGroup>(R.id.profileGroup)
        
        nameInput.setText(zone.name)
        radiusInput.setText(zone.radius.toInt().toString())
        
        val currentProfile = database.getProfile(zone.profileId)
        val profileToSelect = when {
            currentProfile?.dndEnabled == true -> R.id.profileDnd
            currentProfile?.ringtoneEnabled == false && currentProfile.vibrateEnabled == true -> R.id.profileVibrate
            currentProfile?.ringtoneEnabled == false && currentProfile.alarmsEnabled == false -> R.id.profileSilent
            else -> R.id.profileNormal
        }
        profileGroup.check(profileToSelect)
        
        AlertDialog.Builder(this)
            .setTitle("Edit Zone")
            .setView(dialogView)
            .setPositiveButton("Save") { _, _ ->
                val name = nameInput.text.toString().trim()
                val radius = radiusInput.text.toString().toDoubleOrNull() ?: zone.radius
                
                val profileType = when (profileGroup.checkedRadioButtonId) {
                    R.id.profileNormal -> "normal"
                    R.id.profileSilent -> "silent"
                    R.id.profileVibrate -> "vibrate"
                    R.id.profileDnd -> "dnd"
                    else -> "normal"
                }
                
                if (name.isNotEmpty()) {
                    updateZone(zone.id, name, radius, profileType)
                } else {
                    Toast.makeText(this, "Please enter a zone name", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun updateZone(zoneId: String, name: String, radius: Double, profileType: String) {
        try {
            val existingZone = zones.find { it.id == zoneId }
            if (existingZone != null) {
                val profileId = existingZone.profileId
                val profile = Profile(
                    id = profileId,
                    name = when (profileType) {
                        "normal" -> "Normal"
                        "silent" -> "Silent"
                        "vibrate" -> "Vibrate"
                        "dnd" -> "Do Not Disturb"
                        else -> "Normal"
                    },
                    ringtoneEnabled = profileType == "normal",
                    vibrateEnabled = profileType == "normal" || profileType == "vibrate",
                    unmuteEnabled = false,
                    dndEnabled = profileType == "dnd",
                    alarmsEnabled = profileType != "silent",
                    timersEnabled = profileType != "silent"
                )
                database.saveProfile(profile)
                
                val updatedZone = existingZone.copy(name = name, radius = radius)
                database.updateZone(updatedZone)
                zones = database.getAllZones()
                renderZones()
                Toast.makeText(this, "Zone updated: $name", Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            android.util.Log.e("MapActivity", "Failed to update zone", e)
            Toast.makeText(this, "Failed to update zone", Toast.LENGTH_SHORT).show()
        }
    }

    private fun deleteZone(zone: Zone) {
        try {
            database.deleteZone(zone.id)
            zones = database.getAllZones()
            renderZones()
            Toast.makeText(this, "Zone deleted: ${zone.name}", Toast.LENGTH_SHORT).show()
            SoundManager.playSound(this, R.raw.error_bleep_4)
        } catch (e: Exception) {
            android.util.Log.e("MapActivity", "Failed to delete zone", e)
            Toast.makeText(this, "Failed to delete zone", Toast.LENGTH_SHORT).show()
        }
    }

    private fun moveZone(zone: Zone, latitude: Double, longitude: Double) {
        try {
            val updatedZone = zone.copy(latitude = latitude, longitude = longitude)
            database.updateZone(updatedZone)
            zones = database.getAllZones()
            renderZones()
            Toast.makeText(this, "Zone moved: ${zone.name}", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            android.util.Log.e("MapActivity", "Failed to move zone", e)
            Toast.makeText(this, "Failed to move zone", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onResume() {
        super.onResume()
        mapView.onResume()
    }

    override fun onPause() {
        super.onPause()
        mapView.onPause()
        if (hasLocationPermission()) {
            locationManager.removeUpdates(locationListener)
        }
    }
}