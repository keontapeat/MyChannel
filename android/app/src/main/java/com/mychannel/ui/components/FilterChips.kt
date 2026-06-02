package com.mychannel.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Home filter options (REQ-4.1). "All" shows everything; "Live" and "Shorts"
 * switch the feed source; the remainder constrain by category.
 */
val HomeFilters: List<String> = listOf(
    "All", "Live", "Shorts", "Music", "Movies", "Gaming", "News"
)

/**
 * Horizontal scrollable row of [FilterChip]s for the Home screen (REQ-4.1).
 *
 * @param filters the chip labels to render.
 * @param selectedFilter the currently-selected label.
 * @param onFilterSelected invoked with the chosen label when a chip is tapped.
 */
@Composable
fun FilterChips(
    selectedFilter: String,
    onFilterSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
    filters: List<String> = HomeFilters
) {
    LazyRow(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(items = filters, key = { it }) { filter ->
            val selected = filter == selectedFilter
            FilterChip(
                selected = selected,
                onClick = { onFilterSelected(filter) },
                label = { Text(filter) },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    }
}
