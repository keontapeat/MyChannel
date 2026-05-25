"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
var express_1 = require("express");
var firebase_admin_1 = require("firebase-admin");
var storage_1 = require("@google-cloud/storage");
var crypto_1 = require("crypto");
var app = (0, express_1.default)();
app.use(express_1.default.json({ limit: '50mb' }));
// Firebase Admin SDK initialization
if (!firebase_admin_1.default.apps.length) {
    firebase_admin_1.default.initializeApp({
        credential: firebase_admin_1.default.credential.applicationDefault(),
        projectId: 'mychannel-ca26d'
    });
}
var db = firebase_admin_1.default.firestore();
var storage = new storage_1.Storage();
var bucket = storage.bucket('mychannel-ca26d.appspot.com');
// Helper function to verify Firebase Auth token
function requireUser(req, res) {
    return __awaiter(this, void 0, void 0, function () {
        var authHeader, token, decoded, error_1;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    authHeader = req.headers.authorization;
                    if (!(authHeader === null || authHeader === void 0 ? void 0 : authHeader.startsWith('Bearer '))) {
                        res.status(401).json({ error: 'Unauthorized' });
                        return [2 /*return*/, null];
                    }
                    token = authHeader.split('Bearer ')[1];
                    return [4 /*yield*/, firebase_admin_1.default.auth().verifyIdToken(token)];
                case 1:
                    decoded = _a.sent();
                    return [2 /*return*/, { userId: decoded.uid, email: decoded.email }];
                case 2:
                    error_1 = _a.sent();
                    res.status(401).json({ error: 'Invalid token' });
                    return [2 /*return*/, null];
                case 3: return [2 /*return*/];
            }
        });
    });
}
// Helper function to generate track ID
function generateTrackId() {
    return crypto_1.default.randomUUID();
}
// ─────────────────────────────────────────────────────────────────────────────
// Phase 1: Enhanced Music Upload & Processing Service
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/tracks/upload - Initiate upload with metadata
app.post('/v1/music/tracks/upload', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, _a, title, artistName, albumName, genre, isExplicit, duration, trackId, now, trackRef, error_2;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 3, , 4]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                _a = req.body || {}, title = _a.title, artistName = _a.artistName, albumName = _a.albumName, genre = _a.genre, isExplicit = _a.isExplicit, duration = _a.duration;
                if (!title || typeof title !== 'string') {
                    return [2 /*return*/, res.status(400).json({ error: 'title is required' })];
                }
                if (!artistName || typeof artistName !== 'string') {
                    return [2 /*return*/, res.status(400).json({ error: 'artistName is required' })];
                }
                if (!genre || typeof genre !== 'string') {
                    return [2 /*return*/, res.status(400).json({ error: 'genre is required' })];
                }
                trackId = generateTrackId();
                now = firebase_admin_1.default.firestore.Timestamp.now();
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.set({
                        id: trackId,
                        title: title.trim(),
                        artistId: user.userId,
                        artistName: artistName.trim(),
                        albumName: (albumName === null || albumName === void 0 ? void 0 : albumName.trim()) || null,
                        genre: genre.trim(),
                        isExplicit: isExplicit || false,
                        duration: duration || null,
                        status: 'uploading',
                        uploadStartedAt: now,
                        createdAt: now,
                        streamCount: 0,
                        likeCount: 0,
                        artworkURL: null,
                        audioURL: null,
                        transcodingStatus: 'pending',
                        distributionStatus: 'not_submitted'
                    })];
            case 2:
                _b.sent();
                res.status(201).json({
                    trackId: trackId,
                    status: 'uploading',
                    message: 'Upload initiated. Use chunked upload endpoint for large files.'
                });
                return [3 /*break*/, 4];
            case 3:
                error_2 = _b.sent();
                console.error('Initiate upload error:', error_2);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 4];
            case 4: return [2 /*return*/];
        }
    });
}); });
// POST /v1/music/tracks/:trackId/chunk - Chunked audio upload
app.post('/v1/music/tracks/:trackId/chunk', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, _a, chunkIndex, totalChunks, chunkData, trackRef, trackSnap, trackData, chunkRef, buffer, error_3;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 5, , 6]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                _a = req.body || {}, chunkIndex = _a.chunkIndex, totalChunks = _a.totalChunks, chunkData = _a.chunkData;
                if (!chunkData || typeof chunkData !== 'string') {
                    return [2 /*return*/, res.status(400).json({ error: 'chunkData is required' })];
                }
                if (typeof chunkIndex !== 'number' || typeof totalChunks !== 'number') {
                    return [2 /*return*/, res.status(400).json({ error: 'chunkIndex and totalChunks are required' })];
                }
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _b.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                chunkRef = bucket.file("music/temp/".concat(user.userId, "/").concat(trackId, "/chunk_").concat(chunkIndex));
                buffer = Buffer.from(chunkData, 'base64');
                return [4 /*yield*/, chunkRef.save(buffer)];
            case 3:
                _b.sent();
                // Update track with chunk progress
                return [4 /*yield*/, trackRef.update({
                        totalChunks: totalChunks,
                        uploadedChunks: firebase_admin_1.default.firestore.FieldValue.increment(1),
                        lastChunkUploadedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                    })];
            case 4:
                // Update track with chunk progress
                _b.sent();
                res.json({
                    trackId: trackId,
                    chunkIndex: chunkIndex,
                    status: 'chunk_uploaded',
                    message: "Chunk ".concat(chunkIndex + 1, " of ").concat(totalChunks, " uploaded")
                });
                return [3 /*break*/, 6];
            case 5:
                error_3 = _b.sent();
                console.error('Chunk upload error:', error_3);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 6];
            case 6: return [2 /*return*/];
        }
    });
}); });
// POST /v1/music/tracks/:trackId/complete - Finalize upload and trigger processing
app.post('/v1/music/tracks/:trackId/complete', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, _a, fileName, mimeType, trackRef, trackSnap, trackData, tempDir, chunks, finalAudioPath, finalAudioRef, firstChunk, chunkData, audioURL, _i, chunks_1, chunk, error_4;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 11, , 12]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                _a = req.body || {}, fileName = _a.fileName, mimeType = _a.mimeType;
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _b.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                tempDir = "music/temp/".concat(user.userId, "/").concat(trackId);
                return [4 /*yield*/, bucket.getFiles({ prefix: tempDir })];
            case 3:
                chunks = (_b.sent())[0];
                if (chunks.length === 0) {
                    return [2 /*return*/, res.status(400).json({ error: 'No chunks found' })];
                }
                // Sort chunks by index
                chunks.sort(function (a, b) {
                    var indexA = parseInt(a.name.split('_').pop() || '0');
                    var indexB = parseInt(b.name.split('_').pop() || '0');
                    return indexA - indexB;
                });
                finalAudioPath = "music/".concat(user.userId, "/tracks/").concat(trackId, ".").concat((fileName === null || fileName === void 0 ? void 0 : fileName.split('.').pop()) || 'mp3');
                finalAudioRef = bucket.file(finalAudioPath);
                firstChunk = chunks[0];
                return [4 /*yield*/, firstChunk.download()];
            case 4:
                chunkData = (_b.sent())[0];
                return [4 /*yield*/, finalAudioRef.save(chunkData, {
                        contentType: mimeType || 'audio/mpeg'
                    })];
            case 5:
                _b.sent();
                audioURL = "https://storage.googleapis.com/".concat(bucket.name, "/").concat(finalAudioPath);
                // Update track status
                return [4 /*yield*/, trackRef.update({
                        audioURL: audioURL,
                        status: 'processing',
                        processingStartedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                        transcodingStatus: 'in_progress'
                    })];
            case 6:
                // Update track status
                _b.sent();
                _i = 0, chunks_1 = chunks;
                _b.label = 7;
            case 7:
                if (!(_i < chunks_1.length)) return [3 /*break*/, 10];
                chunk = chunks_1[_i];
                return [4 /*yield*/, chunk.delete()];
            case 8:
                _b.sent();
                _b.label = 9;
            case 9:
                _i++;
                return [3 /*break*/, 7];
            case 10:
                res.json({
                    trackId: trackId,
                    audioURL: audioURL,
                    status: 'processing',
                    message: 'Upload complete. Transcoding in progress.'
                });
                return [3 /*break*/, 12];
            case 11:
                error_4 = _b.sent();
                console.error('Complete upload error:', error_4);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 12];
            case 12: return [2 /*return*/];
        }
    });
}); });
// POST /v1/music/tracks/:trackId/artwork - Upload artwork
app.post('/v1/music/tracks/:trackId/artwork', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, _a, artworkData, mimeType, trackRef, trackSnap, trackData, artworkPath, artworkRef, buffer, artworkURL, error_5;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 5, , 6]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                _a = req.body || {}, artworkData = _a.artworkData, mimeType = _a.mimeType;
                if (!artworkData || typeof artworkData !== 'string') {
                    return [2 /*return*/, res.status(400).json({ error: 'artworkData is required' })];
                }
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _b.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                artworkPath = "music/".concat(user.userId, "/artwork/").concat(trackId, ".jpg");
                artworkRef = bucket.file(artworkPath);
                buffer = Buffer.from(artworkData, 'base64');
                return [4 /*yield*/, artworkRef.save(buffer, {
                        contentType: mimeType || 'image/jpeg'
                    })];
            case 3:
                _b.sent();
                artworkURL = "https://storage.googleapis.com/".concat(bucket.name, "/").concat(artworkPath);
                // Update track with artwork URL
                return [4 /*yield*/, trackRef.update({
                        artworkURL: artworkURL,
                        artworkUploadedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                    })];
            case 4:
                // Update track with artwork URL
                _b.sent();
                res.json({
                    trackId: trackId,
                    artworkURL: artworkURL,
                    message: 'Artwork uploaded successfully'
                });
                return [3 /*break*/, 6];
            case 5:
                error_5 = _b.sent();
                console.error('Artwork upload error:', error_5);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 6];
            case 6: return [2 /*return*/];
        }
    });
}); });
// GET /v1/music/tracks/:trackId/status - Check upload/processing status
app.get('/v1/music/tracks/:trackId/status', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, trackRef, trackSnap, trackData, error_6;
    var _a;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 3, , 4]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _b.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                res.json({
                    trackId: trackId,
                    status: trackData.status,
                    transcodingStatus: trackData.transcodingStatus,
                    audioURL: trackData.audioURL,
                    artworkURL: trackData.artworkURL,
                    streamCount: trackData.streamCount || 0,
                    likeCount: trackData.likeCount || 0,
                    createdAt: (_a = trackData.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
                });
                return [3 /*break*/, 4];
            case 3:
                error_6 = _b.sent();
                console.error('Get status error:', error_6);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 4];
            case 4: return [2 /*return*/];
        }
    });
}); });
// GET /v1/music/tracks - List artist's tracks
app.get('/v1/music/tracks', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, _a, limit, status_1, query, tracksSnap, tracks, error_7;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 3, , 4]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                _a = req.query || {}, limit = _a.limit, status_1 = _a.status;
                query = db.collection('music_tracks')
                    .where('artistId', '==', user.userId)
                    .orderBy('createdAt', 'desc')
                    .limit(parseInt(limit) || 50);
                if (status_1) {
                    query = query.where('status', '==', status_1);
                }
                return [4 /*yield*/, query.get()];
            case 2:
                tracksSnap = _b.sent();
                tracks = tracksSnap.docs.map(function (doc) {
                    var _a;
                    var data = doc.data();
                    return {
                        id: doc.id,
                        title: data.title,
                        artistName: data.artistName,
                        albumName: data.albumName,
                        genre: data.genre,
                        isExplicit: data.isExplicit,
                        artworkURL: data.artworkURL,
                        audioURL: data.audioURL,
                        status: data.status,
                        transcodingStatus: data.transcodingStatus,
                        streamCount: data.streamCount || 0,
                        likeCount: data.likeCount || 0,
                        createdAt: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
                    };
                });
                res.json({
                    tracks: tracks,
                    total: tracksSnap.size
                });
                return [3 /*break*/, 4];
            case 3:
                error_7 = _b.sent();
                console.error('List tracks error:', error_7);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 4];
            case 4: return [2 /*return*/];
        }
    });
}); });
// PUT /v1/music/tracks/:trackId/publish - Publish track (make it live)
app.put('/v1/music/tracks/:trackId/publish', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, trackRef, trackSnap, trackData, error_8;
    return __generator(this, function (_a) {
        switch (_a.label) {
            case 0:
                _a.trys.push([0, 4, , 5]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _a.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _a.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                if (!trackData.audioURL) {
                    return [2 /*return*/, res.status(400).json({ error: 'Audio must be uploaded before publishing' })];
                }
                return [4 /*yield*/, trackRef.update({
                        status: 'published',
                        publishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                        isPublished: true
                    })];
            case 3:
                _a.sent();
                res.json({
                    trackId: trackId,
                    status: 'published',
                    message: 'Track published successfully'
                });
                return [3 /*break*/, 5];
            case 4:
                error_8 = _a.sent();
                console.error('Publish track error:', error_8);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 5];
            case 5: return [2 /*return*/];
        }
    });
}); });
// PUT /v1/music/tracks/:trackId - Edit track metadata
app.put('/v1/music/tracks/:trackId', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, _a, title, artistName, albumName, genre, isExplicit, trackRef, trackSnap, trackData, updates, error_9;
    return __generator(this, function (_b) {
        switch (_b.label) {
            case 0:
                _b.trys.push([0, 4, , 5]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _b.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                _a = req.body || {}, title = _a.title, artistName = _a.artistName, albumName = _a.albumName, genre = _a.genre, isExplicit = _a.isExplicit;
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _b.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                updates = {};
                if (title !== undefined)
                    updates.title = title.trim();
                if (artistName !== undefined)
                    updates.artistName = artistName.trim();
                if (albumName !== undefined)
                    updates.albumName = albumName.trim();
                if (genre !== undefined)
                    updates.genre = genre.trim();
                if (isExplicit !== undefined)
                    updates.isExplicit = isExplicit;
                updates.updatedAt = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
                return [4 /*yield*/, trackRef.update(updates)];
            case 3:
                _b.sent();
                res.json({
                    trackId: trackId,
                    message: 'Track updated successfully'
                });
                return [3 /*break*/, 5];
            case 4:
                error_9 = _b.sent();
                console.error('Edit track error:', error_9);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 5];
            case 5: return [2 /*return*/];
        }
    });
}); });
// DELETE /v1/music/tracks/:trackId - Delete track
app.delete('/v1/music/tracks/:trackId', function (req, res) { return __awaiter(void 0, void 0, void 0, function () {
    var user, trackId, trackRef, trackSnap, trackData, audioFileName, audioFile, artworkFileName, artworkFile, error_10;
    return __generator(this, function (_a) {
        switch (_a.label) {
            case 0:
                _a.trys.push([0, 8, , 9]);
                return [4 /*yield*/, requireUser(req, res)];
            case 1:
                user = _a.sent();
                if (!user)
                    return [2 /*return*/];
                trackId = req.params.trackId;
                trackRef = db.collection('music_tracks').doc(trackId);
                return [4 /*yield*/, trackRef.get()];
            case 2:
                trackSnap = _a.sent();
                if (!trackSnap.exists) {
                    return [2 /*return*/, res.status(404).json({ error: 'Track not found' })];
                }
                trackData = trackSnap.data();
                if (String(trackData.artistId || '') !== user.userId) {
                    return [2 /*return*/, res.status(403).json({ error: 'Forbidden' })];
                }
                if (!trackData.audioURL) return [3 /*break*/, 4];
                audioFileName = trackData.audioURL.split('/').pop();
                if (!audioFileName) return [3 /*break*/, 4];
                audioFile = bucket.file("music/".concat(user.userId, "/tracks/").concat(audioFileName));
                return [4 /*yield*/, audioFile.delete().catch(function () { })];
            case 3:
                _a.sent();
                _a.label = 4;
            case 4:
                if (!trackData.artworkURL) return [3 /*break*/, 6];
                artworkFileName = trackData.artworkURL.split('/').pop();
                if (!artworkFileName) return [3 /*break*/, 6];
                artworkFile = bucket.file("music/".concat(user.userId, "/artwork/").concat(artworkFileName));
                return [4 /*yield*/, artworkFile.delete().catch(function () { })];
            case 5:
                _a.sent();
                _a.label = 6;
            case 6: 
            // Delete Firestore document
            return [4 /*yield*/, trackRef.delete()];
            case 7:
                // Delete Firestore document
                _a.sent();
                res.json({
                    trackId: trackId,
                    message: 'Track deleted successfully'
                });
                return [3 /*break*/, 9];
            case 8:
                error_10 = _a.sent();
                console.error('Delete track error:', error_10);
                res.status(500).json({ error: 'Internal server error' });
                return [3 /*break*/, 9];
            case 9: return [2 /*return*/];
        }
    });
}); });
var PORT = process.env.PORT || 8080;
app.listen(PORT, function () {
    console.log("\uD83C\uDFB5 Music service listening on port ".concat(PORT));
});
