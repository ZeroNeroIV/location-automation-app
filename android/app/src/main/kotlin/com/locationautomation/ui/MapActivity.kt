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
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.locationautomation.R
import com.locationautomation.data.Profile
import com.locationautomation.data.Zone
import com.locationautomation.data.ZoneDatabase
import com.locationautomation.util.SoundManager
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.XYTileSource
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID
import org.json.JSONArray

class MapActivity : BaseActivity() {

    companion object {
        private const val DEFAULT_RADIUS_METERS = 100.0
        private const val PERMISSION_REQUEST_CODE = 1001
        
        // Dark map tile source (CartoDB Dark Matter)
        private val DARK_TILE_SOURCE = XYTileSource(
            "CartoDBDarkMatter",
            1,
            20,
            256,
            ".png",
            arrayOf(
                "https://a.basemaps.cartocdn.com/dark_all/",
                "https://b.basemaps.cartocdn.com/dark_all/",
                "https://c.basemaps.cartocdn.com/dark_all/",
                "https://d.basemaps.cartocdn.com/dark_all/"
            ),
            "CartoDB Dark Matter"
        )
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
    private var searchZoneMap: MutableMap<String, Zone> = mutableMapOf()
    private var searchPlaceMap: MutableMap<String, GeoPoint> = mutableMapOf()
    private var searchJob: Thread? = null
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
        debugMode = getSharedPreferences("app_prefs", Context.MODE_PRIVATE).getBoolean("dev_mode", false)
        
        mapView = findViewById(R.id.mapView)
        mapView.setTileSource(if (isDarkMode()) DARK_TILE_SOURCE else TileSourceFactory.MAPNIK)
        mapView.setMultiTouchControls(true)
        mapView.setBuiltInZoomControls(false)
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
        
        setupSearch()
        
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

    private fun isDarkMode(): Boolean {
        return (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
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
            updateSearchAdapter()
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
        
        val fillColor = if (isDarkMode()) Color.argb(48, 20, 184, 166) else Color.argb(32, 13, 148, 136)
        val strokeColor = if (isDarkMode()) Color.parseColor("#14B8A6") else Color.parseColor("#0D9488")
        
        val circle = Polygon().apply {
            points = calculateCirclePoints(zone.latitude, zone.longitude, zone.radius)
            fillPaint.color = fillColor
            outlinePaint.color = strokeColor
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

    private fun setupSearch() {
        val searchInput = findViewById<EditText>(R.id.searchInput)
        val btnClear = findViewById<ImageButton>(R.id.btnClearSearch)
        val resultsCard = findViewById<com.google.android.material.card.MaterialCardView>(R.id.searchResultsCard)
        val resultsList = findViewById<LinearLayout>(R.id.searchResultsList)
        
        searchInput.setOnFocusChangeListener { _, hasFocus ->
            mapView.isClickable = !hasFocus
            mapView.isEnabled = !hasFocus
        }
        
        searchInput.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: android.text.Editable?) {
                val query = s?.toString()?.trim() ?: ""
                btnClear.visibility = if (query.isNotEmpty()) View.VISIBLE else View.GONE
                
                resultsList.removeAllViews()
                searchZoneMap.clear()
                searchPlaceMap.clear()
                
                if (query.isEmpty()) {
                    resultsCard.visibility = View.GONE
                    return
                }
                
                if (query.length < 2) {
                    resultsCard.visibility = View.GONE
                    return
                }
                
                val zoneMatches = zones.filter { it.name.contains(query, ignoreCase = true) }
                
                zoneMatches.forEach { zone ->
                    searchZoneMap[zone.name] = zone
                    val textView = TextView(this@MapActivity).apply {
                        text = zone.name
                        textSize = 14f
                        setTextColor(getColorCompat(R.color.on_surface))
                        setPadding(32, 24, 32, 24)
                        setBackgroundResource(android.R.drawable.list_selector_background)
                        setOnClickListener {
                            searchInput.setText("")
                            searchInput.clearFocus()
                            resultsCard.visibility = View.GONE
                            navigateToZone(zone)
                        }
                    }
                    resultsList.addView(textView)
                }
                
                searchJob?.interrupt()
                searchJob = Thread {
                    try {
                        val encoded = URLEncoder.encode(query, "UTF-8")
                        val url = URL("https://nominatim.openstreetmap.org/search?format=json&q=$encoded&limit=5&addressdetails=1")
                        val conn = url.openConnection() as HttpURLConnection
                        conn.requestMethod = "GET"
                        conn.setRequestProperty("User-Agent", "LocationAutomationApp/1.0")
                        conn.connectTimeout = 5000
                        conn.readTimeout = 5000
                        
                        if (conn.responseCode == 200) {
                            val body = conn.inputStream.bufferedReader().use { it.readText() }
                            val places = JSONArray(body)
                            
                            runOnUiThread {
                                if (places.length() > 0) {
                                    if (zoneMatches.isNotEmpty()) {
                                        val divider = TextView(this@MapActivity).apply {
                                            text = "Places"
                                            textSize = 11f
                                            setTextColor(getColorCompat(R.color.on_surface_secondary))
                                            setPadding(32, 16, 32, 8)
                                        }
                                        resultsList.addView(divider)
                                    }
                                    
                                    for (i in 0 until places.length()) {
                                        val place = places.getJSONObject(i)
                                        val displayName = place.getString("display_name")
                                        val shortName = if (displayName.length > 60) displayName.take(60) + "…" else displayName
                                        val lat = place.getString("lat").toDouble()
                                        val lon = place.getString("lon").toDouble()
                                        val geoPoint = GeoPoint(lat, lon)
                                        searchPlaceMap[shortName] = geoPoint
                                        
                                        val textView = TextView(this@MapActivity).apply {
                                            text = shortName
                                            textSize = 13f
                                            setTextColor(getColorCompat(R.color.on_surface_secondary))
                                            setPadding(32, 20, 32, 20)
                                            setBackgroundResource(android.R.drawable.list_selector_background)
                                            setOnClickListener {
                                                searchInput.setText("")
                                                searchInput.clearFocus()
                                                resultsCard.visibility = View.GONE
                                                mapView.controller.setCenter(geoPoint)
                                                mapView.controller.setZoom(17.0)
                                            }
                                        }
                                        resultsList.addView(textView)
                                    }
                                }
                                resultsCard.visibility = View.VISIBLE
                            }
                        }
                    } catch (_: InterruptedException) {
                    } catch (e: Exception) {
                        android.util.Log.e("MapActivity", "Nominatim search failed", e)
                        runOnUiThread {
                            resultsCard.visibility = View.VISIBLE
                        }
                    }
                }.also { it.start() }
            }
        })
        
        btnClear.setOnClickListener {
            searchInput.setText("")
            resultsCard.visibility = View.GONE
            resultsList.removeAllViews()
            searchZoneMap.clear()
        }
    }
    
    private fun getColorCompat(colorRes: Int): Int {
        return ContextCompat.getColor(this, colorRes)
    }
    
    private fun navigateToZone(zone: Zone) {
        val center = GeoPoint(zone.latitude, zone.longitude)
        mapView.controller.setCenter(center)
        mapView.controller.setZoom(17.0)
        showZoneOptionsDialog(zone)
    }
    
    private fun updateSearchAdapter() {
        val searchInput = findViewById<EditText>(R.id.searchInput)
        val currentQuery = searchInput.text.toString().trim()
        
        if (currentQuery.isNotEmpty()) {
            val matches = zones.filter { it.name.contains(currentQuery, ignoreCase = true) }
            searchZoneMap.clear()
            matches.forEach { searchZoneMap[it.name] = it }
        }
    }

    private var currentEditingZone: Zone? = null
    private var selectedProfileType: String = "normal"
    private var wifiEnabled: Boolean = true
    private var bluetoothEnabled: Boolean = true
    private var mobileDataEnabled: Boolean = true

    private fun showCreateZoneDialog(location: GeoPoint) {
        val sheetView = layoutInflater.inflate(R.layout.bottom_sheet_zone_editor, null)
        val bottomSheet = BottomSheetDialog(this)
        bottomSheet.setContentView(sheetView)

        currentEditingZone = null
        selectedProfileType = "normal"
        wifiEnabled = true
        bluetoothEnabled = true
        mobileDataEnabled = true

        sheetView.findViewById<TextView>(R.id.sheetTitle).text = "Create New Zone"
        sheetView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnSave).text = "Create Zone"
        sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneRadiusInput).setText(DEFAULT_RADIUS_METERS.toInt().toString())

