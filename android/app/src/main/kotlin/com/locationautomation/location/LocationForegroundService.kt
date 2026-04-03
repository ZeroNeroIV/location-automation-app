package com.locationautomation.location

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.locationautomation.MainActivity
import com.locationautomation.R
import com.locationautomation.data.Profile
import com.locationautomation.data.Zone
import com.locationautomation.data.ZoneDatabase
import com.locationautomation.util.SoundManager

class LocationForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "location_service_channel"
        const val NOTIFICATION_ID = 1001
        const val ZONE_NOTIFICATION_ID = 2001
        const val ACTION_START = "com.locationautomation.action.START_SERVICE"
        const val ACTION_STOP = "com.locationautomation.action.STOP_SERVICE"
        const val ACTION_DEBUG_TRIGGER = "com.locationautomation.action.DEBUG_TRIGGER"
        const val ACTION_RESTORE_NORMAL = "com.locationautomation.action.RESTORE_NORMAL"
        const val EXTRA_DEBUG_ZONE_INDEX = "debug_zone_index"
        const val EXTRA_DEBUG_ZONE_ID = "debug_zone_id"
        const val BROADCAST_STATE_CHANGED = "com.locationautomation.STATE_CHANGED"
        const val EXTRA_ZONE_NAME = "zone_name"
        const val EXTRA_PROFILE_NAME = "profile_name"
        const val EXTRA_TIMESTAMP = "timestamp"

        @JvmStatic
        fun start(context: Context) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_START
            }
            context.startForegroundService(intent)
        }

        @JvmStatic
        fun stop(context: Context) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        @JvmStatic
        fun debugTrigger(context: Context, zoneIndex: Int) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_DEBUG_TRIGGER
                putExtra(EXTRA_DEBUG_ZONE_INDEX, zoneIndex)
            }
            context.startService(intent)
        }

        @JvmStatic
        fun triggerZone(context: Context, zoneId: String) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_DEBUG_TRIGGER
                putExtra(EXTRA_DEBUG_ZONE_ID, zoneId)
            }
            context.startService(intent)
        }

        @JvmStatic
        fun triggerNormalProfile(context: Context) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_RESTORE_NORMAL
            }
            context.startService(intent)
        }
    }

