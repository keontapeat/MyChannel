package com.mychannel.services

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 🤖 OpenAI Service - GPT-5 Powered AI
 * 
 * Features:
 * - Content generation (titles, descriptions, scripts)
 * - Content moderation
 * - SEO optimization
 * - Search query understanding
 * - Viral prediction
 */
@Singleton
class OpenAIService @Inject constructor(
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
        get() = keychainManager.get("OPENAI_API_KEY") ?: ""
    
    /**
     * Generate text using GPT-5
     */
    suspend fun generate(
        prompt: String,
        model: GPTModel = GPTModel.GPT5_TURBO,
        maxTokens: Int = 1000,
        temperature: Double = 0.7
    ): String = withContext(Dispatchers.IO) {
        val requestBody = """
            {
                "model": "${model.value}",
                "messages": [
                    {
                        "role": "user",
                        "content": "$prompt"
                    }
                ],
                "max_tokens": $maxTokens,
                "temperature": $temperature
            }
        """.trimIndent()
        
        val request = Request.Builder()
            .url("https://api.openai.com/v1/chat/completions")
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("Content-Type", "application/json")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()
        
        try {
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""
            
            if (!response.isSuccessful) {
                throw Exception("OpenAI API error: ${response.code} - $responseBody")
            }
            
            // Parse response
            val jsonResponse = json.parseToJsonElement(responseBody).jsonObject
            val choices = jsonResponse["choices"]?.jsonArray
            val message = choices?.get(0)?.jsonObject?.get("message")?.jsonObject
            val content = message?.get("content")?.jsonPrimitive?.content ?: ""
            
            content
        } catch (e: Exception) {
            throw Exception("Failed to generate with OpenAI: ${e.message}")
        }
    }
    
    /**
     * Generate video script
     */
    suspend fun generateVideoScript(topic: String, duration: Int): String {
        val prompt = """
            Write a compelling $duration-minute video script about: $topic
            
            Include:
            - Hook (first 10 seconds)
            - Main content with talking points
            - Call to action at the end
            - Timestamps for each section
            
            Make it engaging and authentic for YouTube/TikTok.
        """.trimIndent()
        
        return generate(prompt, GPTModel.GPT5_TURBO)
    }
    
    /**
     * Optimize video for SEO
     */
    suspend fun optimizeForSEO(
        title: String,
        description: String
    ): SEOOptimization {
        val prompt = """
            Optimize this video for SEO:
            
            Title: $title
            Description: $description
            
            Provide:
            1. Optimized title (under 70 characters)
            2. SEO-friendly description with keywords
            3. 10-15 relevant tags
            
            Format as JSON:
            {
              "title": "...",
              "description": "...",
              "tags": ["tag1", "tag2", ...]
            }
        """.trimIndent()
        
        val response = generate(prompt, GPTModel.GPT5_TURBO)
        
        return try {
            json.decodeFromString(response)
        } catch (e: Exception) {
            SEOOptimization(title, description, emptyList())
        }
    }
    
    /**
     * Generate thumbnail text suggestions
     */
    suspend fun generateThumbnailText(videoTitle: String): List<String> {
        val prompt = """
            Generate 5 catchy, short text options for a video thumbnail.
            Video title: "$videoTitle"
            
            Requirements:
            - 2-4 words max
            - Attention-grabbing
            - Capitalize first letter of each word
            
            Return only a JSON array: ["text1", "text2", ...]
        """.trimIndent()
        
        val response = generate(prompt, GPTModel.GPT5_TURBO)
        
        return try {
            json.decodeFromString(response)
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    /**
     * Moderate content using GPT-5
     */
    suspend fun moderateContent(content: String): ModerationResult {
        val prompt = """
            You are an advanced content moderation AI. Analyze the following content for safety and policy compliance.
            
            Content: "$content"
            
            Rate the content on a scale of 0.0 to 1.0, where:
            - 1.0 = Completely safe and appropriate
            - 0.7-0.9 = Minor concerns, may need age restriction
            - 0.4-0.6 = Moderate concerns, needs human review
            - 0.0-0.3 = Severe violations, should be removed
            
            Consider these factors:
            - Hate speech, harassment, bullying
            - Violence, graphic content
            - Sexual or adult content
            - Spam, scams, misleading information
            - Dangerous or illegal activities
            - Child safety concerns
            
            Respond with ONLY a JSON object:
            {
              "safety_score": 0.0-1.0,
              "reasoning": "Brief explanation",
              "primary_concern": "category name or null"
            }
        """.trimIndent()
        
        val response = generate(prompt, GPTModel.GPT5_TURBO)
        
        return try {
            json.decodeFromString(response)
        } catch (e: Exception) {
            ModerationResult(0.9, "Unable to parse moderation result", null)
        }
    }
}

/**
 * GPT Model enum
 */
enum class GPTModel(val value: String) {
    GPT5("gpt-5"),
    GPT5_TURBO("gpt-5-turbo"),
    GPT4("gpt-4"),
    GPT4_TURBO("gpt-4-turbo-preview"),
    GPT4O("gpt-4o"),
    GPT35_TURBO("gpt-3.5-turbo");
    
    companion object {
        val DEFAULT = GPT5_TURBO
    }
}

@Serializable
data class SEOOptimization(
    val title: String,
    val description: String,
    val tags: List<String>
)

@Serializable
data class ModerationResult(
    val safety_score: Double,
    val reasoning: String,
    val primary_concern: String?
)

