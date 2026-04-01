package com.locationautomation.data

import org.junit.Test
import org.junit.Assert.*

class ZoneTest {

    @Test
    fun zone_constructor_shouldCreateZoneWithAllProperties() {
        val zone = Zone(
            id = "zone1",
            name = "Home",
            latitude = 37.7749,
            longitude = -122.4194,
            radius = 100.0,
            detectionMethods = listOf("gps", "wifi"),
            profileId = "profile1"
        )

        assertEquals("zone1", zone.id)
        assertEquals("Home", zone.name)
        assertEquals(37.7749, zone.latitude, 0.0001)
        assertEquals(-122.4194, zone.longitude, 0.0001)
        assertEquals(100.0, zone.radius, 0.0001)
        assertEquals(listOf("gps", "wifi"), zone.detectionMethods)
        assertEquals("profile1", zone.profileId)
    }

    @Test
    fun zone_equals_shouldMatchEqualZones() {
        val zone1 = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")
        val zone2 = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")

        assertEquals(zone1, zone2)
    }

    @Test
    fun zone_notEquals_shouldDifferById() {
        val zone1 = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")
        val zone2 = Zone("zone2", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")

        assertNotEquals(zone1, zone2)
    }

    @Test
    fun zone_notEquals_shouldDifferByName() {
        val zone1 = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")
        val zone2 = Zone("zone1", "Work", 37.0, -122.0, 100.0, listOf("gps"), "p1")

        assertNotEquals(zone1, zone2)
    }

    @Test
    fun zone_hashCode_shouldBeEqualForEqualZones() {
        val zone1 = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")
        val zone2 = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")

        assertEquals(zone1.hashCode(), zone2.hashCode())
    }

    @Test
    fun zone_toString_shouldContainAllProperties() {
        val zone = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")
        val stringRepresentation = zone.toString()

        assertTrue(stringRepresentation.contains("zone1"))
        assertTrue(stringRepresentation.contains("Home"))
        assertTrue(stringRepresentation.contains("37.0"))
        assertTrue(stringRepresentation.contains("-122.0"))
    }

    @Test
    fun zone_copy_shouldCreateCopyWithModifiedProperties() {
        val original = Zone("zone1", "Home", 37.0, -122.0, 100.0, listOf("gps"), "p1")
        val copied = original.copy(name = "Work")

        assertEquals("zone1", copied.id)
        assertEquals("Work", copied.name)
        assertEquals(37.0, copied.latitude, 0.0001)
        assertEquals(-122.0, copied.longitude, 0.0001)
        assertEquals(100.0, copied.radius, 0.0001)
    }

    @Test
    fun zone_withEmptyDetectionMethods_shouldWork() {
        val zone = Zone("zone1", "Test", 37.0, -122.0, 50.0, emptyList(), "p1")

        assertTrue(zone.detectionMethods.isEmpty())
    }

    @Test
    fun zone_withMultipleDetectionMethods_shouldStoreAll() {
        val methods = listOf("gps", "wifi", "bluetooth", "cell")
        val zone = Zone("zone1", "Test", 37.0, -122.0, 50.0, methods, "p1")

        assertEquals(4, zone.detectionMethods.size)
        assertTrue(zone.detectionMethods.containsAll(methods))
    }

    @Test
    fun zone_negativeRadius_shouldBeAllowed() {
        val zone = Zone("zone1", "Test", 37.0, -122.0, -50.0, listOf("gps"), "p1")

        assertEquals(-50.0, zone.radius, 0.0001)
    }

    @Test
    fun zone_zeroCoordinates_shouldBeAllowed() {
        val zone = Zone("zone1", "Origin", 0.0, 0.0, 100.0, listOf("gps"), "p1")

        assertEquals(0.0, zone.latitude, 0.0001)
        assertEquals(0.0, zone.longitude, 0.0001)
    }
}
