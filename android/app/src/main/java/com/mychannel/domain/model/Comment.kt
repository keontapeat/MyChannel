package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Comment domain model — mirrors `videos/{videoId}/comments/{commentId}`.
 *
 * Nested replies are modeled via [parentId]; a top-level comment has a null
 * (empty) parentId. [replyCount] enables lazy loading of reply threads.
 */
data class Comment(
    val id: String = "",
    val videoId: String = "",
    val userId: String = "",
    val username: String = "",
    val avatarUrl: String = "",
    val text: String = "",
    val likeCount: Long = 0L,
    val replyCount: Long = 0L,
    val parentId: String? = null,
    val createdAt: Timestamp = Timestamp(0, 0)
)