private lateinit var locationManager: android.location.LocationManager
        private lateinit var database: ZoneDatabase
        private lateinit var audioManager: AudioManager
        private lateinit var vibrator: Vibrator
    private var currentZone: Zone? = null
    private var currentProfile: Profile? = null
    private var zoneEntryTime: Long = 0
    private var isInitialized: Boolean = false
    
    private var savedRingerMode: Int = AudioManager.RINGER_MODE_NORMAL
    private var savedInterruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL
    private var savedWifiEnabled: Boolean = true
    private var savedBluetoothEnabled: Boolean = true
    private var savedMobileDataEnabled: Boolean = true
    private var stateCaptured: Boolean = false

    private val locationCallback = object : android.location.LocationListener {
        override fun onLocationChanged(location: android.location.Location) {
            checkZones(location.latitude, location.longitude)
        }

        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        database = ZoneDatabase(this)
        createNotificationChannel()
    }

    private fun vibrateEntry() {
        if (vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                //noinspection deprecation
                vibrator.vibrate(50)
            }
        }
    }

    private fun vibrateExit() {
        if (vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
                Handler(Looper.getMainLooper()).postDelayed({
                    vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
                }, 150)
            } else {
                //noinspection deprecation
                vibrator.vibrate(100)
                Handler(Looper.getMainLooper()).postDelayed({
                    //noinspection deprecation
                    vibrator.vibrate(100)
                }, 150)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForegroundService()
            ACTION_STOP -> stopSelf()
            ACTION_RESTORE_NORMAL -> restoreNormalMode()
            ACTION_DEBUG_TRIGGER -> {
                val zoneId = intent.getStringExtra(EXTRA_DEBUG_ZONE_ID)
                if (zoneId != null) {
                    triggerZoneById(zoneId)
                } else {
                    val zoneIndex = intent.getIntExtra(EXTRA_DEBUG_ZONE_INDEX, -1)
                    if (zoneIndex >= 0) {
                        triggerDebugZone(zoneIndex)
                    }
                }
            }
        }
        return START_STICKY
    }

    private fun triggerDebugZone(index: Int) {
        val zones = try {
            database.getAllZones()
        } catch (e: Exception) {
            return
        }

        if (index >= zones.size) return

        val targetZone = zones[index]
        val previousZone = currentZone
        currentZone = targetZone
        zoneEntryTime = System.currentTimeMillis()

        val profile = try {
            database.getProfile(targetZone.profileId)
        } catch (e: Exception) {
            null
        }
        captureConnectivityState()
        applyProfile(profile)
        if (profile != null) applyConnectivity(profile)
        currentProfile = profile
        sendZoneNotification(targetZone.name)
        updateNotification("Zone: ${targetZone.name}", "Profile: ${profile?.name ?: "Normal"}")
        broadcastStateChanged(targetZone.name, profile?.name ?: "Normal")
    }

    private fun triggerZoneById(zoneId: String) {
        val targetZone = try {
            database.getZone(zoneId)
        } catch (e: Exception) {
            return
        }

        if (targetZone == null) return

        currentZone = targetZone
        zoneEntryTime = System.currentTimeMillis()

        val profile = try {
            database.getProfile(targetZone.profileId)
        } catch (e: Exception) {
            null
        }
        captureConnectivityState()
        applyProfile(profile)
        if (profile != null) applyConnectivity(profile)
        currentProfile = profile
        sendZoneNotification(targetZone.name)
        updateNotification("Zone: ${targetZone.name}", "Profile: ${profile?.name ?: "Normal"}")
        broadcastStateChanged(targetZone.name, profile?.name ?: "Normal")
        
        // Vibrate on zone entry
        vibrateEntry()
    }

    private fun startForegroundService() {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Tracking Active")
            .setContentText("Monitoring your location for automation rules")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        startLocationUpdates()
    }

    private fun startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            stopSelf()
            return
        }

        try {
            locationManager.requestLocationUpdates(
                android.location.LocationManager.GPS_PROVIDER,
                30000L,
                50f,
                locationCallback,
                Looper.getMainLooper()
            )
            locationManager.requestLocationUpdates(
                android.location.LocationManager.NETWORK_PROVIDER,
                30000L,
                50f,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to request location updates", e)
        }
    }

    private fun stopLocationUpdates() {
        try {
            locationManager.removeUpdates(locationCallback)
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to remove location updates", e)
        }
    }

    private fun checkZones(latitude: Double, longitude: Double) {
        val zones = try {
            database.getAllZones()
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to load zones", e)
            return
        }

        val insideZone = zones.find { zone ->
            calculateDistance(latitude, longitude, zone.latitude, zone.longitude) <= zone.radius
        }

        if (!isInitialized) {
            currentZone = insideZone
            isInitialized = true
            android.util.Log.d("LocationService", "Initialized in zone: ${insideZone?.name ?: "none"}")
            return
        }

        if (insideZone != currentZone) {
            val previousZone = currentZone
            currentZone = insideZone

            if (insideZone != null) {
                val profile = try {
                    database.getProfile(insideZone.profileId)
                } catch (e: Exception) {
                    android.util.Log.e("LocationService", "Failed to load profile", e)
                    return
                }
                captureConnectivityState()
                applyProfile(profile)
                profile?.let { applyConnectivity(it) }
                currentProfile = profile
                zoneEntryTime = System.currentTimeMillis()
                sendZoneNotification(insideZone.name)
                updateNotification("Zone: ${insideZone.name}", "Profile: ${profile?.name ?: "Normal"}")
                broadcastStateChanged(insideZone.name, profile?.name ?: "Normal")
                SoundManager.playSound(this, R.raw.error_bleep_1)
                vibrateEntry()
                android.util.Log.d("LocationService", "Entered zone: ${insideZone.name}")
            } else if (previousZone != null) {
                database.logZoneSession(previousZone.name, zoneEntryTime, System.currentTimeMillis())
                // Vibrate on zone exit
                vibrateExit()
                restoreNormalMode()
                sendLeaveNotification(previousZone.name)
                zoneEntryTime = 0
                getSharedPreferences("automation_state", Context.MODE_PRIVATE).edit().remove("zone_entry_time").apply()
                updateNotification("Location Tracking Active", "Left zone: ${previousZone.name}")
                broadcastStateChanged("", "")
                SoundManager.playSound(this, R.raw.error_bleep_2)
                android.util.Log.d("LocationService", "Exited zone: ${previousZone.name}")
            }
        }
    }

    private fun calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val results = FloatArray(1)
        android.location.Location.distanceBetween(lat1, lon1, lat2, lon2, results)
        return results[0].toDouble()
    }

    private fun applyProfile(profile: Profile?) {
        if (!stateCaptured) {
            savedRingerMode = audioManager.ringerMode
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                savedInterruptionFilter = notificationManager.currentInterruptionFilter
            } catch (e: Exception) {
                android.util.Log.e("LocationService", "Failed to capture interruption filter", e)
            }
            stateCaptured = true
            android.util.Log.d("LocationService", "State captured: ringer=$savedRingerMode, dnd=$savedInterruptionFilter")
        }

        if (profile == null) {
            restoreNormalMode()
            return
        }

        when {
            profile.dndEnabled -> {
                try {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("LocationService", "Failed to set DND", e)
                }
            }
            else -> {
                try {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("LocationService", "Failed to disable DND", e)
                }
            }
        }

        val ringerMode = when {
            profile.dndEnabled -> AudioManager.RINGER_MODE_SILENT
            profile.ringtoneEnabled -> AudioManager.RINGER_MODE_NORMAL
            profile.vibrateEnabled -> AudioManager.RINGER_MODE_VIBRATE
            else -> AudioManager.RINGER_MODE_SILENT
        }

        try {
            audioManager.ringerMode = ringerMode
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to set ringer mode", e)
        }
    }

    private fun captureConnectivityState() {
        try {
            val wifiManager = getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            savedWifiEnabled = wifiManager.isWifiEnabled
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to capture WiFi state", e)
        }

        try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            savedBluetoothEnabled = bluetoothAdapter?.isEnabled ?: false
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to capture Bluetooth state", e)
        }

        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
            savedMobileDataEnabled = connectivityManager.isActiveNetworkMetered
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to capture mobile data state", e)
        }

        android.util.Log.d("LocationService", "Connectivity state captured: wifi=$savedWifiEnabled, bt=$savedBluetoothEnabled, mobileData=$savedMobileDataEnabled")
    }

    private fun applyConnectivity(profile: Profile) {
        try {
            val wifiManager = getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            if (wifiManager.isWifiEnabled != profile.wifiEnabled) {
                wifiManager.isWifiEnabled = profile.wifiEnabled
                android.util.Log.d("LocationService", "WiFi ${if (profile.wifiEnabled) "enabled" else "disabled"}")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to toggle WiFi", e)
        }

        try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter != null) {
                when {
                    profile.bluetoothEnabled && !bluetoothAdapter.isEnabled -> {
                        bluetoothAdapter.enable()
                        android.util.Log.d("LocationService", "Bluetooth enabled")
                    }
                    !profile.bluetoothEnabled && bluetoothAdapter.isEnabled -> {
                        bluetoothAdapter.disable()
                        android.util.Log.d("LocationService", "Bluetooth disabled")
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to toggle Bluetooth", e)
        }

        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
            val method = connectivityManager::class.java.getDeclaredMethod(
                "setMobileDataEnabled",
                Boolean::class.javaPrimitiveType
            )
            method.isAccessible = true
            method.invoke(connectivityManager, profile.mobileDataEnabled)
            android.util.Log.d("LocationService", "Mobile data ${if (profile.mobileDataEnabled) "enabled" else "disabled"}")
        } catch (e: NoSuchMethodException) {
            android.util.Log.w("LocationService", "Mobile data toggle not available on Android 5.0+ (reflection failed)")
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to toggle mobile data", e)
        }
    }

    private fun restoreConnectivity() {
        try {
            val wifiManager = getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            if (wifiManager.isWifiEnabled != savedWifiEnabled) {
                wifiManager.isWifiEnabled = savedWifiEnabled
                android.util.Log.d("LocationService", "WiFi restored to $savedWifiEnabled")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore WiFi", e)
        }

        try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter != null) {
                when {
                    savedBluetoothEnabled && !bluetoothAdapter.isEnabled -> {
                        bluetoothAdapter.enable()
                        android.util.Log.d("LocationService", "Bluetooth restored to enabled")
                    }
                    !savedBluetoothEnabled && bluetoothAdapter.isEnabled -> {
                        bluetoothAdapter.disable()
                        android.util.Log.d("LocationService", "Bluetooth restored to disabled")
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore Bluetooth", e)
        }

        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
            val method = connectivityManager::class.java.getDeclaredMethod(
                "setMobileDataEnabled",
                Boolean::class.javaPrimitiveType
            )
            method.isAccessible = true
            method.invoke(connectivityManager, savedMobileDataEnabled)
            android.util.Log.d("LocationService", "Mobile data restored to $savedMobileDataEnabled")
        } catch (e: NoSuchMethodException) {
            android.util.Log.w("LocationService", "Mobile data restore not available on Android 5.0+")
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore mobile data", e)
        }
    }

    private fun restoreNormalMode() {
        val prefs = getSharedPreferences("default_phone_state", Context.MODE_PRIVATE)
        
        val defaultRingtone = prefs.getBoolean("default_ringtone", true)
        val defaultVibrate = prefs.getBoolean("default_vibrate", true)
        val defaultDnd = prefs.getBoolean("default_dnd", false)
        val defaultWifi = prefs.getBoolean("default_wifi", true)
        val defaultBluetooth = prefs.getBoolean("default_bluetooth", true)
        val defaultMobileData = prefs.getBoolean("default_mobile_data", true)
        
        // Apply DND
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.isNotificationPolicyAccessGranted) {
                notificationManager.setInterruptionFilter(
                    if (defaultDnd) NotificationManager.INTERRUPTION_FILTER_NONE
                    else NotificationManager.INTERRUPTION_FILTER_ALL
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to set DND on restore", e)
        }
        
        // Apply ringer mode
        val ringerMode = when {
            defaultDnd -> AudioManager.RINGER_MODE_SILENT
            defaultRingtone -> AudioManager.RINGER_MODE_NORMAL
            defaultVibrate -> AudioManager.RINGER_MODE_VIBRATE
            else -> AudioManager.RINGER_MODE_SILENT
        }
        try {
            audioManager.ringerMode = ringerMode
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore ringer mode", e)
        }
        
        // Apply connectivity defaults
        try {
            val wifiManager = getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            if (wifiManager.isWifiEnabled != defaultWifi) {
                wifiManager.isWifiEnabled = defaultWifi
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore WiFi", e)
        }
        
        try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter != null) {
                when {
                    defaultBluetooth && !bluetoothAdapter.isEnabled -> bluetoothAdapter.enable()
                    !defaultBluetooth && bluetoothAdapter.isEnabled -> bluetoothAdapter.disable()
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore Bluetooth", e)
        }
        
        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
            val method = connectivityManager::class.java.getDeclaredMethod(
                "setMobileDataEnabled",
                Boolean::class.javaPrimitiveType
            )
            method.isAccessible = true
            method.invoke(connectivityManager, defaultMobileData)
        } catch (e: NoSuchMethodException) {
            android.util.Log.w("LocationService", "Mobile data toggle not available on Android 5.0+")
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore mobile data", e)
        }
        
        android.util.Log.d("LocationService", "Restored default state: ringtone=$defaultRingtone, vibrate=$defaultVibrate, dnd=$defaultDnd, wifi=$defaultWifi, bt=$defaultBluetooth, mobileData=$defaultMobileData")
    }

    fun updateNotification(title: String, text: String) {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun sendZoneNotification(zoneName: String) {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Welcome to $zoneName")
            .setContentText("Profile activated")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(ZONE_NOTIFICATION_ID, notification)
    }

    private fun sendLeaveNotification(zoneName: String) {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Leaving $zoneName")
            .setContentText("Bye! Profile deactivated")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(ZONE_NOTIFICATION_ID, notification)
    }

    private fun cancelZoneNotification() {
        NotificationManagerCompat.from(this).cancel(ZONE_NOTIFICATION_ID)
    }

    private fun broadcastStateChanged(zoneName: String, profileName: String) {
        val prefs = getSharedPreferences("automation_state", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("current_zone", zoneName)
            putString("current_profile", profileName)
            putLong("zone_entry_time", zoneEntryTime)
            apply()
        }

        val intent = Intent(BROADCAST_STATE_CHANGED)
        sendBroadcast(intent)
    }

    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifications for location tracking service"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        val zone = currentZone
        if (zone != null && zoneEntryTime > 0) {
            database.logZoneSession(zone.name, zoneEntryTime, System.currentTimeMillis())
        }
        stopLocationUpdates()
        restoreNormalMode()
        getSharedPreferences("automation_state", Context.MODE_PRIVATE).edit().apply {
            remove("current_zone")
            remove("current_profile")
            remove("zone_entry_time")
            apply()
        }
    }
}
