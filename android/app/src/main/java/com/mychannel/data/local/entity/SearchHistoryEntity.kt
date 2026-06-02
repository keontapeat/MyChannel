package com.mychannel.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room entity storing a local search history term (REQ-6.2).
 *
 * The [query] is the primary key so re-searching an existing term updates its
 * [searchedAtMillis] (via REPLACE) rather than creating duplicates.
 */
@Entity(tableName = "search_history")
data class SearchHistoryEntity(
    @PrimaryKey val query: String,
    val searchedAtMillis: Long = System.currentTimeMillis()
)
