/**
 * VPAID 2.0 Wrapper (YouTube/Google Ad Manager Level)
 * 
 * Video Player-Ad Interface Definition for interactive video ads.
 * Enables two-way communication between video player and ad unit.
 * 
 * Spec: https://iabtechlab.com/standards/vpaid/
 */

/**
 * Generate VPAID 2.0 JavaScript wrapper.
 * @param {object} ad - Ad creative
 * @param {object} config - VPAID configuration
 * @returns {string} VPAID JavaScript code
 */
export function generateVPAID(ad, config = {}) {
  const {
    adId = ad.id || 'vpaid-ad',
    vastUrl = ad.vast_url,
    clickThrough = ad.click_url,
    tracking = {},
    interactive = false,
    expandable = false
  } = config

  return `
(function() {
  'use strict';
  
  /**
   * VPAID 2.0 Creative
   * IAB Standard for interactive video ads
   */
  var VPAIDCreative = function() {
    this.slot_ = null;
    this.videoSlot_ = null;
    this.eventsCallbacks_ = {};
    this.attributes_ = {
      companions: '',
      desiredBitrate: 256,
      duration: ${ad.duration_sec || 30},
      expanded: false,
      height: ${ad.height || 1080},
      icons: '',
      linear: true,
      skippableState: ${ad.skippable || false},
      viewMode: 'normal',
      width: ${ad.width || 1920},
      volume: 1.0
    };
    this.quartileEvents_ = [
      { event: 'AdVideoStart', value: 0 },
      { event: 'AdVideoFirstQuartile', value: 25 },
      { event: 'AdVideoMidpoint', value: 50 },
      { event: 'AdVideoThirdQuartile', value: 75 },
      { event: 'AdVideoComplete', value: 100 }
    ];
    this.nextQuartileIndex_ = 0;
    this.videoElement_ = null;
  };

  /**
   * VPAID Required Methods
   */
  
  VPAIDCreative.prototype.handshakeVersion = function(version) {
    return '2.0';
  };

  VPAIDCreative.prototype.initAd = function(width, height, viewMode, desiredBitrate, creativeData, environmentVars) {
    this.attributes_.width = width;
    this.attributes_.height = height;
    this.attributes_.viewMode = viewMode;
    this.attributes_.desiredBitrate = desiredBitrate;
    this.slot_ = environmentVars.slot;
    this.videoSlot_ = environmentVars.videoSlot;
    
    this.log_('initAd', { width, height, viewMode });
    this.callEvent_('AdLoaded');
  };

  VPAIDCreative.prototype.startAd = function() {
    this.log_('startAd');
    
    if (this.attributes_.linear) {
      this.createVideoElement_();
      this.loadVideo_();
    } else {
      this.createOverlay_();
    }
    
    this.callEvent_('AdStarted');
    this.callEvent_('AdImpression');
    this.trackEvent_('impression');
  };

  VPAIDCreative.prototype.stopAd = function() {
    this.log_('stopAd');
    
    if (this.videoElement_) {
      this.videoElement_.pause();
      this.videoElement_.src = '';
    }
    
    this.callEvent_('AdStopped');
  };

  VPAIDCreative.prototype.skipAd = function() {
    this.log_('skipAd');
    
    if (this.attributes_.skippableState) {
      this.trackEvent_('skip');
      this.callEvent_('AdSkipped');
      this.stopAd();
    }
  };

  VPAIDCreative.prototype.resizeAd = function(width, height, viewMode) {
    this.log_('resizeAd', { width, height, viewMode });
    
    this.attributes_.width = width;
    this.attributes_.height = height;
    this.attributes_.viewMode = viewMode;
    
    if (this.videoElement_) {
      this.videoElement_.style.width = width + 'px';
      this.videoElement_.style.height = height + 'px';
    }
    
    this.callEvent_('AdSizeChange');
  };

  VPAIDCreative.prototype.pauseAd = function() {
    this.log_('pauseAd');
    
    if (this.videoElement_) {
      this.videoElement_.pause();
    }
    
    this.callEvent_('AdPaused');
    this.trackEvent_('pause');
  };

  VPAIDCreative.prototype.resumeAd = function() {
    this.log_('resumeAd');
    
    if (this.videoElement_) {
      this.videoElement_.play();
    }
    
    this.callEvent_('AdPlaying');
    this.trackEvent_('resume');
  };

  VPAIDCreative.prototype.expandAd = function() {
    this.log_('expandAd');
    
    if (${expandable}) {
      this.attributes_.expanded = true;
      this.callEvent_('AdExpandedChange');
      this.trackEvent_('expand');
    }
  };

  VPAIDCreative.prototype.collapseAd = function() {
    this.log_('collapseAd');
    
    if (this.attributes_.expanded) {
      this.attributes_.expanded = false;
      this.callEvent_('AdExpandedChange');
      this.trackEvent_('collapse');
    }
  };

  /**
   * VPAID Getters
   */
  
  VPAIDCreative.prototype.getAdLinear = function() {
    return this.attributes_.linear;
  };

  VPAIDCreative.prototype.getAdWidth = function() {
    return this.attributes_.width;
  };

  VPAIDCreative.prototype.getAdHeight = function() {
    return this.attributes_.height;
  };

  VPAIDCreative.prototype.getAdExpanded = function() {
    return this.attributes_.expanded;
  };

  VPAIDCreative.prototype.getAdSkippableState = function() {
    return this.attributes_.skippableState;
  };

  VPAIDCreative.prototype.getAdRemainingTime = function() {
    if (this.videoElement_) {
      return this.videoElement_.duration - this.videoElement_.currentTime;
    }
    return this.attributes_.duration;
  };

  VPAIDCreative.prototype.getAdDuration = function() {
    return this.attributes_.duration;
  };

  VPAIDCreative.prototype.getAdVolume = function() {
    if (this.videoElement_) {
      return this.videoElement_.volume;
    }
    return this.attributes_.volume;
  };

  VPAIDCreative.prototype.setAdVolume = function(volume) {
    this.attributes_.volume = volume;
    
    if (this.videoElement_) {
      this.videoElement_.volume = volume;
    }
    
    if (volume === 0) {
      this.callEvent_('AdVolumeChange');
      this.trackEvent_('mute');
    } else {
      this.callEvent_('AdVolumeChange');
      this.trackEvent_('unmute');
    }
  };

  VPAIDCreative.prototype.getAdCompanions = function() {
    return this.attributes_.companions;
  };

  VPAIDCreative.prototype.getAdIcons = function() {
    return this.attributes_.icons;
  };

  /**
   * Event Subscription
   */
  
  VPAIDCreative.prototype.subscribe = function(callback, eventName, context) {
    this.log_('subscribe', eventName);
    
    var callbackObject = {
      callback: callback,
      context: context
    };
    
    if (!this.eventsCallbacks_[eventName]) {
      this.eventsCallbacks_[eventName] = [];
    }
    
    this.eventsCallbacks_[eventName].push(callbackObject);
  };

  VPAIDCreative.prototype.unsubscribe = function(callback, eventName) {
    this.log_('unsubscribe', eventName);
    
    var callbacks = this.eventsCallbacks_[eventName];
    if (callbacks) {
      for (var i = callbacks.length - 1; i >= 0; i--) {
        if (callbacks[i].callback === callback) {
          callbacks.splice(i, 1);
        }
      }
    }
  };

  /**
   * Internal Methods
   */
  
  VPAIDCreative.prototype.createVideoElement_ = function() {
    this.videoElement_ = document.createElement('video');
    this.videoElement_.style.width = this.attributes_.width + 'px';
    this.videoElement_.style.height = this.attributes_.height + 'px';
    this.videoElement_.style.position = 'absolute';
    this.videoElement_.style.top = '0';
    this.videoElement_.style.left = '0';
    
    // Event listeners
    this.videoElement_.addEventListener('timeupdate', this.onTimeUpdate_.bind(this));
    this.videoElement_.addEventListener('ended', this.onVideoEnded_.bind(this));
    this.videoElement_.addEventListener('error', this.onVideoError_.bind(this));
    this.videoElement_.addEventListener('click', this.onVideoClick_.bind(this));
    
    this.slot_.appendChild(this.videoElement_);
  };

  VPAIDCreative.prototype.loadVideo_ = function() {
    this.videoElement_.src = '${ad.uri || ad.video_url}';
    this.videoElement_.load();
    this.videoElement_.play();
  };

  VPAIDCreative.prototype.createOverlay_ = function() {
    var overlay = document.createElement('div');
    overlay.style.width = this.attributes_.width + 'px';
    overlay.style.height = this.attributes_.height + 'px';
    overlay.style.position = 'absolute';
    overlay.style.top = '0';
    overlay.style.left = '0';
    overlay.style.cursor = 'pointer';
    overlay.innerHTML = '<img src="${ad.overlay_url || ''}" style="width:100%;height:100%;">';
    overlay.addEventListener('click', this.onVideoClick_.bind(this));
    
    this.slot_.appendChild(overlay);
  };

  VPAIDCreative.prototype.onTimeUpdate_ = function() {
    var currentTime = this.videoElement_.currentTime;
    var duration = this.videoElement_.duration;
    var percent = (currentTime / duration) * 100;
    
    // Check quartile events
    if (this.nextQuartileIndex_ < this.quartileEvents_.length) {
      var nextQuartile = this.quartileEvents_[this.nextQuartileIndex_];
      if (percent >= nextQuartile.value) {
        this.callEvent_(nextQuartile.event);
        this.trackEvent_(nextQuartile.event.toLowerCase().replace('advideo', ''));
        this.nextQuartileIndex_++;
      }
    }
    
    this.callEvent_('AdRemainingTimeChange');
  };

  VPAIDCreative.prototype.onVideoEnded_ = function() {
    this.callEvent_('AdVideoComplete');
    this.trackEvent_('complete');
    this.stopAd();
  };

  VPAIDCreative.prototype.onVideoError_ = function(e) {
    this.log_('Video error', e);
    this.callEvent_('AdError');
    this.trackEvent_('error');
  };

  VPAIDCreative.prototype.onVideoClick_ = function() {
    this.callEvent_('AdClickThru');
    this.trackEvent_('click');
    
    if ('${clickThrough}') {
      window.open('${clickThrough}', '_blank');
    }
  };

  VPAIDCreative.prototype.callEvent_ = function(eventName) {
    var callbacks = this.eventsCallbacks_[eventName];
    if (callbacks) {
      for (var i = 0; i < callbacks.length; i++) {
        callbacks[i].callback.call(callbacks[i].context);
      }
    }
  };

  VPAIDCreative.prototype.trackEvent_ = function(eventName) {
    var trackingUrl = ${JSON.stringify(tracking)}[eventName];
    if (trackingUrl) {
      var img = new Image();
      img.src = trackingUrl;
    }
  };

  VPAIDCreative.prototype.log_ = function(message, data) {
    if (console && console.log) {
      console.log('[VPAID ${adId}]', message, data || '');
    }
  };

  /**
   * Return VPAID interface
   */
  var getVPAIDAd = function() {
    return new VPAIDCreative();
  };

  // Export for different module systems
  if (typeof define === 'function' && define.amd) {
    define([], function() { return getVPAIDAd; });
  } else if (typeof module === 'object' && module.exports) {
    module.exports = getVPAIDAd;
  } else {
    window.getVPAIDAd = getVPAIDAd;
  }
})();
`.trim()
}

