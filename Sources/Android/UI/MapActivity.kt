package com.locationautomation.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.widget.EditText
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.locationautomation.R
import com.locationautomation.data.Zone
import com.locationautomation.data.ZoneDatabase
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
        private const val TAG = "MapActivity"
    }

    private lateinit var mapView: MapView
    private lateinit var database: ZoneDatabase
    private var userLocation: GeoPoint? = null
    private var zones: List<Zone> = emptyList()

    private val locationPermissionRequest = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineLocationGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        val coarseLocationGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false
        
        when {
            fineLocationGranted || coarseLocationGranted -> {
                Log.d(TAG, "Location permission granted")
                centerOnUserLocation()
            }
            else -> {
                Log.w(TAG, "Location permission denied")
                Toast.makeText(this, "Location permission required", Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "MapActivity onCreate")
        
        Configuration.getInstance().apply {
            userAgentValue = packageName
            load(this@MapActivity, getSharedPreferences("osmdroid", Context.MODE_PRIVATE))
        }
        
        setContentView(R.layout.activity_map)
        
        database = ZoneDatabase(this)
        
        mapView = findViewById(R.id.mapView)
        mapView.setTileSource(TileSourceFactory.MAPNIK)
        mapView.setMultiTouchControls(true)
        mapView.controller.setZoom(17.0)
        
        mapView.overlays.add(object : org.osmdroid.views.overlay.Overlay() {
            override fun onLongPress(e: android.view.MotionEvent?, mapView: MapView?): Boolean {
                if (e != null && mapView != null) {
                    val projection = mapView.projection
                    val geoPoint = projection.fromPixels(e.x.toInt(), e.y.toInt()) as GeoPoint
                    Log.d(TAG, "Long press at: ${geoPoint.latitude}, ${geoPoint.longitude}")
                    showCreateZoneDialog(geoPoint)
                    return true
                }
                return false
            }
        })
        
        checkPermissionsAndLoad()
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
        Log.d(TAG, "Requesting location permissions")
        locationPermissionRequest.launch(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )
    }

    private fun centerOnUserLocation() {
        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            
            val location = locationManager.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            
            if (location != null) {
                userLocation = GeoPoint(location.latitude, location.longitude)
                Log.d(TAG, "User location: ${userLocation?.latitude}, ${userLocation?.longitude}")
                mapView.controller.setCenter(userLocation)
            } else {
                Log.w(TAG, "No last known location available")
                Toast.makeText(this, "Unable to get current location", Toast.LENGTH_SHORT).show()
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception getting location", e)
            Toast.makeText(this, "Location permission required", Toast.LENGTH_SHORT).show()
        }
    }

    private fun loadZones() {
        try {
            zones = database.getAllZones()
            Log.d(TAG, "Loaded ${zones.size} zones")
            renderZones()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load zones", e)
        }
    }

    private fun renderZones() {
        mapView.overlays.clear()
        
        zones.forEach { zone ->
            addZoneMarker(zone)
        }
        
        mapView.invalidate()
    }

    private fun addZoneMarker(zone: Zone) {
        val center = GeoPoint(zone.latitude, zone.longitude)
        
        val marker = Marker(mapView).apply {
            position = center
            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            title = zone.name
            snippet = "Radius: ${zone.radius.toInt()}m"
            
            setOnMarkerClickListener { _, _ ->
                showDeleteZoneDialog(zone)
                true
            }
        }
        mapView.overlays.add(marker)
        
        val circle = Polygon().apply {
            points = calculateCirclePoints(zone.latitude, zone.longitude, zone.radius)
            fillPaint.color = Color.argb(50, 33, 150, 243)
            outlinePaint.color = Color.BLUE
            outlinePaint.strokeWidth = 2f
        }
        mapView.overlays.add(circle)
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
        
        radiusInput.setText(DEFAULT_RADIUS_METERS.toInt().toString())
        
        AlertDialog.Builder(this)
            .setTitle("Create New Zone")
            .setView(dialogView)
            .setPositiveButton("Create") { _, _ ->
                val name = nameInput.text.toString().trim()
                val radius = radiusInput.text.toString().toDoubleOrNull() ?: DEFAULT_RADIUS_METERS
                
                if (name.isNotEmpty()) {
                    createZone(name, location.latitude, location.longitude, radius)
                } else {
                    Toast.makeText(this, "Please enter a zone name", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun createZone(name: String, latitude: Double, longitude: Double, radius: Double) {
        val zone = Zone(
            id = UUID.randomUUID().toString(),
            name = name,
            latitude = latitude,
            longitude = longitude,
            radius = radius,
            detectionMethods = listOf("gps"),
            profileId = UUID.randomUUID().toString()
        )
        
        try {
            database.saveZone(zone)
            zones = database.getAllZones()
            renderZones()
            Log.d(TAG, "Zone created: $name at ($latitude, $longitude) with radius $radius")
            Toast.makeText(this, "Zone created: $name", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create zone", e)
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

    private fun deleteZone(zone: Zone) {
        try {
            database.deleteZone(zone.id)
            zones = database.getAllZones()
            renderZones()
            Log.d(TAG, "Zone deleted: ${zone.name}")
            Toast.makeText(this, "Zone deleted: ${zone.name}", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete zone", e)
            Toast.makeText(this, "Failed to delete zone", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onResume() {
        super.onResume()
        mapView.onResume()
    }

    override fun onPause() {
        super.onPause()
        mapView.onPause()
    }
}