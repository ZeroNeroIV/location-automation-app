package com.locationautomation.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.locationautomation.R
import com.locationautomation.data.ZoneDatabase

class ZoneTimeGraphView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    data class ZoneSlice(val name: String, val seconds: Long, val color: Int)

    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.LEFT
    }
    private val emptyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = ContextCompat.getColor(context, R.color.on_surface_tertiary)
        textAlign = Paint.Align.CENTER
        textSize = 28f
    }

    private var slices: List<ZoneSlice> = emptyList()
    private var barHeight = 32f
    private var labelSize = 24f
    private var dotRadius = 5f
    private var barCornerRadius = 8f

    private val zoneColors = listOf(
        0xFF0D9488.toInt(),
        0xFF6366F1.toInt(),
        0xFFF59E0B.toInt(),
        0xFFEF4444.toInt(),
        0xFF10B981.toInt(),
        0xFF8B5CF6.toInt(),
        0xFFEC4899.toInt(),
        0xFF06B6D4.toInt(),
    )

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    init {
        setWillNotDraw(false)
        setBackgroundColor(ContextCompat.getColor(context, R.color.surface))
    }

    fun setData(buckets: List<ZoneDatabase.ZoneTimeBucket>) {
        val totalSeconds = buckets.sumOf { it.totalSeconds }
        slices = buckets.mapIndexed { index, bucket ->
            val color = zoneColors[index % zoneColors.size]
            ZoneSlice(bucket.zoneName, bucket.totalSeconds, color)
        }
        invalidate()
    }

    fun clear() {
        slices = emptyList()
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val padding = paddingTop + paddingBottom
        val height = if (slices.isEmpty()) {
            padding + 60
        } else {
            padding + barHeight.toInt() + (labelSize.toInt() + 16) * slices.size + 16
        }
        setMeasuredDimension(width, height)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (slices.isEmpty()) {
            textPaint.color = ContextCompat.getColor(context, R.color.on_surface_tertiary)
            textPaint.textSize = 28f
            textPaint.textAlign = Paint.Align.CENTER
            canvas.drawText(
                "No data yet",
                width / 2f,
                height / 2f + 10f,
                textPaint
            )
            return
        }

        val totalSeconds = slices.sumOf { it.seconds }
        if (totalSeconds == 0L) return

        val barWidth = (width - paddingLeft - paddingRight).toFloat()
        val barTop = paddingTop.toFloat()
        var xOffset = paddingLeft.toFloat()

        slices.forEach { slice ->
            val sliceWidth = (slice.seconds.toFloat() / totalSeconds.toFloat()) * barWidth
            barPaint.color = slice.color

            val rect = RectF(xOffset, barTop, xOffset + sliceWidth, barTop + barHeight)
            if (slices.size == 1) {
                canvas.drawRoundRect(rect, barCornerRadius, barCornerRadius, barPaint)
            } else if (xOffset == paddingLeft.toFloat()) {
                canvas.drawRoundRect(
                    RectF(xOffset, barTop, xOffset + sliceWidth - 1, barTop + barHeight),
                    barCornerRadius, barCornerRadius, barPaint
                )
            } else if (xOffset + sliceWidth >= width - paddingRight) {
                canvas.drawRoundRect(
                    RectF(xOffset + 1, barTop, xOffset + sliceWidth, barTop + barHeight),
                    barCornerRadius, barCornerRadius, barPaint
                )
            } else {
                canvas.drawRect(xOffset + 1, barTop, xOffset + sliceWidth - 1, barTop + barHeight, barPaint)
            }
            xOffset += sliceWidth
        }

        var labelY = barTop + barHeight + 24f
        textPaint.textSize = labelSize
        textPaint.textAlign = Paint.Align.LEFT

        slices.forEach { slice ->
            textPaint.color = slice.color
            canvas.drawCircle(paddingLeft.toFloat() + dotRadius, labelY - labelSize / 2, dotRadius, textPaint)

            textPaint.color = ContextCompat.getColor(context, R.color.on_surface)
            val label = "${slice.name} — ${formatDuration(slice.seconds)}"
            canvas.drawText(label, paddingLeft + dotRadius * 2 + 8, labelY, textPaint)

            labelY += labelSize + 16
        }
    }

    private fun formatDuration(seconds: Long): String {
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        return if (hours > 0) {
            "${hours}h ${minutes}m"
        } else {
            "${minutes}m"
        }
    }
}