        clearProfileSelection(sheetView)
        sheetView.findViewById<View>(R.id.radioNormal).let { (it as RadioButton).isChecked = true }

        setupProfileClicks(sheetView)
        setupConnectivitySwitches(sheetView)

        sheetView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnSave).setOnClickListener {
            val name = sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneNameInput).text.toString().trim()
            val radius = sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneRadiusInput).text.toString().toDoubleOrNull() ?: DEFAULT_RADIUS_METERS

            if (name.isNotEmpty()) {
                // Validate inputs
                val tempZone = Zone(
                    id = "temp",
                    name = name,
                    latitude = location.latitude,
                    longitude = location.longitude,
                    radius = radius,
                    detectionMethods = listOf("gps"),
                    profileId = "temp"
                )
                val validationError = Zone.validate(tempZone)
                if (validationError.isEmpty()) {
                    bottomSheet.dismiss()
                    createZone(name, location.latitude, location.longitude, radius, selectedProfileType, wifiEnabled, bluetoothEnabled, mobileDataEnabled)
                } else {
                    Toast.makeText(this, validationError, Toast.LENGTH_LONG).show()
                }
            } else {
                Toast.makeText(this, "Please enter a zone name", Toast.LENGTH_SHORT).show()
            }
        }

        bottomSheet.show()
    }

    private fun createZone(name: String, latitude: Double, longitude: Double, radius: Double, profileType: String, wifi: Boolean, bluetooth: Boolean, mobileData: Boolean) {
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
            timersEnabled = profileType != "silent",
            wifiEnabled = wifi,
            bluetoothEnabled = bluetooth,
            mobileDataEnabled = mobileData
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
            updateSearchAdapter()
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
        val sheetView = layoutInflater.inflate(R.layout.bottom_sheet_zone_editor, null)
        val bottomSheet = BottomSheetDialog(this)
        bottomSheet.setContentView(sheetView)

        currentEditingZone = zone
        sheetView.findViewById<TextView>(R.id.sheetTitle).text = "Edit Zone"
        sheetView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnSave).text = "Save Changes"
        sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneNameInput).setText(zone.name)
        sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneRadiusInput).setText(zone.radius.toInt().toString())

        val currentProfile = database.getProfile(zone.profileId)
        selectedProfileType = when {
            currentProfile?.dndEnabled == true -> "dnd"
            currentProfile?.ringtoneEnabled == false && currentProfile.vibrateEnabled == true -> "vibrate"
            currentProfile?.ringtoneEnabled == false && currentProfile.alarmsEnabled == false -> "silent"
            else -> "normal"
        }

        wifiEnabled = currentProfile?.wifiEnabled ?: true
        bluetoothEnabled = currentProfile?.bluetoothEnabled ?: true
        mobileDataEnabled = currentProfile?.mobileDataEnabled ?: true

        clearProfileSelection(sheetView)
        val radioId = when (selectedProfileType) {
            "dnd" -> R.id.radioDnd
            "vibrate" -> R.id.radioVibrate
            "silent" -> R.id.radioSilent
            else -> R.id.radioNormal
        }
        sheetView.findViewById<View>(radioId).let { (it as RadioButton).isChecked = true }

        setupProfileClicks(sheetView)
        setupConnectivitySwitches(sheetView)

        sheetView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnSave).setOnClickListener {
            val name = sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneNameInput).text.toString().trim()
            val radius = sheetView.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.zoneRadiusInput).text.toString().toDoubleOrNull() ?: zone.radius

            if (name.isNotEmpty()) {
                // Validate inputs
                val tempZone = Zone(
                    id = zone.id,
                    name = name,
                    latitude = zone.latitude,
                    longitude = zone.longitude,
                    radius = radius,
                    detectionMethods = zone.detectionMethods,
                    profileId = zone.profileId
                )
                val validationError = Zone.validate(tempZone)
                if (validationError.isEmpty()) {
                    bottomSheet.dismiss()
                    updateZone(zone.id, name, radius, selectedProfileType, wifiEnabled, bluetoothEnabled, mobileDataEnabled)
                } else {
                    Toast.makeText(this, validationError, Toast.LENGTH_LONG).show()
                }
            } else {
                Toast.makeText(this, "Please enter a zone name", Toast.LENGTH_SHORT).show()
            }
        }

        bottomSheet.show()
    }

    private fun clearProfileSelection(sheetView: View) {
        (sheetView.findViewById<View>(R.id.radioNormal) as RadioButton).isChecked = false
        (sheetView.findViewById<View>(R.id.radioSilent) as RadioButton).isChecked = false
        (sheetView.findViewById<View>(R.id.radioVibrate) as RadioButton).isChecked = false
        (sheetView.findViewById<View>(R.id.radioDnd) as RadioButton).isChecked = false
    }

    private fun setupProfileClicks(sheetView: View) {
        val profileRows = listOf(
            Pair(R.id.profileNormal, Pair("normal", R.id.radioNormal)),
            Pair(R.id.profileSilent, Pair("silent", R.id.radioSilent)),
            Pair(R.id.profileVibrate, Pair("vibrate", R.id.radioVibrate)),
            Pair(R.id.profileDnd, Pair("dnd", R.id.radioDnd)),
        )

        profileRows.forEach { (rowId, profilePair) ->
            val (profileType, radioId) = profilePair
            sheetView.findViewById<View>(rowId).setOnClickListener {
                clearProfileSelection(sheetView)
                (sheetView.findViewById<View>(radioId) as RadioButton).isChecked = true
                selectedProfileType = profileType
            }
        }
    }

    private fun setupConnectivitySwitches(sheetView: View) {
        val switchWifi = sheetView.findViewById<androidx.appcompat.widget.SwitchCompat>(R.id.switchWifi)
        val switchBluetooth = sheetView.findViewById<androidx.appcompat.widget.SwitchCompat>(R.id.switchBluetooth)
        val switchMobileData = sheetView.findViewById<androidx.appcompat.widget.SwitchCompat>(R.id.switchMobileData)

        switchWifi.isChecked = wifiEnabled
        switchBluetooth.isChecked = bluetoothEnabled
        switchMobileData.isChecked = mobileDataEnabled

        sheetView.findViewById<View>(R.id.connectivityWifi).setOnClickListener {
            wifiEnabled = !wifiEnabled
            switchWifi.isChecked = wifiEnabled
        }
        sheetView.findViewById<View>(R.id.connectivityBluetooth).setOnClickListener {
            bluetoothEnabled = !bluetoothEnabled
            switchBluetooth.isChecked = bluetoothEnabled
        }
        sheetView.findViewById<View>(R.id.connectivityMobileData).setOnClickListener {
            mobileDataEnabled = !mobileDataEnabled
            switchMobileData.isChecked = mobileDataEnabled
        }
    }

    private fun updateZone(zoneId: String, name: String, radius: Double, profileType: String, wifi: Boolean, bluetooth: Boolean, mobileData: Boolean) {
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
                    timersEnabled = profileType != "silent",
                    wifiEnabled = wifi,
                    bluetoothEnabled = bluetooth,
                    mobileDataEnabled = mobileData
                )
                database.saveProfile(profile)
                
                val updatedZone = existingZone.copy(name = name, radius = radius)
                database.updateZone(updatedZone)
                zones = database.getAllZones()
                renderZones()
                updateSearchAdapter()
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
            updateSearchAdapter()
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