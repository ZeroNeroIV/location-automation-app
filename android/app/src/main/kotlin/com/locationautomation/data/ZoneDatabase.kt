package com.locationautomation.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class ZoneDatabase(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "location_automation.db"
        private const val DATABASE_VERSION = 2
        
        private const val TABLE_ZONES = "zones"
        private const val TABLE_PROFILES = "profiles"
        private const val TABLE_ZONE_TIME_LOG = "zone_time_log"
        private const val COLUMN_ID = "id"
        private const val COLUMN_NAME = "name"
        private const val COLUMN_LATITUDE = "latitude"
        private const val COLUMN_LONGITUDE = "longitude"
        private const val COLUMN_RADIUS = "radius"
        private const val COLUMN_DETECTION_METHODS = "detection_methods"
        private const val COLUMN_PROFILE_ID = "profile_id"
        
        // Profile columns
        private const val COLUMN_RINGTONE_ENABLED = "ringtone_enabled"
        private const val COLUMN_VIBRATE_ENABLED = "vibrate_enabled"
        private const val COLUMN_UNMUTE_ENABLED = "unmute_enabled"
        private const val COLUMN_DND_ENABLED = "dnd_enabled"
        private const val COLUMN_ALARMS_ENABLED = "alarms_enabled"
        private const val COLUMN_TIMERS_ENABLED = "timers_enabled"
        
        // Zone time log columns
        private const val COLUMN_ZONE_NAME = "zone_name"
        private const val COLUMN_ENTRY_TIME = "entry_time"
        private const val COLUMN_EXIT_TIME = "exit_time"
        private const val COLUMN_DURATION_SECONDS = "duration_seconds"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createZonesTable = """
            CREATE TABLE $TABLE_ZONES (
                $COLUMN_ID TEXT PRIMARY KEY,
                $COLUMN_NAME TEXT NOT NULL,
                $COLUMN_LATITUDE REAL NOT NULL,
                $COLUMN_LONGITUDE REAL NOT NULL,
                $COLUMN_RADIUS REAL NOT NULL,
                $COLUMN_DETECTION_METHODS TEXT NOT NULL,
                $COLUMN_PROFILE_ID TEXT NOT NULL
            )
        """.trimIndent()
        db.execSQL(createZonesTable)
        
        val createProfilesTable = """
            CREATE TABLE $TABLE_PROFILES (
                $COLUMN_ID TEXT PRIMARY KEY,
                $COLUMN_NAME TEXT NOT NULL,
                $COLUMN_RINGTONE_ENABLED INTEGER NOT NULL DEFAULT 1,
                $COLUMN_VIBRATE_ENABLED INTEGER NOT NULL DEFAULT 1,
                $COLUMN_UNMUTE_ENABLED INTEGER NOT NULL DEFAULT 0,
                $COLUMN_DND_ENABLED INTEGER NOT NULL DEFAULT 0,
                $COLUMN_ALARMS_ENABLED INTEGER NOT NULL DEFAULT 1,
                $COLUMN_TIMERS_ENABLED INTEGER NOT NULL DEFAULT 1
            )
        """.trimIndent()
        db.execSQL(createProfilesTable)

        val createTimeLogTable = """
            CREATE TABLE $TABLE_ZONE_TIME_LOG (
                $COLUMN_ID TEXT PRIMARY KEY,
                $COLUMN_ZONE_NAME TEXT NOT NULL,
                $COLUMN_ENTRY_TIME INTEGER NOT NULL,
                $COLUMN_EXIT_TIME INTEGER NOT NULL,
                $COLUMN_DURATION_SECONDS INTEGER NOT NULL
            )
        """.trimIndent()
        db.execSQL(createTimeLogTable)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS $TABLE_ZONE_TIME_LOG (
                    $COLUMN_ID TEXT PRIMARY KEY,
                    $COLUMN_ZONE_NAME TEXT NOT NULL,
                    $COLUMN_ENTRY_TIME INTEGER NOT NULL,
                    $COLUMN_EXIT_TIME INTEGER NOT NULL,
                    $COLUMN_DURATION_SECONDS INTEGER NOT NULL
                )
            """.trimIndent())
        }
    }

    fun saveZone(zone: Zone) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_ID, zone.id)
            put(COLUMN_NAME, zone.name)
            put(COLUMN_LATITUDE, zone.latitude)
            put(COLUMN_LONGITUDE, zone.longitude)
            put(COLUMN_RADIUS, zone.radius)
            put(COLUMN_DETECTION_METHODS, zone.detectionMethods.joinToString(","))
            put(COLUMN_PROFILE_ID, zone.profileId)
        }
        db.insertWithOnConflict(TABLE_ZONES, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllZones(): List<Zone> {
        val zones = mutableListOf<Zone>()
        val db = readableDatabase
        val cursor = db.query(TABLE_ZONES, null, null, null, null, null, null)
        
        cursor.use {
            while (it.moveToNext()) {
                val zone = Zone(
                    id = it.getString(it.getColumnIndexOrThrow(COLUMN_ID)),
                    name = it.getString(it.getColumnIndexOrThrow(COLUMN_NAME)),
                    latitude = it.getDouble(it.getColumnIndexOrThrow(COLUMN_LATITUDE)),
                    longitude = it.getDouble(it.getColumnIndexOrThrow(COLUMN_LONGITUDE)),
                    radius = it.getDouble(it.getColumnIndexOrThrow(COLUMN_RADIUS)),
                    detectionMethods = it.getString(it.getColumnIndexOrThrow(COLUMN_DETECTION_METHODS))
                        .split(",")
                        .filter { it.isNotEmpty() },
                    profileId = it.getString(it.getColumnIndexOrThrow(COLUMN_PROFILE_ID))
                )
                zones.add(zone)
            }
        }
        return zones
    }

    fun getZone(id: String): Zone? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_ZONES,
            null,
            "$COLUMN_ID = ?",
            arrayOf(id),
            null, null, null
        )
        
        cursor.use {
            if (it.moveToFirst()) {
                return Zone(
                    id = it.getString(it.getColumnIndexOrThrow(COLUMN_ID)),
                    name = it.getString(it.getColumnIndexOrThrow(COLUMN_NAME)),
                    latitude = it.getDouble(it.getColumnIndexOrThrow(COLUMN_LATITUDE)),
                    longitude = it.getDouble(it.getColumnIndexOrThrow(COLUMN_LONGITUDE)),
                    radius = it.getDouble(it.getColumnIndexOrThrow(COLUMN_RADIUS)),
                    detectionMethods = it.getString(it.getColumnIndexOrThrow(COLUMN_DETECTION_METHODS))
                        .split(",")
                        .filter { s -> s.isNotEmpty() },
                    profileId = it.getString(it.getColumnIndexOrThrow(COLUMN_PROFILE_ID))
                )
            }
        }
        return null
    }

    fun deleteZone(id: String) {
        val db = writableDatabase
        db.delete(TABLE_ZONES, "$COLUMN_ID = ?", arrayOf(id))
    }

    fun updateZone(zone: Zone) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_NAME, zone.name)
            put(COLUMN_LATITUDE, zone.latitude)
            put(COLUMN_LONGITUDE, zone.longitude)
            put(COLUMN_RADIUS, zone.radius)
            put(COLUMN_DETECTION_METHODS, zone.detectionMethods.joinToString(","))
            put(COLUMN_PROFILE_ID, zone.profileId)
        }
        db.update(TABLE_ZONES, values, "$COLUMN_ID = ?", arrayOf(zone.id))
    }

    fun saveProfile(profile: Profile) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_ID, profile.id)
            put(COLUMN_NAME, profile.name)
            put(COLUMN_RINGTONE_ENABLED, if (profile.ringtoneEnabled) 1 else 0)
            put(COLUMN_VIBRATE_ENABLED, if (profile.vibrateEnabled) 1 else 0)
            put(COLUMN_UNMUTE_ENABLED, if (profile.unmuteEnabled) 1 else 0)
            put(COLUMN_DND_ENABLED, if (profile.dndEnabled) 1 else 0)
            put(COLUMN_ALARMS_ENABLED, if (profile.alarmsEnabled) 1 else 0)
            put(COLUMN_TIMERS_ENABLED, if (profile.timersEnabled) 1 else 0)
        }
        db.insertWithOnConflict(TABLE_PROFILES, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getProfile(id: String): Profile? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_PROFILES,
            null,
            "$COLUMN_ID = ?",
            arrayOf(id),
            null, null, null
        )
        
        cursor.use {
            if (it.moveToFirst()) {
                return Profile(
                    id = it.getString(it.getColumnIndexOrThrow(COLUMN_ID)),
                    name = it.getString(it.getColumnIndexOrThrow(COLUMN_NAME)),
                    ringtoneEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_RINGTONE_ENABLED)) == 1,
                    vibrateEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_VIBRATE_ENABLED)) == 1,
                    unmuteEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_UNMUTE_ENABLED)) == 1,
                    dndEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_DND_ENABLED)) == 1,
                    alarmsEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_ALARMS_ENABLED)) == 1,
                    timersEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_TIMERS_ENABLED)) == 1
                )
            }
        }
        return null
    }

    fun getAllProfiles(): List<Profile> {
        val profiles = mutableListOf<Profile>()
        val db = readableDatabase
        val cursor = db.query(TABLE_PROFILES, null, null, null, null, null, null)
        
        cursor.use {
            while (it.moveToNext()) {
                val profile = Profile(
                    id = it.getString(it.getColumnIndexOrThrow(COLUMN_ID)),
                    name = it.getString(it.getColumnIndexOrThrow(COLUMN_NAME)),
                    ringtoneEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_RINGTONE_ENABLED)) == 1,
                    vibrateEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_VIBRATE_ENABLED)) == 1,
                    unmuteEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_UNMUTE_ENABLED)) == 1,
                    dndEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_DND_ENABLED)) == 1,
                    alarmsEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_ALARMS_ENABLED)) == 1,
                    timersEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_TIMERS_ENABLED)) == 1
                )
                profiles.add(profile)
            }
        }
        return profiles
    }

    fun deleteProfile(id: String) {
        val db = writableDatabase
        db.delete(TABLE_PROFILES, "$COLUMN_ID = ?", arrayOf(id))
    }

    fun logZoneSession(zoneName: String, entryTime: Long, exitTime: Long) {
        val duration = (exitTime - entryTime) / 1000
        if (duration <= 0 || zoneName.isEmpty()) return
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_ID, java.util.UUID.randomUUID().toString())
            put(COLUMN_ZONE_NAME, zoneName)
            put(COLUMN_ENTRY_TIME, entryTime)
            put(COLUMN_EXIT_TIME, exitTime)
            put(COLUMN_DURATION_SECONDS, duration)
        }
        db.insert(TABLE_ZONE_TIME_LOG, null, values)
    }

    data class ZoneTimeBucket(
        val zoneName: String,
        val totalSeconds: Long
    )

    fun getDailyZoneTime(): List<ZoneTimeBucket> {
        val todayStart = getDayStartMillis(System.currentTimeMillis())
        val tomorrowStart = todayStart + 86400000L
        return aggregateZoneTime(todayStart, tomorrowStart)
    }

    fun getWeeklyZoneTime(): List<ZoneTimeBucket> {
        val cal = java.util.Calendar.getInstance()
        cal.firstDayOfWeek = java.util.Calendar.SATURDAY
        cal.timeInMillis = System.currentTimeMillis()
        cal.set(java.util.Calendar.DAY_OF_WEEK, java.util.Calendar.SATURDAY)
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        val weekStart = cal.timeInMillis
        val weekEnd = weekStart + 7L * 86400000L
        return aggregateZoneTime(weekStart, weekEnd)
    }

    private fun aggregateZoneTime(startMillis: Long, endMillis: Long): List<ZoneTimeBucket> {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT $COLUMN_ZONE_NAME, SUM($COLUMN_DURATION_SECONDS) as total " +
            "FROM $TABLE_ZONE_TIME_LOG " +
            "WHERE $COLUMN_ENTRY_TIME >= ? AND $COLUMN_ENTRY_TIME < ? " +
            "GROUP BY $COLUMN_ZONE_NAME " +
            "ORDER BY total DESC",
            arrayOf(startMillis.toString(), endMillis.toString())
        )
        val result = mutableListOf<ZoneTimeBucket>()
        cursor.use {
            while (it.moveToNext()) {
                result.add(ZoneTimeBucket(
                    zoneName = it.getString(0),
                    totalSeconds = it.getLong(1)
                ))
            }
        }
        return result
    }

    private fun getDayStartMillis(timestamp: Long): Long {
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = timestamp
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}