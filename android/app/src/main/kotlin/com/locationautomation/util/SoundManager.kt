package com.locationautomation.util

import android.content.Context
import android.media.MediaPlayer
import androidx.annotation.RawRes

object SoundManager {
    fun playSound(context: Context, @RawRes soundResId: Int) {
        try {
            val mediaPlayer = MediaPlayer.create(context, soundResId)
            mediaPlayer?.setOnCompletionListener { it.release() }
            mediaPlayer?.start()
        } catch (e: Exception) {
            android.util.Log.e("SoundManager", "Failed to play sound $soundResId", e)
        }
    }
}
