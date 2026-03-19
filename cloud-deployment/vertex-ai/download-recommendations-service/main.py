from flask import Flask, request, jsonify
from google.cloud import firestore
import vertexai
from vertexai.generative_models import GenerativeModel
import os
from datetime import datetime, timedelta
import numpy as np

app = Flask(__name__)

PROJECT_ID = os.environ.get('GCP_PROJECT', 'mychannel-ca26d')
LOCATION = 'us-central1'

vertexai.init(project=PROJECT_ID, location=LOCATION)
db = firestore.Client(project=PROJECT_ID)
model = GenerativeModel('gemini-1.5-flash')

@app.route('/recommend-downloads', methods=['POST'])
def recommend_downloads():
    """
    ML-powered download recommendations based on:
    - User watch history
    - Download patterns
    - Offline viewing habits
    - Video characteristics (duration, engagement)
    """
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        limit = data.get('limit', 10)
        context = data.get('context', 'downloads')
        include_offline_suitable = data.get('include_offline_suitable', True)
        
        if not user_id:
            return jsonify({'error': 'user_id required'}), 400
        
        # Get user profile and preferences
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            return jsonify({'error': 'User not found'}), 404
        
        user_data = user_doc.to_dict()
        
        # Get user's watch history
        watch_history = list(db.collection('users').document(user_id)
                           .collection('watch_history')
                           .order_by('timestamp', direction=firestore.Query.DESCENDING)
                           .limit(50)
                           .stream())
        
        # Get user's download history
        download_history = list(db.collection('users').document(user_id)
                              .collection('downloads_history')
                              .order_by('timestamp', direction=firestore.Query.DESCENDING)
                              .limit(30)
                              .stream())
        
        # Get existing downloads to avoid duplicates
        existing_downloads = list(db.collection('users').document(user_id)
                                .collection('downloads')
                                .stream())
        existing_video_ids = {d.to_dict().get('videoId') for d in existing_downloads}
        
        # Analyze user preferences
        watched_categories = {}
        watched_creators = {}
        avg_watch_duration = []
        
        for watch in watch_history:
            watch_data = watch.to_dict()
            category = watch_data.get('category', 'general')
            creator_id = watch_data.get('creatorId')
            watch_time = watch_data.get('watchTime', 0)
            duration = watch_data.get('duration', 1)
            
            watched_categories[category] = watched_categories.get(category, 0) + 1
            watched_creators[creator_id] = watched_creators.get(creator_id, 0) + 1
            avg_watch_duration.append(watch_time / duration if duration > 0 else 0)
        
        # Calculate user's average completion rate
        avg_completion_rate = np.mean(avg_watch_duration) if avg_watch_duration else 0.5
        
        # Get candidate videos for download recommendations
        videos_ref = db.collection('videos')
        
        # Filter criteria for offline-suitable content
        query = videos_ref
        
        if include_offline_suitable:
            # Prefer videos between 5-30 minutes (good for offline viewing)
            query = query.where('duration', '>=', 300).where('duration', '<=', 1800)
        
        candidate_videos = list(query.limit(100).stream())
        
        recommendations = []
        
        for video_doc in candidate_videos:
            video_data = video_doc.to_dict()
            video_id = video_doc.id
            
            # Skip if already downloaded
            if video_id in existing_video_ids:
                continue
            
            # Calculate recommendation score
            score = 0.0
            reason = []
            
            # Category match
            video_category = video_data.get('category', 'general')
            if video_category in watched_categories:
                category_weight = watched_categories[video_category] / len(watch_history)
                score += category_weight * 0.3
                reason.append(f"Matches your interest in {video_category}")
            
            # Creator match
            creator_id = video_data.get('creatorId')
            if creator_id in watched_creators:
                creator_weight = watched_creators[creator_id] / len(watch_history)
                score += creator_weight * 0.25
                reason.append(f"From creator you watch")
            
            # Duration suitability for offline
            duration = video_data.get('duration', 0)
            if 300 <= duration <= 1800:  # 5-30 minutes
                score += 0.2
                reason.append("Perfect length for offline viewing")
            elif duration < 300:
                score += 0.1
            
            # Engagement metrics
            view_count = video_data.get('viewCount', 0)
            like_count = video_data.get('likeCount', 0)
            engagement_rate = like_count / view_count if view_count > 0 else 0
            
            if engagement_rate > 0.05:  # 5% engagement is good
                score += 0.15
                reason.append("Highly engaging content")
            
            # Recency bonus
            created_at = video_data.get('createdAt')
            if created_at:
                days_old = (datetime.now() - created_at.replace(tzinfo=None)).days
                if days_old < 7:
                    score += 0.1
                    reason.append("Recent upload")
            
            # Quality score based on user's completion rate
            if avg_completion_rate > 0.7:
                # User watches videos fully, recommend longer content
                if duration > 600:
                    score += 0.1
            
            if score > 0.3:  # Minimum threshold
                recommendations.append({
                    'video_id': video_id,
                    'title': video_data.get('title', ''),
                    'channel_name': video_data.get('channelName', ''),
                    'channel_id': video_data.get('channelId', ''),
                    'thumbnail_url': video_data.get('thumbnailUrl', ''),
                    'duration': duration,
                    'view_count': view_count,
                    'score': round(score, 3),
                    'reason': ' • '.join(reason[:2]) if reason else 'Recommended for you'
                })
        
        # Sort by score and limit
        recommendations.sort(key=lambda x: x['score'], reverse=True)
        recommendations = recommendations[:limit]
        
        return jsonify({
            'recommendations': recommendations,
            'user_completion_rate': round(avg_completion_rate, 2),
            'total_candidates': len(candidate_videos),
            'ml_version': '2.0'
        })
        
    except Exception as e:
        print(f"Error in recommend_downloads: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/track-download', methods=['POST'])
def track_download():
    """Track download events for ML learning"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        video_id = data.get('video_id')
        quality = data.get('quality')
        action = data.get('action', 'download')
        
        if not user_id or not video_id:
            return jsonify({'error': 'user_id and video_id required'}), 400
        
        # Store download event
        event_data = {
            'userId': user_id,
            'videoId': video_id,
            'quality': quality,
            'action': action,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'platform': 'ios'
        }
        
        db.collection('ml_events').document('downloads').collection('events').add(event_data)
        
        # Update user download preferences
        user_ref = db.collection('users').document(user_id)
        user_ref.update({
            'lastDownloadDate': firestore.SERVER_TIMESTAMP,
            'totalDownloads': firestore.Increment(1)
        })
        
        return jsonify({
            'success': True,
            'message': 'Download tracked successfully'
        })
        
    except Exception as e:
        print(f"Error tracking download: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/update-download-preference', methods=['POST'])
def update_download_preference():
    """Update user's download preferences based on their behavior"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        video_id = data.get('video_id')
        
        if not user_id or not video_id:
            return jsonify({'error': 'user_id and video_id required'}), 400
        
        # Get video details
        video_ref = db.collection('videos').document(video_id)
        video_doc = video_ref.get()
        
        if not video_doc.exists:
            return jsonify({'error': 'Video not found'}), 404
        
        video_data = video_doc.to_dict()
        
        # Update user preferences
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        
        if user_doc.exists:
            preferences = user_doc.to_dict().get('downloadPreferences', {})
            
            # Track preferred categories
            category = video_data.get('category', 'general')
            categories = preferences.get('categories', {})
            categories[category] = categories.get(category, 0) + 1
            
            # Track preferred duration ranges
            duration = video_data.get('duration', 0)
            duration_range = 'short' if duration < 300 else 'medium' if duration < 1800 else 'long'
            durations = preferences.get('durations', {})
            durations[duration_range] = durations.get(duration_range, 0) + 1
            
            preferences['categories'] = categories
            preferences['durations'] = durations
            preferences['lastUpdated'] = firestore.SERVER_TIMESTAMP
            
            user_ref.update({'downloadPreferences': preferences})
        
        return jsonify({
            'success': True,
            'message': 'Preferences updated'
        })
        
    except Exception as e:
        print(f"Error updating preferences: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'download-recommendations'}), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
