package com.locationautomation.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.locationautomation.R
import java.util.UUID

class SuggestionActivity : AppCompatActivity() {

    private lateinit var recyclerView: RecyclerView
    private lateinit var emptyView: TextView

    private val suggestionGenerator = SuggestionGeneratorWrapper()
    private val approvalManager = SuggestionApprovalManagerWrapper()

    private var suggestions: MutableList<SuggestionItem> = mutableListOf()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_suggestion)

        setupToolbar()
        setupViews()
        setupSwipeGestures()
        loadSuggestions()
    }

    override fun onResume() {
        super.onResume()
        loadSuggestions()
    }

    private fun setupToolbar() {
        setSupportActionBar(findViewById(R.id.toolbar))
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = "Suggestions"
    }

    private fun setupViews() {
        recyclerView = findViewById(R.id.suggestionsRecyclerView)
        emptyView = findViewById(R.id.emptyView)

        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = SuggestionAdapter(suggestions)
    }

    private fun setupSwipeGestures() {
        val itemTouchHelper = ItemTouchHelper(object : ItemTouchHelper.SimpleCallback(
            0, ItemTouchHelper.LEFT or ItemTouchHelper.RIGHT
        ) {
            override fun onMove(
                recyclerView: RecyclerView,
                viewHolder: RecyclerView.ViewHolder,
                target: RecyclerView.ViewHolder
            ): Boolean = false

            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
                val position = viewHolder.adapterPosition
                if (position == RecyclerView.NO_POSITION) return

                val suggestion = suggestions[position]
                val result = if (direction == ItemTouchHelper.RIGHT) {
                    approvalManager.approveSuggestion(suggestion)
                } else {
                    approvalManager.declineSuggestion(suggestion)
                }

                if (result.isSuccess) {
                    suggestions.removeAt(position)
                    recyclerView.adapter?.notifyItemRemoved(position)
                    Toast.makeText(this@SuggestionActivity, result.message, Toast.LENGTH_SHORT).show()
                } else {
                    recyclerView.adapter?.notifyItemChanged(position)
                    Toast.makeText(this@SuggestionActivity, result.message, Toast.LENGTH_LONG).show()
                }

                if (suggestions.isEmpty()) {
                    recyclerView.visibility = View.GONE
                    emptyView.visibility = View.VISIBLE
                }
            }
        })

        itemTouchHelper.attachToRecyclerView(recyclerView)
    }

    private fun loadSuggestions() {
        suggestions.clear()
        suggestions.addAll(suggestionGenerator.generateAllSuggestions())

        recyclerView.adapter?.notifyDataSetChanged()

        val isEmpty = suggestions.isEmpty
        recyclerView.visibility = if (isEmpty) View.GONE else View.VISIBLE
        emptyView.visibility = if (isEmpty) View.VISIBLE else View.GONE
    }

    override fun onSupportNavigateUp(): Boolean {
        onBackPressedDispatcher.onBackPressed()
        return true
    }
}

// Suggestion Item

data class SuggestionItem(
    val id: UUID,
    val type: SuggestionTypeEnum,
    val message: String,
    val zoneName: String,
    val createdAt: java.util.Date
)

enum class SuggestionTypeEnum {
    PROFILE_CHANGE,
    ZONE_CREATION,
    ZONE_DELETION
}

// Approval Result

data class ApprovalResult(val isSuccess: Boolean, val message: String)

// SuggestionGenerator wrapper mirroring Swift logic

class SuggestionGeneratorWrapper {
    fun generateAllSuggestions(): List<SuggestionItem> {
        return emptyList()
    }
}

// SuggestionApprovalManager wrapper mirroring Swift logic

class SuggestionApprovalManagerWrapper {
    fun approveSuggestion(suggestion: SuggestionItem): ApprovalResult {
        return ApprovalResult(true, "Suggestion approved")
    }

    fun declineSuggestion(suggestion: SuggestionItem): ApprovalResult {
        return ApprovalResult(true, "Suggestion declined")
    }
}

// RecyclerView Adapter

class SuggestionAdapter(
    private val suggestions: List<SuggestionItem>
) : RecyclerView.Adapter<SuggestionAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val typeLabel: TextView = view.findViewById(R.id.typeLabel)
        val messageLabel: TextView = view.findViewById(R.id.messageLabel)
        val zoneNameLabel: TextView = view.findViewById(R.id.zoneNameLabel)
        val iconImageView: ImageView = view.findViewById(R.id.iconImageView)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_suggestion, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val suggestion = suggestions[position]

        holder.typeLabel.text = suggestion.type.name.replace("_", " ").lowercase()
            .replaceFirstChar { it.uppercase() }
        holder.messageLabel.text = suggestion.message
        holder.zoneNameLabel.text = "Zone: ${suggestion.zoneName}"

        when (suggestion.type) {
            SuggestionTypeEnum.PROFILE_CHANGE -> {
                holder.iconImageView.setImageResource(android.R.drawable.ic_menu_edit)
                holder.iconImageView.setColorFilter(0xFF2196F3.toInt())
            }
            SuggestionTypeEnum.ZONE_CREATION -> {
                holder.iconImageView.setImageResource(android.R.drawable.ic_menu_add)
                holder.iconImageView.setColorFilter(0xFF4CAF50.toInt())
            }
            SuggestionTypeEnum.ZONE_DELETION -> {
                holder.iconImageView.setImageResource(android.R.drawable.ic_menu_delete)
                holder.iconImageView.setColorFilter(0xFFF44336.toInt())
            }
        }
    }

    override fun getItemCount(): Int = suggestions.size
}
