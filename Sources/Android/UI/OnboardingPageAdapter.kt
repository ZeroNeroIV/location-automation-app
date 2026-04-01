package com.locationautomation.ui

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.locationautomation.R
import com.locationautomation.databinding.ItemOnboardingPageBinding

class OnboardingPageAdapter : RecyclerView.Adapter<OnboardingPageAdapter.OnboardingViewHolder>() {

    private val pages = listOf(
        OnboardingPage(
            illustration = R.drawable.ic_location_onboarding,
            title = R.string.onboarding_location_title,
            description = R.string.onboarding_location_description
        ),
        OnboardingPage(
            illustration = R.drawable.ic_notification_onboarding,
            title = R.string.onboarding_notification_title,
            description = R.string.onboarding_notification_description
        ),
        OnboardingPage(
            illustration = R.drawable.ic_zone_onboarding,
            title = R.string.onboarding_create_zone_title,
            description = R.string.onboarding_create_zone_description
        )
    )

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OnboardingViewHolder {
        val binding = ItemOnboardingPageBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return OnboardingViewHolder(binding)
    }

    override fun onBindViewHolder(holder: OnboardingViewHolder, position: Int) {
        holder.bind(pages[position])
    }

    override fun getItemCount(): Int = pages.size

    class OnboardingViewHolder(
        private val binding: ItemOnboardingPageBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(page: OnboardingPage) {
            binding.illustrationImageView.setImageResource(page.illustration)
            binding.titleTextView.setText(page.title)
            binding.descriptionTextView.setText(page.description)
        }
    }

    data class OnboardingPage(
        val illustration: Int,
        val title: Int,
        val description: Int
    )
}