/**
 * VPAID Events (IAB Standard)
 */
export const VPAID_EVENTS = {
  // Ad lifecycle
  AdLoaded: 'AdLoaded',
  AdStarted: 'AdStarted',
  AdStopped: 'AdStopped',
  AdSkipped: 'AdSkipped',
  AdError: 'AdError',
  
  // Ad interaction
  AdClickThru: 'AdClickThru',
  AdUserAcceptInvitation: 'AdUserAcceptInvitation',
  AdUserMinimize: 'AdUserMinimize',
  AdUserClose: 'AdUserClose',
  
  // Ad state changes
  AdPaused: 'AdPaused',
  AdPlaying: 'AdPlaying',
  AdSizeChange: 'AdSizeChange',
  AdExpandedChange: 'AdExpandedChange',
  AdSkippableStateChange: 'AdSkippableStateChange',
  AdDurationChange: 'AdDurationChange',
  AdRemainingTimeChange: 'AdRemainingTimeChange',
  AdVolumeChange: 'AdVolumeChange',
  AdImpression: 'AdImpression',
  
  // Video events
  AdVideoStart: 'AdVideoStart',
  AdVideoFirstQuartile: 'AdVideoFirstQuartile',
  AdVideoMidpoint: 'AdVideoMidpoint',
  AdVideoThirdQuartile: 'AdVideoThirdQuartile',
  AdVideoComplete: 'AdVideoComplete',
  
  // Linear change
  AdLinearChange: 'AdLinearChange',
  
  // Interaction
  AdInteraction: 'AdInteraction'
}

/**
 * Validate VPAID creative.
 */
export function validateVPAID(vpaidCode) {
  const requiredMethods = [
    'handshakeVersion',
    'initAd',
    'startAd',
    'stopAd',
    'skipAd',
    'resizeAd',
    'pauseAd',
    'resumeAd',
    'expandAd',
    'collapseAd',
    'getAdLinear',
    'getAdWidth',
    'getAdHeight',
    'getAdExpanded',
    'getAdSkippableState',
    'getAdRemainingTime',
    'getAdDuration',
    'getAdVolume',
    'setAdVolume',
    'getAdCompanions',
    'getAdIcons',
    'subscribe',
    'unsubscribe'
  ]
  
  const errors = []
  
  for (const method of requiredMethods) {
    if (!vpaidCode.includes(method)) {
      errors.push(`Missing required method: ${method}`)
    }
  }
  
  if (!vpaidCode.includes('getVPAIDAd')) {
    errors.push('Missing getVPAIDAd function')
  }
  
  return {
    isValid: errors.length === 0,
    errors
  }
}
