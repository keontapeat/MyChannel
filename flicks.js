// Simple Shorts-style vertical swiper with preloading and double-tap like
(function(){
  const videos = [
    // Use sample portrait-friendly demo sources (replace with Storage URLs later)
    // If no MP4s in repo, we can use the same placeholder mp4 URL multiple times
    // or simply loop an image video via inline mp4 test asset
    'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4'
  ];

  const state = {
    idx: 0,
    muted: true,
    isDragging: false,
    startY: 0,
    deltaY: 0,
    likeTimeout: null,
    lastTap: 0
  };

  const prevEl = document.getElementById('prev');
  const currEl = document.getElementById('curr');
  const nextEl = document.getElementById('next');
  const muteBtn = document.getElementById('muteBtn');
  const likeBtn = document.getElementById('likeBtn');
  const shareBtn = document.getElementById('shareBtn');
  const touchLayer = document.getElementById('touchLayer');
  const heart = document.getElementById('heart');
  const title = document.getElementById('title');
  const desc = document.getElementById('desc');

  function clamp(n, min, max){ return Math.max(min, Math.min(max, n)); }
  function srcAt(i){ const n = (i + videos.length) % videos.length; return videos[n]; }

  function loadAround(){
    prevEl.src = srcAt(state.idx - 1);
    currEl.src = srcAt(state.idx);
    nextEl.src = srcAt(state.idx + 1);
    [prevEl, currEl, nextEl].forEach(v => { v.loop = true; v.muted = state.muted; });
    currEl.play().catch(()=>{});
    title.textContent = `Flick ${state.idx+1}/${videos.length}`;
    desc.textContent = 'Swipe up/down • Double‑tap to like';
  }

  function animateHeart(){
    heart.classList.add('show');
    clearTimeout(state.likeTimeout);
    state.likeTimeout = setTimeout(()=> heart.classList.remove('show'), 650);
  }

  function onDoubleTap(){ animateHeart(); }

  muteBtn.addEventListener('click', () => {
    state.muted = !state.muted;
    [prevEl, currEl, nextEl].forEach(v => v.muted = state.muted);
    muteBtn.textContent = state.muted ? '🔇' : '🔊';
    if (!state.muted) currEl.play().catch(()=>{});
  });

  likeBtn.addEventListener('click', animateHeart);
  shareBtn.addEventListener('click', async () => {
    try {
      await navigator.share?.({ title: document.title, url: location.href });
    } catch {}
  });

  // Gesture handling
  const threshold = 60; // px to trigger navigation
  function onStart(y){ state.isDragging = true; state.startY = y; state.deltaY = 0; }
  function onMove(y){ if(!state.isDragging) return; state.deltaY = y - state.startY; }
  function onEnd(){
    if(!state.isDragging) return; state.isDragging = false;
    const dy = state.deltaY; state.deltaY = 0;
    if (Math.abs(dy) > threshold){
      if (dy < 0){ // up → next
        state.idx = (state.idx + 1) % videos.length;
      } else {
        state.idx = (state.idx - 1 + videos.length) % videos.length;
      }
      loadAround();
    }
  }

  // Touch + mouse events
  touchLayer.addEventListener('touchstart', e => {
    if (e.touches.length === 1){
      const now = Date.now();
      if (now - state.lastTap < 280) onDoubleTap();
      state.lastTap = now;
      onStart(e.touches[0].clientY);
    }
  }, {passive:true});
  touchLayer.addEventListener('touchmove', e => onMove(e.touches[0].clientY), {passive:true});
  touchLayer.addEventListener('touchend', onEnd);
  touchLayer.addEventListener('mousedown', e => onStart(e.clientY));
  window.addEventListener('mousemove', e => onMove(e.clientY));
  window.addEventListener('mouseup', onEnd);

  // Init
  loadAround();
})();


