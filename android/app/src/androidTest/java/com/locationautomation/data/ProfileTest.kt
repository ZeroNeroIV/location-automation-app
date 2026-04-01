package com.locationautomation.data

import org.junit.Test
import org.junit.Assert.*

class ProfileTest {

    @Test
    fun profile_constructor_shouldCreateProfileWithAllProperties() {
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

        assertEquals("profile1", profile.id)
        assertEquals("Silent Mode", profile.name)
        assertFalse(profile.ringtoneEnabled)
        assertTrue(profile.vibrateEnabled)
        assertFalse(profile.unmuteEnabled)
        assertTrue(profile.dndEnabled)
        assertFalse(profile.alarmsEnabled)
        assertFalse(profile.timersEnabled)
    }

    @Test
    fun profile_defaultValues_shouldHaveCorrectDefaults() {
        val profile = Profile("profile1", "Default")

        assertTrue(profile.ringtoneEnabled)
        assertTrue(profile.vibrateEnabled)
        assertFalse(profile.unmuteEnabled)
        assertFalse(profile.dndEnabled)
        assertTrue(profile.alarmsEnabled)
        assertTrue(profile.timersEnabled)
    }

    @Test
    fun profile_equals_shouldMatchEqualProfiles() {
        val profile1 = Profile("profile1", "Silent", ringtoneEnabled = false)
        val profile2 = Profile("profile1", "Silent", ringtoneEnabled = false)

        assertEquals(profile1, profile2)
    }

    @Test
    fun profile_notEquals_shouldDifferById() {
        val profile1 = Profile("profile1", "Silent")
        val profile2 = Profile("profile2", "Silent")

        assertNotEquals(profile1, profile2)
    }

    @Test
    fun profile_notEquals_shouldDifferByName() {
        val profile1 = Profile("profile1", "Silent")
        val profile2 = Profile("profile1", "Loud")

        assertNotEquals(profile1, profile2)
    }

    @Test
    fun profile_hashCode_shouldBeEqualForEqualProfiles() {
        val profile1 = Profile("profile1", "Silent", ringtoneEnabled = false)
        val profile2 = Profile("profile1", "Silent", ringtoneEnabled = false)

        assertEquals(profile1.hashCode(), profile2.hashCode())
    }

    @Test
    fun profile_toString_shouldContainAllProperties() {
        val profile = Profile("profile1", "Test Profile")
        val stringRepresentation = profile.toString()

        assertTrue(stringRepresentation.contains("profile1"))
        assertTrue(stringRepresentation.contains("Test Profile"))
    }

    @Test
    fun profile_copy_shouldCreateCopyWithModifiedProperties() {
        val original = Profile("profile1", "Original", ringtoneEnabled = true)
        val copied = original.copy(ringtoneEnabled = false, dndEnabled = true)

        assertEquals("profile1", copied.id)
        assertEquals("Original", copied.name)
        assertFalse(copied.ringtoneEnabled)
        assertTrue(copied.dndEnabled)
    }

    @Test
    fun profile_allFlagsDisabled_shouldWork() {
        val profile = Profile(
            id = "profile1",
            name = "All Off",
            ringtoneEnabled = false,
            vibrateEnabled = false,
            unmuteEnabled = false,
            dndEnabled = false,
            alarmsEnabled = false,
            timersEnabled = false
        )

        assertFalse(profile.ringtoneEnabled)
        assertFalse(profile.vibrateEnabled)
        assertFalse(profile.unmuteEnabled)
        assertFalse(profile.dndEnabled)
        assertFalse(profile.alarmsEnabled)
        assertFalse(profile.timersEnabled)
    }

    @Test
    fun profile_allFlagsEnabled_shouldWork() {
        val profile = Profile(
            id = "profile1",
            name = "All On",
            ringtoneEnabled = true,
            vibrateEnabled = true,
            unmuteEnabled = true,
            dndEnabled = true,
            alarmsEnabled = true,
            timersEnabled = true
        )

        assertTrue(profile.ringtoneEnabled)
        assertTrue(profile.vibrateEnabled)
        assertTrue(profile.unmuteEnabled)
        assertTrue(profile.dndEnabled)
        assertTrue(profile.alarmsEnabled)
        assertTrue(profile.timersEnabled)
    }

    @Test
    fun profile_partialFlags_shouldWork() {
        val profile = Profile(
            id = "profile1",
            name = "Partial",
            ringtoneEnabled = false,
            vibrateEnabled = true,
            unmuteEnabled = false,
            dndEnabled = false,
            alarmsEnabled = true,
            timersEnabled = false
        )

        assertEquals(4, listOf(
            profile.vibrateEnabled,
            profile.alarmsEnabled
        ).count { it })

        assertEquals(4, listOf(
            profile.ringtoneEnabled,
            profile.unmuteEnabled,
            profile.dndEnabled,
            profile.timersEnabled
        ).count { !it })
    }

    @Test
    fun profile_copyName_shouldPreserveOtherFields() {
        val original = Profile(
            id = "profile1",
            name = "Original",
            ringtoneEnabled = false,
            vibrateEnabled = false,
            dndEnabled = true
        )
        val copied = original.copy(name = "Renamed")

        assertEquals("profile1", copied.id)
        assertEquals("Renamed", copied.name)
        assertFalse(copied.ringtoneEnabled)
        assertFalse(copied.vibrateEnabled)
        assertTrue(copied.dndEnabled)
    }

    @Test
    fun profile_specialCharactersInName_shouldWork() {
        val profile = Profile("profile1", "Silent @ Work! #$%")

        assertEquals("Silent @ Work! #$%", profile.name)
    }
}
