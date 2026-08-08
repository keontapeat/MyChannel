package com.mychannel.data.remote

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Retrofit interface for the MyChannel Recommendations Service.
 * Base URL: https://api.mychannel.live (configured in NetworkModule).
 *
 * All endpoints require Authorization header (attached via auth interceptor)
 * and App Check token.
 */
interface RecommendationApi {

    /**
     * Personalized recommendations using hybrid algorithm (content-based 70% +
     * collaborative filtering 30%). Requires authenticated user.
     */
    @GET("v1/recommendations/personal")
    suspend fun getPersonalRecommendations(
        @Query("limit") limit: Int = 20,
        @Query("algorithm") algorithm: String = "hybrid"
    ): RecommendationResponse

    /**
     * Trending videos with time-decay scoring.
     */
    @GET("v1/recommendations/trending")
    suspend fun getTrending(
        @Query("limit") limit: Int = 20,
        @Query("timeframe") timeframe: String = "week"
    ): RecommendationResponse

    /**
     * Similar videos to a specific video (sidebar recommendations).
     */
    @GET("v1/recommendations/similar/{videoId}")
    suspend fun getSimilar(
        @Path("videoId") videoId: String,
        @Query("limit") limit: Int = 12
    ): RecommendationResponse
}

data class RecommendationResponse(
    val videos: List<RecommendedVideo> = emptyList(),
    val algorithm: String = "",
    val userId: String? = null
)

data class RecommendedVideo(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val thumbnailUrl: String = "",
    val duration: Int = 0,
    val viewCount: Long = 0L,
    val likeCount: Long = 0L,
    val commentCount: Long = 0L,
    val publishedAt: String? = null,
    val createdAt: String? = null,
    val creator: RecommendedCreator? = null
)

data class RecommendedCreator(
    val id: String = "",
    val username: String = "",
    val displayName: String = "",
    val avatarUrl: String = "",
    val verified: Boolean = false,
    val subscriberCount: Long = 0L
)
