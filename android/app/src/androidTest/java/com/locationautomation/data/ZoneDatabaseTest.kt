package com.locationautomation.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

import org.junit.Assert.*

@RunWith(AndroidJUnit4::class)
class ZoneDatabaseTest {

    private lateinit var database: ZoneDatabase
    private lateinit var db: SQLiteDatabase

    @Before
    fun setUp() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = ZoneDatabase(context)
        db = database.writableDatabase
    }

    @After
    fun tearDown() {
        db.delete(ZoneDatabase.TABLE_ZONES, null, null)
        db.delete(ZoneDatabase.TABLE_PROFILES, null, null)
        database.close()
    }

    @Test
    fun saveZone_shouldSaveZoneSuccessfully() {
        val zone = Zone(
            id = "zone1",
            name = "Test Zone",
            latitude = 37.7749,
            longitude = -122.4194,
            radius = 100.0,
            detectionMethods = listOf("gps", "wifi"),
            profileId = "profile1"
        )

        database.saveZone(zone)
        val retrieved = database.getZone("zone1")

        assertNotNull(retrieved)
        assertEquals("zone1", retrieved?.id)
        assertEquals("Test Zone", retrieved?.name)
        assertEquals(37.7749, retrieved?.latitude, 0.001)
        assertEquals(-122.4194, retrieved?.longitude, 0.001)
        assertEquals(100.0, retrieved?.radius, 0.001)
        assertEquals(listOf("gps", "wifi"), retrieved?.detectionMethods)
        assertEquals("profile1", retrieved?.profileId)
    }

    @Test
    fun getAllZones_shouldReturnAllSavedZones() {
        val zone1 = Zone("zone1", "Zone 1", 37.0, -122.0, 50.0, listOf("gps"), "p1")
        val zone2 = Zone("zone2", "Zone 2", 38.0, -123.0, 75.0, listOf("wifi"), "p2")

        database.saveZone(zone1)
        database.saveZone(zone2)
        val zones = database.getAllZones()

        assertEquals(2, zones.size)
        assertTrue(zones.any { it.id == "zone1" })
        assertTrue(zones.any { it.id == "zone2" })
    }

    @Test
    fun deleteZone_shouldRemoveZone() {
        val zone = Zone("zone1", "Test Zone", 37.0, -122.0, 50.0, listOf("gps"), "p1")
        database.saveZone(zone)

        database.deleteZone("zone1")
        val retrieved = database.getZone("zone1")

        assertNull(retrieved)
    }

    @Test
    fun saveProfile_shouldSaveProfileSuccessfully() {
        val profile = Profile(
            id = "profile1",
            name = "Silent Mode",
            ringtoneEnabled = false,
            vibrateEnabled = true,
            unmuteEnabled = false,
            dndEnabled = true,
            alarmsEnabled = false,
            timersEnabled = false
        )

        database.saveProfile(profile)
        val retrieved = database.getProfile("profile1")

        assertNotNull(retrieved)
        assertEquals("profile1", retrieved?.id)
        assertEquals("Silent Mode", retrieved?.name)
        assertFalse(retrieved?.ringtoneEnabled ?: true)
        assertTrue(retrieved?.vibrateEnabled ?: false)
        assertFalse(retrieved?.unmuteEnabled ?: true)
        assertTrue(retrieved?.dndEnabled ?: false)
        assertFalse(retrieved?.alarmsEnabled ?: true)
        assertFalse(retrieved?.timersEnabled ?: true)
    }

    @Test
    fun getAllProfiles_shouldReturnAllSavedProfiles() {
        val profile1 = Profile("profile1", "Profile 1")
        val profile2 = Profile("profile2", "Profile 2", ringtoneEnabled = false)

        database.saveProfile(profile1)
        database.saveProfile(profile2)
        val profiles = database.getAllProfiles()

        assertEquals(2, profiles.size)
    }

    @Test
    fun deleteProfile_shouldRemoveProfile() {
        val profile = Profile("profile1", "Test Profile")
        database.saveProfile(profile)

        database.deleteProfile("profile1")
        val retrieved = database.getProfile("profile1")

        assertNull(retrieved)
    }

    @Test
    fun saveZone_withEmptyDetectionMethods_shouldHandleCorrectly() {
        val zone = Zone("zone1", "Zone", 37.0, -122.0, 50.0, emptyList(), "p1")

        database.saveZone(zone)
        val retrieved = database.getZone("zone1")

        assertNotNull(retrieved)
        assertTrue(retrieved?.detectionMethods?.isEmpty() ?: false)
    }

    @Test
    fun getProfile_withDefaultValues_shouldReturnDefaults() {
        val profile = Profile("profile1", "Default Profile")

        database.saveProfile(profile)
        val retrieved = database.getProfile("profile1")

        assertNotNull(retrieved)
        assertTrue(retrieved?.ringtoneEnabled ?: false)
        assertTrue(retrieved?.vibrateEnabled ?: false)
        assertFalse(retrieved?.unmuteEnabled ?: true)
        assertFalse(retrieved?.dndEnabled ?: true)
        assertTrue(retrieved?.alarmsEnabled ?: false)
        assertTrue(retrieved?.timersEnabled ?: false)
    }

    @Test
    fun saveZone_updateExisting_shouldReplace() {
        val zone1 = Zone("zone1", "Original", 37.0, -122.0, 50.0, listOf("gps"), "p1")
        val zoneUpdated = Zone("zone1", "Updated", 38.0, -123.0, 100.0, listOf("wifi"), "p2")

        database.saveZone(zone1)
        database.saveZone(zoneUpdated)
        val zones = database.getAllZones()

        assertEquals(1, zones.size)
        assertEquals("Updated", zones[0].name)
    }

    @Test
    fun saveProfile_updateExisting_shouldReplace() {
        val profile1 = Profile("profile1", "Original")
        val profileUpdated = Profile("profile1", "Updated", ringtoneEnabled = false)

        database.saveProfile(profile1)
        database.saveProfile(profileUpdated)
        val profiles = database.getAllProfiles()

        assertEquals(1, profiles.size)
        assertEquals("Updated", profiles[0].name)
        assertFalse(profiles[0].ringtoneEnabled)
    }
}
