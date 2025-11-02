package com.mychannel.services

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 🤖 Google Vertex AI (Gemini) Service
 * 
 * Features:
 * - Gemini 1.5 Pro integration
 * - Visual analysis
 * - Context understanding
 * - Multimodal AI
 * - Trend analysis
 */
@Singleton
class VertexAIService @Inject constructor(
    private val context: Context,
    private val keychainManager: KeychainManager
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()
    
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }
    
    private val apiKey: String
        get() = keychainManager.googleCloudKey ?: ""
    
    /**
     * Generate text using Gemini
     */
    suspend fun generateWithGemini(
        prompt: String,
        model: GeminiModel = GeminiModel.GEMINI_1_5_PRO
    ): String = withContext(Dispatchers.IO) {
        val requestBody = """
            {
                "contents": [
                    {
                        "parts": [
                            {
                                "text": "$prompt"
                            }
                        ]
                    }
                ],
                "generationConfig": {
                    "temperature": 0.7,
                    "topK": 40,
                    "topP": 0.95,
                    "maxOutputTokens": 2048
                }
            }
        """.trimIndent()
        
        val url = "https://generativelanguage.googleapis.com/v1beta/models/${model.value}:generateContent?key=$apiKey"
        
        val request = Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()
        
        try {
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""
            
            if (!response.isSuccessful) {
                throw Exception("Gemini API error: ${response.code} - $responseBody")
            }
            
            // Parse response
            val jsonResponse = json.parseToJsonElement(responseBody).jsonObject
            val candidates = jsonResponse["candidates"]?.jsonArray
            val content = candidates?.get(0)?.jsonObject?.get("content")?.jsonObject
            val parts = content?.get("parts")?.jsonArray
            val text = parts?.get(0)?.jsonObject?.get("text")?.jsonPrimitive?.content ?: ""
            
            text
        } catch (e: Exception) {
            throw Exception("Failed to generate with Gemini: ${e.message}")
        }
    }
    
    /**
     * Analyze visual content
     */
    suspend fun analyzeVisuals(imageBase64: String, prompt: String): String {
        val requestBody = """
            {
                "contents": [
                    {
                        "parts": [
                            {
                                "text": "$prompt"
                            },
                            {
                                "inline_data": {
                                    "mime_type": "image/jpeg",
                                    "data": "$imageBase64"
                                }
                            }
                        ]
                    }
                ]
            }
        """.trimIndent()
        
        val url = "https://generativelanguage.googleapis.com/v1beta/models/${GeminiModel.GEMINI_PRO_VISION.value}:generateContent?key=$apiKey"
        
        val request = Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()
        
        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""
        
        if (!response.isSuccessful) {
            throw Exception("Gemini Vision API error: ${response.code} - $responseBody")
        }
        
        // Parse response
        val jsonResponse = json.parseToJsonElement(responseBody).jsonObject
        val candidates = jsonResponse["candidates"]?.jsonArray
        val content = candidates?.get(0)?.jsonObject?.get("content")?.jsonObject
        val parts = content?.get("parts")?.jsonArray
        val text = parts?.get(0)?.jsonObject?.get("text")?.jsonPrimitive?.content ?: ""
        
        return text
    }
    
    /**
     * Generate thumbnail suggestions
     */
    suspend fun generateThumbnailSuggestions(videoTitle: String): String {
        val prompt = """
            Generate creative thumbnail suggestions for this video:
            
            Title: "$videoTitle"
            
            Provide 3 thumbnail concepts with:
            - Main visual element
            - Text overlay
            - Color scheme
            - Emotional tone
            - Viral potential score (0-10)
            
            Format as JSON array.
        """.trimIndent()
        
        return generateWithGemini(prompt, GeminiModel.GEMINI_1_5_PRO)
    }
    
    /**
     * Analyze trends
     */
    suspend fun analyzeTrends(topic: String): String {
        val prompt = """
            Analyze current trends related to: $topic
            
            Provide:
            - Trending keywords
            - Viral topics
            - Audience demographics
            - Best posting times
            - Content format recommendations
            
            Format as JSON.
        """.trimIndent()
        
        return generateWithGemini(prompt, GeminiModel.GEMINI_1_5_PRO)
    }
}

/**
 * Gemini Model enum
 */
enum class GeminiModel(val value: String) {
    GEMINI_PRO("gemini-pro"),
    GEMINI_PRO_VISION("gemini-pro-vision"),
    GEMINI_1_5_PRO("gemini-1.5-pro"),
    GEMINI_1_5_FLASH("gemini-1.5-flash");
    
    companion object {
        val DEFAULT = GEMINI_1_5_PRO
    }
}

