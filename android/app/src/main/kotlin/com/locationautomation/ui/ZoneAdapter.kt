package com.locationautomation.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.locationautomation.R
import com.locationautomation.data.Zone
import java.util.UUID

class ZoneAdapter(
    private val onItemClick: (Zone) -> Unit,
    private val onActiveToggle: (Zone, Boolean) -> Unit,
    private val onTriggerClick: (Zone) -> Unit
) : ListAdapter<Zone, ZoneAdapter.ZoneViewHolder>(ZoneDiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ZoneViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_zone, parent, false)
        return ZoneViewHolder(view)
    }

    override fun onBindViewHolder(holder: ZoneViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    fun getZoneAt(position: Int): Zone = getItem(position)

    inner class ZoneViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val activeIndicator: View = itemView.findViewById(R.id.activeIndicator)
        private val zoneName: TextView = itemView.findViewById(R.id.zoneName)
        private val profileName: TextView = itemView.findViewById(R.id.profileName)
        private val zoneInfo: TextView = itemView.findViewById(R.id.zoneInfo)
        private val btnTrigger: ImageButton = itemView.findViewById(R.id.btnTrigger)

        fun bind(zone: Zone) {
            zoneName.text = zone.name
            profileName.text = itemView.context.getString(R.string.profile_name) + ": " + zone.profileId
            zoneInfo.text = "${zone.radius.toInt()}${itemView.context.getString(R.string.meters)}"

            val isActive = try {
                UUID.fromString(zone.profileId)
                true
            } catch (e: Exception) {
                zone.profileId == "active"
            }
            activeIndicator.visibility = if (isActive) View.VISIBLE else View.INVISIBLE

            val isManuallyTriggered = zone.isManuallyTriggered
            btnTrigger.setImageResource(if (isManuallyTriggered) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)

            itemView.setOnClickListener { onItemClick(zone) }
            itemView.setOnLongClickListener {
                onActiveToggle(zone, !isActive)
                true
            }
            btnTrigger.setOnClickListener { onTriggerClick(zone) }
        }
    }

    private class ZoneDiffCallback : DiffUtil.ItemCallback<Zone>() {
        override fun areItemsTheSame(oldItem: Zone, newItem: Zone): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: Zone, newItem: Zone): Boolean {
            return oldItem == newItem
        }
    }
}