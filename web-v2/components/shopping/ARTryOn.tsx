// AR Try-On Component - Professional Implementation
'use client';

import { useState, useRef, useEffect } from 'react';
import type { Product } from '@/types/shopping';

interface ARTryOnProps {
  product: Product;
  onClose: () => void;
  onAddToCart: () => void;
}

export default function ARTryOn({ product, onClose, onAddToCart }: ARTryOnProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [screenshots, setScreenshots] = useState<string[]>([]);
  const [cameraActive, setCameraActive] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    startCamera();
    return () => {
      stopCamera();
    };
  }, []);

  async function startCamera() {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });

      setStream(mediaStream);
      setCameraActive(true);

      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
      }
    } catch (err) {
      console.error('Error accessing camera:', err);
      setError('Failed to access camera. Please grant camera permissions.');
    }
  }

  function stopCamera() {
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
      setStream(null);
      setCameraActive(false);
    }
  }

  function takeScreenshot() {
    if (!videoRef.current || !canvasRef.current) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    const context = canvas.getContext('2d');

    if (!context) return;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    context.drawImage(video, 0, 0, canvas.width, canvas.height);

    const screenshot = canvas.toDataURL('image/png');
    setScreenshots([...screenshots, screenshot]);
  }

  function deleteScreenshot(index: number) {
    setScreenshots(screenshots.filter((_, i) => i !== index));
  }

  function downloadScreenshot(screenshot: string, index: number) {
    const link = document.createElement('a');
    link.href = screenshot;
    link.download = `ar-tryon-${product.name}-${index + 1}.png`;
    link.click();
  }

  function handleAddToCart() {
    // Save AR session data
    const sessionData = {
      productId: product.id,
      screenshots,
      timestamp: new Date().toISOString(),
    };
    localStorage.setItem('ar-session', JSON.stringify(sessionData));

    onAddToCart();
    onClose();
  }

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="w-full max-w-6xl bg-[rgb(var(--color-surface))] rounded-xl overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-[rgb(var(--color-border))]">
          <div>
            <h2 className="text-[24px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">
              AR Try-On
            </h2>
            <p className="text-[14px] text-[rgb(var(--color-text-secondary))]">
              {product.name}
            </p>
          </div>
          <button
            onClick={onClose}
            className="w-10 h-10 rounded-lg bg-[rgb(var(--color-background))] flex items-center justify-center hover:bg-[rgb(var(--color-surface-hover))] transition-all"
          >
            <svg className="w-6 h-6 text-[rgb(var(--color-text-primary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          {error ? (
            <div className="text-center py-12">
              <svg className="w-16 h-16 mx-auto mb-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <p className="text-[15px] text-red-500 mb-4">{error}</p>
              <button
                onClick={startCamera}
                className="px-6 py-3 rounded-lg bg-[rgb(var(--color-primary))] text-white text-[15px] font-semibold hover:opacity-90 transition-all"
              >
                Try Again
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Camera View */}
              <div className="lg:col-span-2">
                <div className="relative aspect-video bg-black rounded-xl overflow-hidden">
                  <video
                    ref={videoRef}
                    autoPlay
                    playsInline
                    muted
                    className="w-full h-full object-cover"
                  />
                  <canvas ref={canvasRef} className="hidden" />

                  {/* Camera Status */}
                  {cameraActive && (
                    <div className="absolute top-4 left-4 flex items-center gap-2 px-3 py-1.5 rounded-lg bg-black/60 backdrop-blur-sm">
                      <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                      <span className="text-[13px] text-white font-medium">Camera Active</span>
                    </div>
                  )}

                  {/* AR Overlay Guide */}
                  <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                    <div className="w-64 h-64 border-2 border-white/30 rounded-full" />
                  </div>

                  {/* Controls */}
                  <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex items-center gap-3">
                    <button
                      onClick={takeScreenshot}
                      className="w-16 h-16 rounded-full bg-white border-4 border-white/50 hover:scale-110 transition-all"
                    >
                      <div className="w-full h-full rounded-full bg-red-500" />
                    </button>
                  </div>
                </div>

                {/* Instructions */}
                <div className="mt-4 p-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))]">
                  <div className="flex items-start gap-3">
                    <svg className="w-5 h-5 text-blue-500 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                    </svg>
                    <div>
                      <h3 className="text-[15px] font-semibold text-[rgb(var(--color-text-primary))] mb-1">
                        How to use AR Try-On
                      </h3>
                      <ul className="text-[14px] text-[rgb(var(--color-text-secondary))] space-y-1">
                        <li>• Position your face in the center circle</li>
                        <li>• Tap the red button to take a photo</li>
                        <li>• Try different angles and lighting</li>
                        <li>• Add to cart when you're satisfied</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>

              {/* Screenshots & Actions */}
              <div className="lg:col-span-1">
                {/* Product Info */}
                <div className="p-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] mb-4">
                  <img
                    src={product.imageURL}
                    alt={product.name}
                    className="w-full aspect-square rounded-lg object-cover mb-3"
                  />
                  <h3 className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-2">
                    {product.name}
                  </h3>
                  <div className="text-[24px] font-semibold text-[rgb(var(--color-text-primary))]">
                    ${product.price.toFixed(2)}
                  </div>
                </div>

                {/* Screenshots */}
                <div className="mb-4">
                  <h3 className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">
                    Your Photos ({screenshots.length})
                  </h3>
                  {screenshots.length === 0 ? (
                    <div className="text-center py-8 px-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))]">
                      <svg className="w-12 h-12 mx-auto mb-3 text-[rgb(var(--color-text-secondary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                      <p className="text-[14px] text-[rgb(var(--color-text-secondary))]">
                        No photos yet
                      </p>
                    </div>
                  ) : (
                    <div className="space-y-2 max-h-[400px] overflow-y-auto scrollbar-hide">
                      {screenshots.map((screenshot, index) => (
                        <div
                          key={index}
                          className="relative group rounded-lg overflow-hidden border border-[rgb(var(--color-border))]"
                        >
                          <img
                            src={screenshot}
                            alt={`Screenshot ${index + 1}`}
                            className="w-full aspect-square object-cover"
                          />
                          <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                            <button
                              onClick={() => downloadScreenshot(screenshot, index)}
                              className="w-10 h-10 rounded-lg bg-white/20 backdrop-blur-sm flex items-center justify-center hover:bg-white/30 transition-all"
                            >
                              <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                              </svg>
                            </button>
                            <button
                              onClick={() => deleteScreenshot(index)}
                              className="w-10 h-10 rounded-lg bg-red-500/80 backdrop-blur-sm flex items-center justify-center hover:bg-red-500 transition-all"
                            >
                              <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                              </svg>
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Action Buttons */}
                <div className="space-y-2">
                  <button
                    onClick={handleAddToCart}
                    disabled={screenshots.length === 0}
                    className="w-full px-6 py-3 rounded-lg bg-[rgb(var(--color-primary))] text-white text-[15px] font-semibold hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                  >
                    Add to Cart
                  </button>
                  <button
                    onClick={onClose}
                    className="w-full px-6 py-3 rounded-lg bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] text-[rgb(var(--color-text-primary))] text-[15px] font-semibold hover:border-[rgb(var(--color-text-secondary))]/30 transition-all"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}


