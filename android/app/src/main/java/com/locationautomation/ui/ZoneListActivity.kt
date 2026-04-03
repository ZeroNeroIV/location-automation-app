package com.locationautomation.ui

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.snackbar.Snackbar
import com.locationautomation.R
import com.locationautomation.data.Zone
import com.locationautomation.data.ZoneDatabase
import com.locationautomation.location.LocationForegroundService

class ZoneListActivity : BaseActivity() {

    companion object {
        private const val REQUEST_EDIT_ZONE = 1001
    }

    private lateinit var database: ZoneDatabase
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: ZoneAdapter
    private lateinit var emptyStateView: View

    private val editZoneLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            loadZones()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_zone_list)

        setupToolbar()
        setupViews()
        setupSwipeToDelete()
    }

    override fun onResume() {
        super.onResume()
        loadZones()
    }

    private fun setupToolbar() {
        supportActionBar?.apply {
            title = getString(R.string.zones)
            setDisplayHomeAsUpEnabled(true)
            setHomeAsUpIndicator(android.R.drawable.ic_menu_revert)
        }
    }

    private fun setupViews() {
        database = ZoneDatabase(this)

        recyclerView = findViewById(R.id.zonesRecyclerView)
        emptyStateView = findViewById(R.id.emptyStateView)

        adapter = ZoneAdapter(
            onItemClick = { zone -> editZone(zone) },
            onActiveToggle = { zone, isActive -> toggleActive(zone, isActive) },
            onTriggerClick = { zone -> triggerZone(zone) }
        )

        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        findViewById<View>(R.id.fabAddZone).setOnClickListener {
            openMapActivity()
        }

        findViewById<View>(R.id.btnBack)?.setOnClickListener {
            onBackPressedDispatcher.onBackPressed()
        }
    }

    private fun setupSwipeToDelete() {
        val swipeHandler = object : ItemTouchHelper.SimpleCallback(
            0,
            ItemTouchHelper.LEFT or ItemTouchHelper.RIGHT
        ) {
            override fun onMove(
                recyclerView: RecyclerView,
                viewHolder: RecyclerView.ViewHolder,
                target: RecyclerView.ViewHolder
            ): Boolean = false

            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
                val position = viewHolder.adapterPosition
                val zone = adapter.getZoneAt(position)
                
                if (direction == ItemTouchHelper.LEFT) {
                    showDeleteConfirmation(zone, position)
                } else {
                    editZone(zone)
                    adapter.notifyItemChanged(position)
                }
            }

            override fun getSwipeDirs(
                recyclerView: RecyclerView,
                viewHolder: RecyclerView.ViewHolder
            ): Int {
                return ItemTouchHelper.LEFT or ItemTouchHelper.RIGHT
            }
        }

        ItemTouchHelper(swipeHandler).attachToRecyclerView(recyclerView)
    }

    private fun showDeleteConfirmation(zone: Zone, position: Int) {
        AlertDialog.Builder(this)
            .setTitle("Delete Zone")
            .setMessage("Are you sure you want to delete '${zone.name}'?")
            .setPositiveButton("Delete") { _, _ ->
                deleteZone(zone, position)
            }
            .setNegativeButton("Cancel") { _, _ ->
                adapter.notifyItemChanged(position)
            }
            .setOnCancelListener {
                adapter.notifyItemChanged(position)
            }
            .show()
    }

    private fun loadZones() {
        try {
            val zones = database.getAllZones()
            adapter.submitList(zones)
            updateEmptyState(zones.isEmpty())
        } catch (e: Exception) {
            android.util.Log.e("ZoneListActivity", "Failed to load zones", e)
            Toast.makeText(this, "Failed to load zones", Toast.LENGTH_SHORT).show()
        }
    }

    private fun updateEmptyState(isEmpty: Boolean) {
        emptyStateView.visibility = if (isEmpty) View.VISIBLE else View.GONE
        recyclerView.visibility = if (isEmpty) View.GONE else View.VISIBLE
    }

    private fun editZone(zone: Zone) {
        val intent = Intent(this, MapActivity::class.java).apply {
            putExtra("zone_id", zone.id)
        }
        startActivity(intent)
    }

    private fun openMapActivity() {
        startActivity(Intent(this, MapActivity::class.java))
    }

    private fun toggleActive(zone: Zone, isActive: Boolean) {
        val updatedZone = zone.copy(profileId = if (isActive) "active" else "inactive")
        try {
            database.saveZone(updatedZone)
            loadZones()
        } catch (e: Exception) {
            android.util.Log.e("ZoneListActivity", "Failed to update zone", e)
        }
    }

    private fun deleteZone(zone: Zone, position: Int) {
        try {
            database.deleteZone(zone.id)
            adapter.notifyItemRemoved(position)
            updateEmptyState(adapter.itemCount == 0)

            Snackbar.make(recyclerView, R.string.zone_deleted, Snackbar.LENGTH_LONG)
                .setAction(R.string.cancel) {
                    database.saveZone(zone)
                    loadZones()
                }
                .show()
        } catch (e: Exception) {
            android.util.Log.e("ZoneListActivity", "Failed to delete zone", e)
            Toast.makeText(this, "Failed to delete zone", Toast.LENGTH_SHORT).show()
        }
    }

    private fun triggerZone(zone: Zone) {
        if (zone.isManuallyTriggered) {
            val updatedZone = zone.copy(isManuallyTriggered = false)
            try {
                database.saveZone(updatedZone)
                loadZones()
            } catch (e: Exception) {
                android.util.Log.e("ZoneListActivity", "Failed to reset zone", e)
            }
            LocationForegroundService.triggerNormalProfile(this)
            Toast.makeText(this, "Back to Normal: ${zone.name}", Toast.LENGTH_SHORT).show()
        } else {
            val updatedZone = zone.copy(isManuallyTriggered = true)
            try {
                database.saveZone(updatedZone)
                loadZones()
            } catch (e: Exception) {
                android.util.Log.e("ZoneListActivity", "Failed to update zone", e)
            }
            LocationForegroundService.triggerZone(this, zone.id)
            Toast.makeText(this, "Triggered: ${zone.name}", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        onBackPressedDispatcher.onBackPressed()
        return true
    }
}