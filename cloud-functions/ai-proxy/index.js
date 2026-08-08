/**
 * AI Content Generation Proxy — Securely calls Vertex AI Gemini from the client.
 *
 * Clients can't call Vertex AI directly (requires service account).
 * This callable function validates the user, rate-limits, and proxies
 * the request to Gemini 1.5 Flash.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { VertexAI } = require('@google-cloud/vertexai');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const PROJECT_ID = 'mychannel-ca26d';
const LOCATION = 'us-central1';
const MODEL = 'gemini-1.5-flash-001';

// Rate limit: 20 AI calls per user per hour
const RATE_LIMIT = 20;
const RATE_WINDOW_MS = 3600000;

/**
 * generateAIContent — Callable function for Creator Studio AI tools.
 *
 * Input: { prompt: string, model?: string }
 * Output: { text: string } or { error: string }
 */
exports.generateAIContent = functions.https.onCall(async (data, context) => {
  // Auth required
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const { prompt, model } = data;
  if (!prompt || typeof prompt !== 'string' || prompt.length < 10) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt must be at least 10 characters');
  }
  if (prompt.length > 32000) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt too long (max 32000 chars)');
  }

  // Rate limiting
  const userId = context.auth.uid;
  const rateLimitRef = db.collection('ai_rate_limits').doc(userId);
  const rateLimitDoc = await rateLimitRef.get();
  const rateLimitData = rateLimitDoc.data();

  if (rateLimitData) {
    const windowStart = rateLimitData.windowStart?.toMillis?.() || 0;
    const count = rateLimitData.count || 0;

    if (Date.now() - windowStart < RATE_WINDOW_MS && count >= RATE_LIMIT) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Max ${RATE_LIMIT} AI calls per hour.`
      );
    }

    if (Date.now() - windowStart >= RATE_WINDOW_MS) {
      // Reset window
      await rateLimitRef.set({
        windowStart: admin.firestore.FieldValue.serverTimestamp(),
        count: 1,
      });
    } else {
      await rateLimitRef.update({
        count: admin.firestore.FieldValue.increment(1),
      });
    }
  } else {
    await rateLimitRef.set({
      windowStart: admin.firestore.FieldValue.serverTimestamp(),
      count: 1,
    });
  }

  // Call Vertex AI
  try {
    const vertexAI = new VertexAI({ project: PROJECT_ID, location: LOCATION });
    const generativeModel = vertexAI.getGenerativeModel({
      model: model || MODEL,
      generationConfig: {
        maxOutputTokens: 4096,
        temperature: 0.7,
        topP: 0.9,
      },
      safetySettings: [
        { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      ],
    });

    const result = await generativeModel.generateContent(prompt);
    const response = result.response;
    const text = response?.candidates?.[0]?.content?.parts?.[0]?.text || '';

    if (!text) {
      return { error: 'No response generated. Content may have been filtered.' };
    }

    // Log usage for billing/analytics
    await db.collection('ai_usage_logs').add({
      userId,
      model: model || MODEL,
      promptLength: prompt.length,
      responseLength: text.length,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { text };
  } catch (error) {
    console.error('[AI Proxy] Vertex AI error:', error.message);
    return { error: 'AI generation failed. Please try again.' };
  }
});
