package com.locationautomation.ui

import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.viewpager2.widget.ViewPager2
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.tabs.TabLayoutMediator
import com.locationautomation.MainActivity
import com.locationautomation.R
import com.locationautomation.databinding.ActivityOnboardingBinding

class OnboardingActivity : AppCompatActivity() {

    private lateinit var binding: ActivityOnboardingBinding
    private lateinit var adapter: OnboardingPageAdapter

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineLocationGranted = permissions[android.Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        val coarseLocationGranted = permissions[android.Manifest.permission.ACCESS_COARSE_LOCATION] ?: false

        if (fineLocationGranted || coarseLocationGranted) {
            moveToNextPage()
        } else {
            showPermissionDeniedMessage()
        }
    }

    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            moveToNextPage()
        } else {
            moveToNextPage()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityOnboardingBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupViewPager()
        setupButtons()
    }

    private fun setupViewPager() {
        adapter = OnboardingPageAdapter()
        binding.onboardingViewPager.adapter = adapter

        binding.onboardingViewPager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                updateUIForPage(position)
            }
        })

        TabLayoutMediator(binding.pageIndicator, binding.onboardingViewPager) { _, _ -> }.attach()
    }

    private fun setupButtons() {
        binding.skipButton.setOnClickListener {
            val currentItem = binding.onboardingViewPager.currentItem
            if (currentItem < 2) {
                binding.onboardingViewPager.currentItem = currentItem + 1
            }
        }

        binding.continueButton.setOnClickListener {
            handleContinueButtonClick()
        }
    }

    private fun handleContinueButtonClick() {
        val currentItem = binding.onboardingViewPager.currentItem

        when (currentItem) {
            0 -> requestLocationPermission()
            1 -> requestNotificationPermission()
            2 -> finishOnboarding()
        }
    }

    private fun requestLocationPermission() {
        if (hasLocationPermission()) {
            moveToNextPage()
        } else {
            locationPermissionLauncher.launch(
                arrayOf(
                    android.Manifest.permission.ACCESS_FINE_LOCATION,
                    android.Manifest.permission.ACCESS_COARSE_LOCATION
                )
            )
        }
    }

    private fun requestNotificationPermission() {
        if (hasNotificationPermission()) {
            moveToNextPage()
        } else {
            notificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun hasNotificationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.POST_NOTIFICATIONS
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun moveToNextPage() {
        val currentItem = binding.onboardingViewPager.currentItem
        if (currentItem < 2) {
            binding.onboardingViewPager.currentItem = currentItem + 1
        }
    }

    private fun updateUIForPage(position: Int) {
        when (position) {
            0, 1 -> {
                binding.skipButton.visibility = View.VISIBLE
                binding.continueButton.text = getString(R.string.continue_text)
            }
            2 -> {
                binding.skipButton.visibility = View.GONE
                binding.continueButton.text = getString(R.string.get_started)
            }
        }
    }

    private fun showPermissionDeniedMessage() {
        Snackbar.make(
            binding.root,
            R.string.permission_denied_message,
            Snackbar.LENGTH_LONG
        ).show()
    }

    private fun finishOnboarding() {
        val prefs = getSharedPreferences("onboarding", MODE_PRIVATE)
        prefs.edit().putBoolean("completed", true).apply()

        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }
}