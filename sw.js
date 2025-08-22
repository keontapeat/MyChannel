// MyChannel Service Worker
// Enables offline functionality and caching for better performance

const CACHE_NAME = 'mychannel-v1.0.4';
const STATIC_CACHE = 'mychannel-static-v5';
const DYNAMIC_CACHE = 'mychannel-dynamic-v5';

// Files to cache for offline functionality
const STATIC_FILES = [
    '/',
    '/app.html',
    '/auth.html',
    '/dashboard.html',
    '/upload.html',
    '/video-player.html',
    '/manifest.json',
    '/firebase-config.js',
    '/flicks.html',
    '/flicks.js',
    // Add your image assets
    '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
    '/assets/UserProfileAvatar.imageset/UserProfileAvatar.PNG'
];

// Network-first strategy for API calls
const NETWORK_FIRST = [
    '/api/',
    'firestore.googleapis.com',
    'firebase.googleapis.com',
    'googleapis.com'
];

// Cache-first strategy for static assets
const CACHE_FIRST = [
    '.css',
    '.js',
    '.png',
    '.jpg',
    '.jpeg',
    '.svg',
    '.woff',
    '.woff2'
];

// Install event - cache static files
self.addEventListener('install', (event) => {
    console.log('🔧 Service Worker installing...');
    
    event.waitUntil(
        caches.open(STATIC_CACHE)
            .then((cache) => {
                console.log('📦 Caching static files');
                return cache.addAll(STATIC_FILES);
            })
            .then(() => {
                console.log('✅ Static files cached successfully');
                return self.skipWaiting();
            })
            .catch((error) => {
                console.error('❌ Failed to cache static files:', error);
            })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('🚀 Service Worker activating...');
    
    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames.map((cacheName) => {
                        if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
                            console.log('🗑️ Deleting old cache:', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            })
            .then(() => {
                console.log('✅ Service Worker activated');
                return self.clients.claim();
            })
    );
});

// Fetch event - handle network requests
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);
    
    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }
    
    // Skip Chrome extensions
    if (url.protocol === 'chrome-extension:') {
        return;
    }
    
    event.respondWith(handleRequest(request));
});

async function handleRequest(request) {
    const url = new URL(request.url);
    
    try {
        // Network-first strategy for API calls
        if (NETWORK_FIRST.some(pattern => url.href.includes(pattern))) {
            return await networkFirst(request);
        }
        
        // Cache-first strategy for static assets
        if (CACHE_FIRST.some(ext => url.pathname.endsWith(ext))) {
            return await cacheFirst(request);
        }
        
        // Stale-while-revalidate for HTML pages
        if (request.headers.get('accept').includes('text/html')) {
            return await networkFirst(request);
        }
        
        // Default: network first with cache fallback
        return await networkFirst(request);
        
    } catch (error) {
        console.error('Fetch error:', error);
        return await cacheFirst(request);
    }
}

// Network-first strategy
async function networkFirst(request) {
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            // Cache successful responses
            const cache = await caches.open(DYNAMIC_CACHE);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        // Network failed, try cache
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            return cachedResponse;
        }
        
        // Return offline page for HTML requests
        if (request.headers.get('accept').includes('text/html')) {
            return caches.match('/app.html');
        }
        
        throw error;
    }
}

// Cache-first strategy
async function cacheFirst(request) {
    const cachedResponse = await caches.match(request);
    
    if (cachedResponse) {
        return cachedResponse;
    }
    
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            const cache = await caches.open(DYNAMIC_CACHE);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.error('Network and cache failed for:', request.url);
        throw error;
    }
}

// Stale-while-revalidate strategy
async function staleWhileRevalidate(request) {
    const cache = await caches.open(DYNAMIC_CACHE);
    const cachedResponse = await cache.match(request);
    
    // Fetch in background to update cache
    const fetchPromise = fetch(request).then((networkResponse) => {
        if (networkResponse.ok) {
            cache.put(request, networkResponse.clone());
        }
        return networkResponse;
    });
    
    // Return cached version immediately if available
    return cachedResponse || fetchPromise;
}

// Background sync for offline uploads
self.addEventListener('sync', (event) => {
    console.log('🔄 Background sync triggered:', event.tag);
    
    if (event.tag === 'upload-video') {
        event.waitUntil(handleOfflineUpload());
    }
});

async function handleOfflineUpload() {
    try {
        // Get pending uploads from IndexedDB
        const pendingUploads = await getPendingUploads();
        
        for (const upload of pendingUploads) {
            try {
                await uploadVideo(upload);
                await removePendingUpload(upload.id);
                
                // Notify user of successful upload
                self.registration.showNotification('Upload Complete', {
                    body: `"${upload.title}" has been uploaded successfully!`,
                    icon: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
                    badge: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
                    tag: 'upload-complete'
                });
                
            } catch (error) {
                console.error('Failed to upload:', upload.title, error);
            }
        }
    } catch (error) {
        console.error('Background sync error:', error);
    }
}

// Push notifications
self.addEventListener('push', (event) => {
    console.log('📬 Push notification received');
    
    const options = {
        body: 'You have new activity on MyChannel!',
        icon: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
        badge: '/assets/MyChannel.imageset/MyChannelLaunch.PNG',
        vibrate: [200, 100, 200],
        tag: 'mychannel-notification',
        actions: [
            {
                action: 'view',
                title: 'View',
                icon: '/assets/MyChannel.imageset/MyChannelLaunch.PNG'
            },
            {
                action: 'dismiss',
                title: 'Dismiss'
            }
        ]
    };
    
    if (event.data) {
        const data = event.data.json();
        options.body = data.body || options.body;
        options.title = data.title || 'MyChannel';
    }
    
    event.waitUntil(
        self.registration.showNotification('MyChannel', options)
    );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
    console.log('🔔 Notification clicked:', event.action);
    
    event.notification.close();
    
    if (event.action === 'view') {
        event.waitUntil(
            clients.openWindow('/app.html')
        );
    }
});

// Utility functions for IndexedDB operations
async function getPendingUploads() {
    // This would integrate with IndexedDB to get pending uploads
    // For now, return empty array
    return [];
}

async function removePendingUpload(id) {
    // This would remove the upload from IndexedDB
    console.log('Removing pending upload:', id);
}

async function uploadVideo(upload) {
    // This would handle the actual video upload
    console.log('Uploading video:', upload.title);
    
    // Simulate upload
    return new Promise((resolve) => {
        setTimeout(resolve, 1000);
    });
}

// Performance monitoring
self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'PERFORMANCE_MEASURE') {
        console.log('📊 Performance measure:', event.data.name, event.data.duration + 'ms');
    }
});

console.log('🎬 MyChannel Service Worker loaded successfully!');
console.log('📦 Caching strategy: Network-first for APIs, Cache-first for assets');
console.log('🔄 Background sync enabled for offline uploads');
console.log('📬 Push notifications ready');
