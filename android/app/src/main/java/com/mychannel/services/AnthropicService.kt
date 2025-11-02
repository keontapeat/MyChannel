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
 * 🤖 Anthropic Claude Service - Advanced AI
 * 
 * Features:
 * - Claude 3.5 Sonnet integration
 * - Content quality analysis
 * - Semantic understanding
 * - Script generation
 * - Content optimization
 */
@Singleton
class AnthropicService @Inject constructor(
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
        get() = keychainManager.anthropicKey ?: ""
    
    /**
     * Generate text using Claude
     */
    suspend fun generateWithClaude(
        prompt: String,
        model: ClaudeModel = ClaudeModel.CLAUDE_3_5_SONNET,
        maxTokens: Int = 2000
    ): String = withContext(Dispatchers.IO) {
        val requestBody = """
            {
                "model": "${model.value}",
                "max_tokens": $maxTokens,
                "messages": [
                    {
                        "role": "user",
                        "content": "$prompt"
                    }
                ]
            }
        """.trimIndent()
        
        val request = Request.Builder()
            .url("https://api.anthropic.com/v1/messages")
            .addHeader("x-api-key", apiKey)
            .addHeader("anthropic-version", "2023-06-01")
            .addHeader("Content-Type", "application/json")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()
        
        try {
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""
            
            if (!response.isSuccessful) {
                throw Exception("Anthropic API error: ${response.code} - $responseBody")
            }
            
            // Parse response
            val jsonResponse = json.parseToJsonElement(responseBody).jsonObject
            val content = jsonResponse["content"]?.jsonArray
            val text = content?.get(0)?.jsonObject?.get("text")?.jsonPrimitive?.content ?: ""
            
            text
        } catch (e: Exception) {
            throw Exception("Failed to generate with Claude: ${e.message}")
        }
    }
    
    /**
     * Analyze content quality
     */
    suspend fun analyzeContentQuality(content: String): String {
        val prompt = """
            Analyze this video content for quality and engagement potential:
            
            "$content"
            
            Provide:
            1. Content quality score (0-10)
            2. Engagement prediction (low/medium/high)
            3. Key strengths
            4. Areas for improvement
            5. Viral potential
            
            Format as JSON.
        """.trimIndent()
        
        return generateWithClaude(prompt)
    }
    
    /**
     * Generate video ideas
     */
    suspend fun generateVideoIdeas(topic: String, count: Int = 5): String {
        val prompt = """
            Generate $count creative video ideas about: $topic
            
            For each idea provide:
            - Title (catchy and SEO-friendly)
            - Brief description
            - Target audience
            - Estimated viral score (0-10)
            
            Format as JSON array.
        """.trimIndent()
        
        return generateWithClaude(prompt, ClaudeModel.CLAUDE_3_5_SONNET)
    }
}

/**
 * Claude Model enum
 */
enum class ClaudeModel(val value: String) {
    CLAUDE_3_5_SONNET("claude-3-5-sonnet-20241022"),
    CLAUDE_3_OPUS("claude-3-opus-20240229"),
    CLAUDE_3_SONNET("claude-3-sonnet-20240229"),
    CLAUDE_3_HAIKU("claude-3-haiku-20240307");
    
    companion object {
        val DEFAULT = CLAUDE_3_5_SONNET
    }
}

