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
        const val EXTRA_DEBUG_ZONE_INDEX = "debug_zone_index"
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
    }

    private lateinit var locationManager: android.location.LocationManager
    private lateinit var database: ZoneDatabase
    private lateinit var audioManager: AudioManager
    private var currentZone: Zone? = null
    private var currentProfile: Profile? = null
    private var zoneEntryTime: Long = 0
    private var isInitialized: Boolean = false
    
    private var savedRingerMode: Int = AudioManager.RINGER_MODE_NORMAL
    private var savedInterruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL
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
        database = ZoneDatabase(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForegroundService()
            ACTION_STOP -> stopSelf()
            ACTION_DEBUG_TRIGGER -> {
                val zoneIndex = intent.getIntExtra(EXTRA_DEBUG_ZONE_INDEX, -1)
                if (zoneIndex >= 0) {
                    triggerDebugZone(zoneIndex)
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
        applyProfile(profile)
        currentProfile = profile
        sendZoneNotification(targetZone.name)
        updateNotification("Zone: ${targetZone.name}", "Profile: ${profile?.name ?: "Normal"}")
        broadcastStateChanged(targetZone.name, profile?.name ?: "Normal")
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
                applyProfile(profile)
                currentProfile = profile
                zoneEntryTime = System.currentTimeMillis()
                sendZoneNotification(insideZone.name)
                updateNotification("Zone: ${insideZone.name}", "Profile: ${profile?.name ?: "Normal"}")
                broadcastStateChanged(insideZone.name, profile?.name ?: "Normal")
                SoundManager.playSound(this, R.raw.error_bleep_1)
                android.util.Log.d("LocationService", "Entered zone: ${insideZone.name}")
            } else if (previousZone != null) {
                database.logZoneSession(previousZone.name, zoneEntryTime, System.currentTimeMillis())
                restoreNormalMode()
                cancelZoneNotification()
                zoneEntryTime = 0
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

    private fun restoreNormalMode() {
        try {
            audioManager.ringerMode = if (stateCaptured) savedRingerMode else AudioManager.RINGER_MODE_NORMAL
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore ringer mode", e)
        }

        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.isNotificationPolicyAccessGranted) {
                val filter = if (stateCaptured) savedInterruptionFilter else NotificationManager.INTERRUPTION_FILTER_ALL
                notificationManager.setInterruptionFilter(filter)
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Failed to restore DND", e)
        }

        savedRingerMode = AudioManager.RINGER_MODE_NORMAL
        savedInterruptionFilter = NotificationManager.INTERRUPTION_FILTER_ALL
        stateCaptured = false
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
    }
}
