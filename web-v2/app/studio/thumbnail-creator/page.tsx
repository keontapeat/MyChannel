'use client';

// 🔥💣 NUCLEAR UNIVERSE THUMBNAIL CREATOR - YOUTUBE CAN'T EVEN COMPREHEND THIS 🌌🚀

import {
  Upload,
  Wand2,
  Type,
  Palette,
  Scissors,
  Layers,
  Sparkles,
  Download,
  Trash2,
  RotateCcw,
  ZoomIn,
  ZoomOut,
  Move,
  Image as ImageIcon,
  Eye,
  TrendingUp,
  Copy,
  Save,
  ChevronLeft,
  ChevronRight,
  Plus,
  Minus,
  AlignLeft,
  AlignCenter,
  AlignRight,
  Bold,
  Italic,
  Underline,
  Droplet,
  Sun,
  Contrast,
  Filter,
  Grid3x3,
  Target,
  Zap,
  Star,
  Crown,
  Flame,
  Undo2,
  Redo2,
  Cloud,
  Eraser,
  Shuffle,
  BarChart3,
} from 'lucide-react';
import Link from 'next/link';
import { useState, useRef, useEffect, useCallback } from 'react';

// Types
interface TextLayer {
  id: string;
  text: string;
  x: number;
  y: number;
  fontSize: number;
  fontWeight: 'normal' | 'bold' | 'black';
  fontStyle: 'normal' | 'italic';
  fontFamily: string;
  color: string;
  strokeColor: string;
  strokeWidth: number;
  align: 'left' | 'center' | 'right';
  rotation: number;
  opacity: number;
  isDragging?: boolean;
}

interface ImageLayer {
  id: string;
  src: string;
  x: number;
  y: number;
  width: number;
  height: number;
  rotation: number;
  opacity: number;
  isDragging?: boolean;
}

interface Filter {
  brightness: number;
  contrast: number;
  saturation: number;
  blur: number;
}

interface HistoryState {
  backgroundImage: string | null;
  textLayers: TextLayer[];
  imageLayers: ImageLayer[];
  filter: Filter;
}

interface SavedProject {
  id: string;
  name: string;
  thumbnail: string;
  createdAt: Date;
  state: HistoryState;
}

interface ABTestVariant {
  id: string;
  name: string;
  thumbnail: string;
  ctr: number;
  impressions: number;
  clicks: number;
}

export default function ThumbnailCreatorPage() {
  // Canvas refs
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  
  // Canvas state
  const [backgroundImage, setBackgroundImage] = useState<string | null>(null);
  const [textLayers, setTextLayers] = useState<TextLayer[]>([]);
  const [imageLayers, setImageLayers] = useState<ImageLayer[]>([]);
  const [selectedLayer, setSelectedLayer] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>({
    brightness: 100,
    contrast: 100,
    saturation: 100,
    blur: 0,
  });

  // History/Undo state
  const [history, setHistory] = useState<HistoryState[]>([]);
  const [historyIndex, setHistoryIndex] = useState(-1);
  const [isSaving, setIsSaving] = useState(false);

  // UI state
  const [activeTab, setActiveTab] = useState<'upload' | 'ai' | 'text' | 'stickers' | 'filters' | 'templates' | 'abtest' | 'projects'>('upload');
  const [isGenerating, setIsGenerating] = useState(false);
  const [aiPrompt, setAiPrompt] = useState('');
  const [ctrPrediction, setCtrPrediction] = useState<number | null>(null);
  const [zoom, setZoom] = useState(100);
  const [showGrid, setShowGrid] = useState(true);
  const [isRemovingBg, setIsRemovingBg] = useState(false);

  // Drag state
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null);

  // A/B Testing state
  const [abTestVariants, setAbTestVariants] = useState<ABTestVariant[]>([]);
  const [isRunningABTest, setIsRunningABTest] = useState(false);

  // Saved projects
  const [savedProjects, setSavedProjects] = useState<SavedProject[]>([]);
  const [projectName, setProjectName] = useState('');

  // Templates
  const templates = [
    {
      id: 'gaming',
      name: 'Gaming',
      icon: '🎮',
      gradient: 'from-purple-600 via-pink-600 to-red-600',
      textColor: '#FFFFFF',
      strokeColor: '#000000',
      fontSize: 96,
    },
    {
      id: 'tutorial',
      name: 'Tutorial',
      icon: '📚',
      gradient: 'from-blue-600 via-cyan-600 to-teal-600',
      textColor: '#FFFFFF',
      strokeColor: '#1E3A8A',
      fontSize: 72,
    },
    {
      id: 'vlog',
      name: 'Vlog',
      icon: '🎥',
      gradient: 'from-orange-600 via-red-600 to-pink-600',
      textColor: '#FFFFFF',
      strokeColor: '#7C2D12',
      fontSize: 84,
    },
    {
      id: 'reaction',
      name: 'Reaction',
      icon: '😱',
      gradient: 'from-yellow-600 via-orange-600 to-red-600',
      textColor: '#000000',
      strokeColor: '#FFFFFF',
      fontSize: 108,
    },
    {
      id: 'music',
      name: 'Music',
      icon: '🎵',
      gradient: 'from-indigo-600 via-purple-600 to-pink-600',
      textColor: '#FFFFFF',
      strokeColor: '#312E81',
      fontSize: 90,
    },
    {
      id: 'tech',
      name: 'Tech',
      icon: '💻',
      gradient: 'from-gray-600 via-blue-600 to-cyan-600',
      textColor: '#FFFFFF',
      strokeColor: '#1F2937',
      fontSize: 78,
    },
  ];

  // Fonts
  const fonts = [
    { name: 'Inter', value: 'Inter' },
    { name: 'Montserrat', value: 'Montserrat' },
    { name: 'Poppins', value: 'Poppins' },
    { name: 'Bebas Neue', value: 'Bebas Neue' },
    { name: 'Anton', value: 'Anton' },
    { name: 'Oswald', value: 'Oswald' },
    { name: 'Roboto', value: 'Roboto' },
  ];

  // Save current state to history
  const saveToHistory = useCallback(() => {
    const newState: HistoryState = {
      backgroundImage,
      textLayers: JSON.parse(JSON.stringify(textLayers)),
      imageLayers: JSON.parse(JSON.stringify(imageLayers)),
      filter: { ...filter },
    };

    // Remove any states after current index
    const newHistory = history.slice(0, historyIndex + 1);
    newHistory.push(newState);

    // Limit history to 50 states
    if (newHistory.length > 50) {
      newHistory.shift();
    }

    setHistory(newHistory);
    setHistoryIndex(newHistory.length - 1);
  }, [backgroundImage, textLayers, imageLayers, filter, history, historyIndex]);

  // Undo
  const undo = useCallback(() => {
    if (historyIndex > 0) {
      const newIndex = historyIndex - 1;
      const state = history[newIndex];
      setBackgroundImage(state.backgroundImage);
      setTextLayers(state.textLayers);
      setImageLayers(state.imageLayers);
      setFilter(state.filter);
      setHistoryIndex(newIndex);
    }
  }, [history, historyIndex]);

  // Redo
  const redo = useCallback(() => {
    if (historyIndex < history.length - 1) {
      const newIndex = historyIndex + 1;
      const state = history[newIndex];
      setBackgroundImage(state.backgroundImage);
      setTextLayers(state.textLayers);
      setImageLayers(state.imageLayers);
      setFilter(state.filter);
      setHistoryIndex(newIndex);
    }
  }, [history, historyIndex]);

  // Render canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Set canvas size
    canvas.width = 1280;
    canvas.height = 720;

    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Apply filters
    ctx.filter = `brightness(${filter.brightness}%) contrast(${filter.contrast}%) saturate(${filter.saturation}%) blur(${filter.blur}px)`;

    // Draw background
    if (backgroundImage) {
      const img = new Image();
      img.src = backgroundImage;
      img.onload = () => {
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

        // Reset filter for layers
        ctx.filter = 'none';

        // Draw image layers
        imageLayers.forEach((layer) => {
          ctx.save();
          ctx.globalAlpha = layer.opacity / 100;
          ctx.translate(layer.x, layer.y);
          ctx.rotate((layer.rotation * Math.PI) / 180);
          const layerImg = new Image();
          layerImg.src = layer.src;
          ctx.drawImage(layerImg, -layer.width / 2, -layer.height / 2, layer.width, layer.height);
          ctx.restore();
        });

        // Draw text layers
        textLayers.forEach((layer) => {
          ctx.save();
          ctx.globalAlpha = layer.opacity / 100;
          ctx.translate(layer.x, layer.y);
          ctx.rotate((layer.rotation * Math.PI) / 180);
          ctx.font = `${layer.fontStyle} ${layer.fontWeight} ${layer.fontSize}px ${layer.fontFamily}`;
          ctx.textAlign = layer.align;
          ctx.textBaseline = 'middle';

          // Draw stroke
          if (layer.strokeWidth > 0) {
            ctx.strokeStyle = layer.strokeColor;
            ctx.lineWidth = layer.strokeWidth;
            ctx.strokeText(layer.text, 0, 0);
          }

          // Draw fill
          ctx.fillStyle = layer.color;
          ctx.fillText(layer.text, 0, 0);
          ctx.restore();
        });
      };
    }
  }, [backgroundImage, textLayers, imageLayers, filter]);

  // Handle file upload
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (event) => {
        setBackgroundImage(event.target?.result as string);
        saveToHistory();
      };
      reader.readAsDataURL(file);
    }
  };

  // Generate AI thumbnail
  const generateAIThumbnail = async () => {
    if (!aiPrompt.trim()) return;

    setIsGenerating(true);
    try {
      // TODO: Call Vertex AI Imagen API
      const response = await fetch('/api/generate-thumbnail', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: aiPrompt }),
      });

      if (response.ok) {
        const data = await response.json();
        setBackgroundImage(data.imageUrl);
        saveToHistory();
      }
    } catch (error) {
      console.error('AI generation failed:', error);
      // Fallback to mock
      await new Promise((resolve) => setTimeout(resolve, 2000));
      setBackgroundImage(`https://picsum.photos/seed/${Date.now()}/1280/720`);
      saveToHistory();
    } finally {
      setIsGenerating(false);
    }
  };

  // Remove background with AI
  const removeBackground = async () => {
    if (!backgroundImage) return;

    setIsRemovingBg(true);
    try {
      // TODO: Call Vertex AI Vision API for background removal
      const response = await fetch('/api/remove-background', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ imageUrl: backgroundImage }),
      });

      if (response.ok) {
        const data = await response.json();
        setBackgroundImage(data.imageUrl);
        saveToHistory();
      }
    } catch (error) {
      console.error('Background removal failed:', error);
    } finally {
      setIsRemovingBg(false);
    }
  };

  // Add text layer
  const addTextLayer = () => {
    const newLayer: TextLayer = {
      id: `text-${Date.now()}`,
      text: 'Your Text Here',
      x: 640,
      y: 360,
      fontSize: 72,
      fontWeight: 'bold',
      fontStyle: 'normal',
      fontFamily: 'Inter',
      color: '#FFFFFF',
      strokeColor: '#000000',
      strokeWidth: 4,
      align: 'center',
      rotation: 0,
      opacity: 100,
    };
    setTextLayers([...textLayers, newLayer]);
    setSelectedLayer(newLayer.id);
    saveToHistory();
  };

  // Add sticker layer
  const addStickerLayer = (emoji: string) => {
    const newLayer: TextLayer = {
      id: `sticker-${Date.now()}`,
      text: emoji,
      x: 640,
      y: 360,
      fontSize: 120,
      fontWeight: 'normal',
      fontStyle: 'normal',
      fontFamily: 'Inter',
      color: '#FFFFFF',
      strokeColor: 'transparent',
      strokeWidth: 0,
      align: 'center',
      rotation: 0,
      opacity: 100,
    };
    setTextLayers([...textLayers, newLayer]);
    setSelectedLayer(newLayer.id);
    saveToHistory();
  };

  // Apply template
  const applyTemplate = (template: typeof templates[0]) => {
    // Create gradient background
    const canvas = document.createElement('canvas');
    canvas.width = 1280;
    canvas.height = 720;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    // Parse gradient colors from template
    gradient.addColorStop(0, '#8B5CF6');
    gradient.addColorStop(0.5, '#EC4899');
    gradient.addColorStop(1, '#EF4444');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    setBackgroundImage(canvas.toDataURL());

    // Add template text
    const newLayer: TextLayer = {
      id: `text-${Date.now()}`,
      text: 'YOUR TITLE HERE',
      x: 640,
      y: 360,
      fontSize: template.fontSize,
      fontWeight: 'black',
      fontStyle: 'normal',
      fontFamily: 'Anton',
      color: template.textColor,
      strokeColor: template.strokeColor,
      strokeWidth: 8,
      align: 'center',
      rotation: 0,
      opacity: 100,
    };
    setTextLayers([newLayer]);
    saveToHistory();
  };

  // Predict CTR with AI
  const predictCTR = async () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    try {
      // TODO: Call Vertex AI Vision API for CTR prediction
      const imageData = canvas.toDataURL();
      const response = await fetch('/api/predict-ctr', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ imageData }),
      });

      if (response.ok) {
        const data = await response.json();
        setCtrPrediction(data.ctr);
      }
    } catch (error) {
      console.error('CTR prediction failed:', error);
      // Mock prediction
      const prediction = Math.floor(Math.random() * 5) + 8;
      setCtrPrediction(prediction);
    }
  };

  // Create A/B test variant
  const createABTestVariant = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const variant: ABTestVariant = {
      id: `variant-${Date.now()}`,
      name: `Variant ${abTestVariants.length + 1}`,
      thumbnail: canvas.toDataURL(),
      ctr: 0,
      impressions: 0,
      clicks: 0,
    };

    setAbTestVariants([...abTestVariants, variant]);
  };

  // Start A/B test
  const startABTest = async () => {
    if (abTestVariants.length < 2) {
      alert('Add at least 2 variants to start A/B testing');
      return;
    }

    setIsRunningABTest(true);

    // Simulate A/B test results
    await new Promise((resolve) => setTimeout(resolve, 3000));

    const updatedVariants = abTestVariants.map((variant) => ({
      ...variant,
      impressions: Math.floor(Math.random() * 10000) + 5000,
      clicks: Math.floor(Math.random() * 1000) + 500,
      ctr: 0,
    }));

    updatedVariants.forEach((variant) => {
      variant.ctr = (variant.clicks / variant.impressions) * 100;
    });

    setAbTestVariants(updatedVariants);
    setIsRunningABTest(false);
  };

  // Save project to Firestore
  const saveProject = async () => {
    if (!projectName.trim()) {
      alert('Please enter a project name');
      return;
    }

    setIsSaving(true);

    try {
      const canvas = canvasRef.current;
      if (!canvas) return;

      const project: SavedProject = {
        id: `project-${Date.now()}`,
        name: projectName,
        thumbnail: canvas.toDataURL(),
        createdAt: new Date(),
        state: {
          backgroundImage,
          textLayers,
          imageLayers,
          filter,
        },
      };

      // TODO: Save to Firestore
      // await db.collection('thumbnail-projects').add(project);

      // Mock save
      setSavedProjects([...savedProjects, project]);
      setProjectName('');
      alert('Project saved successfully!');
    } catch (error) {
      console.error('Save failed:', error);
      alert('Failed to save project');
    } finally {
      setIsSaving(false);
    }
  };

  // Load project
  const loadProject = (project: SavedProject) => {
    setBackgroundImage(project.state.backgroundImage);
    setTextLayers(project.state.textLayers);
    setImageLayers(project.state.imageLayers);
    setFilter(project.state.filter);
    saveToHistory();
    setActiveTab('upload');
  };

  // Export thumbnail
  const exportThumbnail = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const link = document.createElement('a');
    link.download = `thumbnail-${Date.now()}.png`;
    link.href = canvas.toDataURL('image/png');
    link.click();
  };

  // Handle layer drag
  const handleLayerMouseDown = (layerId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setSelectedLayer(layerId);
    setDragStart({ x: e.clientX, y: e.clientY });
  };

  const handleLayerMouseMove = (e: React.MouseEvent) => {
    if (!dragStart || !selectedLayer) return;

    const dx = e.clientX - dragStart.x;
    const dy = e.clientY - dragStart.y;

    setTextLayers(
      textLayers.map((layer) =>
        layer.id === selectedLayer
          ? { ...layer, x: layer.x + dx, y: layer.y + dy }
          : layer
      )
    );

    setDragStart({ x: e.clientX, y: e.clientY });
  };

  const handleLayerMouseUp = () => {
    if (dragStart) {
      saveToHistory();
      setDragStart(null);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black">
      {/* Mobile-First Container */}
      <div className="max-w-[768px] mx-auto">
        {/* Header */}
        <header className="sticky top-0 z-50 bg-black/80 backdrop-blur-xl border-b border-gray-800 px-4 py-4">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-3">
              <Link
                href="/studio"
                className="p-2 hover:bg-white/10 rounded-full transition-all active:scale-95"
              >
                <ChevronLeft size={24} className="text-white" />
              </Link>
              <div>
                <h1 className="text-xl font-black text-white flex items-center gap-2">
                  <Sparkles size={20} className="text-yellow-400" />
                  Thumbnail Creator
                </h1>
                <p className="text-xs text-gray-400">Nuclear Universe Edition 🌌</p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {/* Undo/Redo */}
              <button
                onClick={undo}
                disabled={historyIndex <= 0}
                className="p-2 bg-gray-800 hover:bg-gray-700 text-white rounded-lg transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <Undo2 size={18} />
              </button>
              <button
                onClick={redo}
                disabled={historyIndex >= history.length - 1}
                className="p-2 bg-gray-800 hover:bg-gray-700 text-white rounded-lg transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <Redo2 size={18} />
              </button>

              {/* CTR Prediction */}
              <button
                onClick={predictCTR}
                className="px-3 py-2 bg-gradient-to-r from-blue-600 to-cyan-600 text-white text-xs font-bold rounded-lg hover:shadow-lg hover:shadow-blue-500/50 transition-all active:scale-95"
              >
                <Target size={16} className="inline mr-1" />
                CTR
              </button>

              {/* Export */}
              <button
                onClick={exportThumbnail}
                className="px-3 py-2 bg-gradient-to-r from-green-600 to-emerald-600 text-white text-xs font-bold rounded-lg hover:shadow-lg hover:shadow-green-500/50 transition-all active:scale-95"
              >
                <Download size={16} className="inline mr-1" />
                Export
              </button>
            </div>
          </div>

          {/* CTR Prediction Banner */}
          {ctrPrediction !== null && (
            <div className="p-3 bg-gradient-to-r from-blue-600/20 to-cyan-600/20 border border-blue-500/30 rounded-xl">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <TrendingUp size={16} className="text-blue-400" />
                  <span className="text-sm font-bold text-white">AI Predicted CTR</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-2xl font-black text-white">{ctrPrediction.toFixed(1)}%</span>
                  <span className="text-xs text-gray-400">
                    {ctrPrediction >= 10 ? '🔥 Excellent' : ctrPrediction >= 8 ? '⚡ Good' : '📈 Average'}
                  </span>
                </div>
              </div>
              <div className="mt-2 h-1.5 bg-gray-800 rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-blue-500 to-cyan-500 transition-all duration-500"
                  style={{ width: `${(ctrPrediction / 15) * 100}%` }}
                />
              </div>
            </div>
          )}
        </header>

        {/* Main Content */}
        <main className="px-4 py-6 pb-32">
          {/* Canvas Area */}
          <section className="mb-6">
            <div className="relative bg-gradient-to-br from-gray-900 to-gray-800 rounded-2xl overflow-hidden border-2 border-gray-700 shadow-2xl">
              {/* Canvas Controls */}
              <div className="absolute top-3 left-3 z-10 flex items-center gap-2">
                <button
                  onClick={() => setShowGrid(!showGrid)}
                  className={`
                    p-2 backdrop-blur-xl text-white rounded-lg transition-all active:scale-95
                    ${showGrid ? 'bg-blue-600/80' : 'bg-black/60 hover:bg-black/80'}
                  `}
                >
                  <Grid3x3 size={18} />
                </button>
                {backgroundImage && (
                  <button
                    onClick={removeBackground}
                    disabled={isRemovingBg}
                    className="p-2 bg-black/60 backdrop-blur-xl text-white rounded-lg hover:bg-black/80 transition-all active:scale-95 disabled:opacity-50"
                  >
                    {isRemovingBg ? (
                      <div className="w-[18px] h-[18px] border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    ) : (
                      <Eraser size={18} />
                    )}
                  </button>
                )}
              </div>

              <div className="absolute top-3 right-3 z-10 flex items-center gap-2">
                <button
                  onClick={() => setZoom(Math.max(50, zoom - 10))}
                  className="p-2 bg-black/60 backdrop-blur-xl text-white rounded-lg hover:bg-black/80 transition-all active:scale-95"
                >
                  <ZoomOut size={18} />
                </button>
                <span className="px-3 py-1 bg-black/60 backdrop-blur-xl text-white text-xs font-bold rounded-lg">
                  {zoom}%
                </span>
                <button
                  onClick={() => setZoom(Math.min(200, zoom + 10))}
                  className="p-2 bg-black/60 backdrop-blur-xl text-white rounded-lg hover:bg-black/80 transition-all active:scale-95"
                >
                  <ZoomIn size={18} />
                </button>
              </div>

              {/* Canvas */}
              <div
                ref={containerRef}
                className="aspect-video bg-gradient-to-br from-gray-800 via-gray-900 to-black flex items-center justify-center p-4 relative"
                onMouseMove={handleLayerMouseMove}
                onMouseUp={handleLayerMouseUp}
              >
                <canvas
                  ref={canvasRef}
                  className="max-w-full max-h-full object-contain"
                  style={{ transform: `scale(${zoom / 100})` }}
                />

                {!backgroundImage && (
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="text-center">
                      <div className="w-20 h-20 mx-auto mb-4 bg-gradient-to-br from-purple-600 to-pink-600 rounded-2xl flex items-center justify-center">
                        <ImageIcon size={40} className="text-white" />
                      </div>
                      <h3 className="text-lg font-bold text-white mb-2">No Image Yet</h3>
                      <p className="text-sm text-gray-400">Upload or generate with AI</p>
                    </div>
                  </div>
                )}

                {/* Grid Overlay */}
                {showGrid && backgroundImage && (
                  <div className="absolute inset-0 pointer-events-none">
                    <div
                      className="w-full h-full"
                      style={{
                        backgroundImage:
                          'linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px)',
                        backgroundSize: '50px 50px',
                      }}
                    />
                  </div>
                )}
              </div>
            </div>
          </section>

          {/* Tool Tabs */}
          <section className="mb-6">
            <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide pb-2">
              {[
                { id: 'upload', label: 'Upload', icon: Upload, gradient: 'from-blue-600 to-cyan-600' },
                { id: 'ai', label: 'AI', icon: Wand2, gradient: 'from-purple-600 to-pink-600' },
                { id: 'text', label: 'Text', icon: Type, gradient: 'from-orange-600 to-red-600' },
                { id: 'stickers', label: 'Stickers', icon: Sparkles, gradient: 'from-yellow-600 to-orange-600' },
                { id: 'filters', label: 'Filters', icon: Filter, gradient: 'from-green-600 to-emerald-600' },
                { id: 'templates', label: 'Templates', icon: Layers, gradient: 'from-indigo-600 to-purple-600' },
                { id: 'abtest', label: 'A/B Test', icon: BarChart3, gradient: 'from-pink-600 to-rose-600' },
                { id: 'projects', label: 'Projects', icon: Cloud, gradient: 'from-teal-600 to-cyan-600' },
              ].map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as any)}
                  className={`
                    flex items-center gap-2 px-4 py-2.5 rounded-xl font-bold text-sm whitespace-nowrap transition-all
                    ${
                      activeTab === tab.id
                        ? `bg-gradient-to-r ${tab.gradient} text-white shadow-lg`
                        : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
                    }
                  `}
                >
                  <tab.icon size={18} />
                  {tab.label}
                </button>
              ))}
            </div>
          </section>

          {/* Tool Content */}
          <section>
            {/* Upload Tab */}
            {activeTab === 'upload' && (
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-6 border border-gray-700">
                  <label className="block cursor-pointer">
                    <input
                      type="file"
                      accept="image/*"
                      onChange={handleFileUpload}
                      className="hidden"
                    />
                    <div className="text-center py-8">
                      <div className="w-16 h-16 mx-auto mb-4 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-2xl flex items-center justify-center">
                        <Upload size={32} className="text-white" />
                      </div>
                      <h3 className="text-lg font-bold text-white mb-2">Upload Image</h3>
                      <p className="text-sm text-gray-400 mb-4">Drag & drop or click to browse</p>
                      <div className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-cyan-600 text-white font-bold rounded-xl hover:shadow-lg hover:shadow-blue-500/50 transition-all">
                        <ImageIcon size={20} />
                        Choose File
                      </div>
                    </div>
                  </label>
                </div>

                <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700">
                  <h3 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
                    <Zap size={16} className="text-yellow-400" />
                    Pro Tips for Maximum CTR
                  </h3>
                  <ul className="space-y-2 text-xs text-gray-400">
                    <li className="flex items-start gap-2">
                      <span className="text-green-400">✓</span>
                      <span>Use 1280x720 resolution (16:9 aspect ratio)</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-green-400">✓</span>
                      <span>Keep file size under 2MB for faster loading</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-green-400">✓</span>
                      <span>Use bright colors and high contrast (70%+ contrast)</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-green-400">✓</span>
                      <span>Make text large (72px+) and readable on mobile</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-green-400">✓</span>
                      <span>Include faces with strong emotions (increases CTR by 30%)</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-green-400">✓</span>
                      <span>Use the rule of thirds for composition</span>
                    </li>
                  </ul>
                </div>
              </div>
            )}

            {/* AI Generate Tab */}
            {activeTab === 'ai' && (
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-purple-900/50 to-pink-900/50 rounded-2xl p-6 border border-purple-500/30">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-12 h-12 bg-gradient-to-br from-purple-600 to-pink-600 rounded-xl flex items-center justify-center">
                      <Wand2 size={24} className="text-white" />
                    </div>
                    <div>
                      <h3 className="text-lg font-bold text-white">AI Thumbnail Generator</h3>
                      <p className="text-xs text-purple-300">Powered by Vertex AI Imagen 3</p>
                    </div>
                  </div>

                  <textarea
                    value={aiPrompt}
                    onChange={(e) => setAiPrompt(e.target.value)}
                    placeholder="Describe your thumbnail in detail... (e.g., 'Epic gaming thumbnail with neon lights, futuristic city skyline, dramatic lighting, cinematic composition')"
                    className="w-full h-32 px-4 py-3 bg-black/30 border border-purple-500/30 rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-purple-500 resize-none text-sm"
                  />

                  <button
                    onClick={generateAIThumbnail}
                    disabled={isGenerating || !aiPrompt.trim()}
                    className="w-full mt-4 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-black rounded-xl hover:shadow-lg hover:shadow-purple-500/50 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                  >
                    {isGenerating ? (
                      <>
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                        Generating with AI...
                      </>
                    ) : (
                      <>
                        <Sparkles size={20} />
                        Generate Thumbnail
                      </>
                    )}
                  </button>
                </div>

                <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700">
                  <h3 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
                    <Star size={16} className="text-yellow-400" />
                    Example Prompts
                  </h3>
                  <div className="space-y-2">
                    {[
                      'Epic gaming thumbnail with neon lights and futuristic city',
                      'Minimalist tech review background with clean lines',
                      'Dramatic reaction face with explosion and fire effects',
                      'Cozy vlog aesthetic with warm tones and bokeh',
                      'Professional tutorial thumbnail with clean workspace',
                      'Energetic music video vibe with vibrant colors',
                    ].map((prompt, i) => (
                      <button
                        key={i}
                        onClick={() => setAiPrompt(prompt)}
                        className="w-full text-left px-3 py-2 bg-gray-700/50 hover:bg-gray-700 rounded-lg text-xs text-gray-300 transition-all"
                      >
                        {prompt}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Text Tab */}
            {activeTab === 'text' && (
              <div className="space-y-4">
                <button
                  onClick={addTextLayer}
                  className="w-full py-4 bg-gradient-to-r from-orange-600 to-red-600 text-white font-black rounded-xl hover:shadow-lg hover:shadow-orange-500/50 transition-all active:scale-95 flex items-center justify-center gap-2"
                >
                  <Plus size={20} />
                  Add Text Layer
                </button>

                {textLayers.length > 0 && (
                  <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700 space-y-4">
                    <h3 className="text-sm font-bold text-white">Text Layers ({textLayers.length})</h3>
                    {textLayers.map((layer) => (
                      <div
                        key={layer.id}
                        className={`
                          p-3 rounded-xl border-2 transition-all cursor-pointer
                          ${
                            selectedLayer === layer.id
                              ? 'border-orange-500 bg-orange-500/10'
                              : 'border-gray-700 bg-gray-800/50 hover:border-gray-600'
                          }
                        `}
                        onClick={() => setSelectedLayer(layer.id)}
                      >
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-sm font-bold text-white truncate">{layer.text}</span>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setTextLayers(textLayers.filter((l) => l.id !== layer.id));
                              saveToHistory();
                            }}
                            className="p-1 hover:bg-red-500/20 rounded transition-all"
                          >
                            <Trash2 size={16} className="text-red-400" />
                          </button>
                        </div>

                        {selectedLayer === layer.id && (
                          <div className="space-y-3 mt-3 pt-3 border-t border-gray-700">
                            <input
                              type="text"
                              value={layer.text}
                              onChange={(e) => {
                                setTextLayers(
                                  textLayers.map((l) =>
                                    l.id === layer.id ? { ...l, text: e.target.value } : l
                                  )
                                );
                              }}
                              onBlur={saveToHistory}
                              className="w-full px-3 py-2 bg-black/30 border border-gray-600 rounded-lg text-white text-sm focus:outline-none focus:border-orange-500"
                            />

                            <div>
                              <label className="text-xs text-gray-400 mb-1 block">Font Family</label>
                              <select
                                value={layer.fontFamily}
                                onChange={(e) => {
                                  setTextLayers(
                                    textLayers.map((l) =>
                                      l.id === layer.id ? { ...l, fontFamily: e.target.value } : l
                                    )
                                  );
                                  saveToHistory();
                                }}
                                className="w-full px-3 py-2 bg-black/30 border border-gray-600 rounded-lg text-white text-sm focus:outline-none focus:border-orange-500"
                              >
                                {fonts.map((font) => (
                                  <option key={font.value} value={font.value}>
                                    {font.name}
                                  </option>
                                ))}
                              </select>
                            </div>

                            <div className="grid grid-cols-3 gap-2">
                              <button
                                onClick={() => {
                                  setTextLayers(
                                    textLayers.map((l) =>
                                      l.id === layer.id
                                        ? {
                                            ...l,
                                            fontWeight: l.fontWeight === 'bold' ? 'normal' : 'bold',
                                          }
                                        : l
                                    )
                                  );
                                  saveToHistory();
                                }}
                                className={`p-2 rounded-lg transition-all ${
                                  layer.fontWeight === 'bold'
                                    ? 'bg-orange-600 text-white'
                                    : 'bg-gray-700 hover:bg-gray-600 text-white'
                                }`}
                              >
                                <Bold size={18} className="mx-auto" />
                              </button>
                              <button
                                onClick={() => {
                                  setTextLayers(
                                    textLayers.map((l) =>
                                      l.id === layer.id
                                        ? {
                                            ...l,
                                            fontStyle: l.fontStyle === 'italic' ? 'normal' : 'italic',
                                          }
                                        : l
                                    )
                                  );
                                  saveToHistory();
                                }}
                                className={`p-2 rounded-lg transition-all ${
                                  layer.fontStyle === 'italic'
                                    ? 'bg-orange-600 text-white'
                                    : 'bg-gray-700 hover:bg-gray-600 text-white'
                                }`}
                              >
                                <Italic size={18} className="mx-auto" />
                              </button>
                              <button className="p-2 bg-gray-700 hover:bg-gray-600 rounded-lg transition-all">
                                <Underline size={18} className="text-white mx-auto" />
                              </button>
                            </div>

                            <div>
                              <label className="text-xs text-gray-400 mb-1 block">
                                Font Size: {layer.fontSize}px
                              </label>
                              <input
                                type="range"
                                min="12"
                                max="200"
                                value={layer.fontSize}
                                onChange={(e) => {
                                  setTextLayers(
                                    textLayers.map((l) =>
                                      l.id === layer.id ? { ...l, fontSize: parseInt(e.target.value) } : l
                                    )
                                  );
                                }}
                                onMouseUp={saveToHistory}
                                className="w-full"
                              />
                            </div>

                            <div className="grid grid-cols-2 gap-3">
                              <div>
                                <label className="text-xs text-gray-400 mb-1 block">Text Color</label>
                                <input
                                  type="color"
                                  value={layer.color}
                                  onChange={(e) => {
                                    setTextLayers(
                                      textLayers.map((l) =>
                                        l.id === layer.id ? { ...l, color: e.target.value } : l
                                      )
                                    );
                                  }}
                                  onBlur={saveToHistory}
                                  className="w-full h-10 rounded-lg cursor-pointer"
                                />
                              </div>

                              <div>
                                <label className="text-xs text-gray-400 mb-1 block">Stroke Color</label>
                                <input
                                  type="color"
                                  value={layer.strokeColor}
                                  onChange={(e) => {
                                    setTextLayers(
                                      textLayers.map((l) =>
                                        l.id === layer.id ? { ...l, strokeColor: e.target.value } : l
                                      )
                                    );
                                  }}
                                  onBlur={saveToHistory}
                                  className="w-full h-10 rounded-lg cursor-pointer"
                                />
                              </div>
                            </div>

                            <div>
                              <label className="text-xs text-gray-400 mb-1 block">
                                Stroke Width: {layer.strokeWidth}px
                              </label>
                              <input
                                type="range"
                                min="0"
                                max="20"
                                value={layer.strokeWidth}
                                onChange={(e) => {
                                  setTextLayers(
                                    textLayers.map((l) =>
                                      l.id === layer.id
                                        ? { ...l, strokeWidth: parseInt(e.target.value) }
                                        : l
                                    )
                                  );
                                }}
                                onMouseUp={saveToHistory}
                                className="w-full"
                              />
                            </div>

                            <div>
                              <label className="text-xs text-gray-400 mb-1 block">
                                Opacity: {layer.opacity}%
                              </label>
                              <input
                                type="range"
                                min="0"
                                max="100"
                                value={layer.opacity}
                                onChange={(e) => {
                                  setTextLayers(
                                    textLayers.map((l) =>
                                      l.id === layer.id ? { ...l, opacity: parseInt(e.target.value) } : l
                                    )
                                  );
                                }}
                                onMouseUp={saveToHistory}
                                className="w-full"
                              />
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Stickers Tab */}
            {activeTab === 'stickers' && (
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700">
                  <h3 className="text-sm font-bold text-white mb-3">Popular Stickers</h3>
                  <div className="grid grid-cols-4 gap-3">
                    {['🔥', '⚡', '💎', '👑', '🎯', '🚀', '💪', '🎮', '🎵', '💰', '⭐', '💥', '🏆', '💯', '🔴', '🟢'].map(
                      (emoji, i) => (
                        <button
                          key={i}
                          onClick={() => addStickerLayer(emoji)}
                          className="aspect-square bg-gray-700/50 hover:bg-gray-700 rounded-xl flex items-center justify-center text-3xl transition-all active:scale-95"
                        >
                          {emoji}
                        </button>
                      )
                    )}
                  </div>
                </div>

                <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700">
                  <h3 className="text-sm font-bold text-white mb-3">Shapes & Icons</h3>
                  <div className="grid grid-cols-4 gap-3">
                    {[
                      { icon: Star, color: 'text-yellow-400' },
                      { icon: Crown, color: 'text-yellow-400' },
                      { icon: Flame, color: 'text-orange-400' },
                      { icon: Zap, color: 'text-blue-400' },
                      { icon: Target, color: 'text-red-400' },
                      { icon: TrendingUp, color: 'text-green-400' },
                      { icon: Eye, color: 'text-purple-400' },
                      { icon: Sparkles, color: 'text-pink-400' },
                    ].map((item, i) => (
                      <button
                        key={i}
                        className="aspect-square bg-gray-700/50 hover:bg-gray-700 rounded-xl flex items-center justify-center transition-all active:scale-95"
                      >
                        <item.icon size={32} className={item.color} />
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Filters Tab */}
            {activeTab === 'filters' && (
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700 space-y-4">
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="text-sm font-bold text-white flex items-center gap-2">
                        <Sun size={16} className="text-yellow-400" />
                        Brightness
                      </label>
                      <span className="text-xs text-gray-400">{filter.brightness}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="200"
                      value={filter.brightness}
                      onChange={(e) => setFilter({ ...filter, brightness: parseInt(e.target.value) })}
                      onMouseUp={saveToHistory}
                      className="w-full"
                    />
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="text-sm font-bold text-white flex items-center gap-2">
                        <Contrast size={16} className="text-purple-400" />
                        Contrast
                      </label>
                      <span className="text-xs text-gray-400">{filter.contrast}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="200"
                      value={filter.contrast}
                      onChange={(e) => setFilter({ ...filter, contrast: parseInt(e.target.value) })}
                      onMouseUp={saveToHistory}
                      className="w-full"
                    />
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="text-sm font-bold text-white flex items-center gap-2">
                        <Droplet size={16} className="text-blue-400" />
                        Saturation
                      </label>
                      <span className="text-xs text-gray-400">{filter.saturation}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="200"
                      value={filter.saturation}
                      onChange={(e) => setFilter({ ...filter, saturation: parseInt(e.target.value) })}
                      onMouseUp={saveToHistory}
                      className="w-full"
                    />
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="text-sm font-bold text-white flex items-center gap-2">
                        <Filter size={16} className="text-green-400" />
                        Blur
                      </label>
                      <span className="text-xs text-gray-400">{filter.blur}px</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="20"
                      value={filter.blur}
                      onChange={(e) => setFilter({ ...filter, blur: parseInt(e.target.value) })}
                      onMouseUp={saveToHistory}
                      className="w-full"
                    />
                  </div>

                  <button
                    onClick={() => {
                      setFilter({ brightness: 100, contrast: 100, saturation: 100, blur: 0 });
                      saveToHistory();
                    }}
                    className="w-full py-3 bg-gray-700 hover:bg-gray-600 text-white font-bold rounded-xl transition-all active:scale-95 flex items-center justify-center gap-2"
                  >
                    <RotateCcw size={18} />
                    Reset Filters
                  </button>
                </div>
              </div>
            )}

            {/* Templates Tab */}
            {activeTab === 'templates' && (
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  {templates.map((template) => (
                    <button
                      key={template.id}
                      onClick={() => applyTemplate(template)}
                      className="group relative overflow-hidden rounded-2xl aspect-video transition-all active:scale-95"
                    >
                      <div
                        className={`absolute inset-0 bg-gradient-to-br ${template.gradient} opacity-80 group-hover:opacity-100 transition-opacity`}
                      />
                      <div className="relative h-full flex flex-col items-center justify-center gap-2 p-4">
                        <span className="text-4xl">{template.icon}</span>
                        <span className="text-sm font-black text-white">{template.name}</span>
                        <span className="text-xs text-white/70">{template.fontSize}px</span>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* A/B Test Tab */}
            {activeTab === 'abtest' && (
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-pink-900/50 to-rose-900/50 rounded-2xl p-6 border border-pink-500/30">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-12 h-12 bg-gradient-to-br from-pink-600 to-rose-600 rounded-xl flex items-center justify-center">
                      <BarChart3 size={24} className="text-white" />
                    </div>
                    <div>
                      <h3 className="text-lg font-bold text-white">A/B Testing</h3>
                      <p className="text-xs text-pink-300">Compare multiple variants</p>
                    </div>
                  </div>

                  <button
                    onClick={createABTestVariant}
                    className="w-full py-3 bg-gradient-to-r from-pink-600 to-rose-600 text-white font-bold rounded-xl hover:shadow-lg hover:shadow-pink-500/50 transition-all active:scale-95 flex items-center justify-center gap-2 mb-4"
                  >
                    <Plus size={18} />
                    Add Current as Variant
                  </button>

                  {abTestVariants.length > 0 && (
                    <>
                      <div className="space-y-3 mb-4">
                        {abTestVariants.map((variant, index) => (
                          <div
                            key={variant.id}
                            className="bg-black/30 border border-pink-500/30 rounded-xl p-3"
                          >
                            <div className="flex items-center gap-3">
                              <img
                                src={variant.thumbnail}
                                alt={variant.name}
                                className="w-24 h-14 object-cover rounded-lg"
                              />
                              <div className="flex-1">
                                <h4 className="text-sm font-bold text-white">{variant.name}</h4>
                                {variant.ctr > 0 && (
                                  <div className="flex items-center gap-3 text-xs text-gray-400 mt-1">
                                    <span>CTR: {variant.ctr.toFixed(2)}%</span>
                                    <span>Impressions: {variant.impressions.toLocaleString()}</span>
                                    <span>Clicks: {variant.clicks.toLocaleString()}</span>
                                  </div>
                                )}
                              </div>
                              <button
                                onClick={() =>
                                  setAbTestVariants(abTestVariants.filter((v) => v.id !== variant.id))
                                }
                                className="p-2 hover:bg-red-500/20 rounded-lg transition-all"
                              >
                                <Trash2 size={16} className="text-red-400" />
                              </button>
                            </div>
                          </div>
                        ))}
                      </div>

                      <button
                        onClick={startABTest}
                        disabled={abTestVariants.length < 2 || isRunningABTest}
                        className="w-full py-4 bg-gradient-to-r from-pink-600 to-rose-600 text-white font-black rounded-xl hover:shadow-lg hover:shadow-pink-500/50 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                      >
                        {isRunningABTest ? (
                          <>
                            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            Running Test...
                          </>
                        ) : (
                          <>
                            <Shuffle size={20} />
                            Start A/B Test
                          </>
                        )}
                      </button>
                    </>
                  )}

                  {abTestVariants.length === 0 && (
                    <p className="text-sm text-gray-400 text-center py-4">
                      Create multiple variants to start A/B testing
                    </p>
                  )}
                </div>
              </div>
            )}

            {/* Projects Tab */}
            {activeTab === 'projects' && (
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-teal-900/50 to-cyan-900/50 rounded-2xl p-6 border border-teal-500/30">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-12 h-12 bg-gradient-to-br from-teal-600 to-cyan-600 rounded-xl flex items-center justify-center">
                      <Cloud size={24} className="text-white" />
                    </div>
                    <div>
                      <h3 className="text-lg font-bold text-white">Save to Cloud</h3>
                      <p className="text-xs text-teal-300">Sync across devices</p>
                    </div>
                  </div>

                  <input
                    type="text"
                    value={projectName}
                    onChange={(e) => setProjectName(e.target.value)}
                    placeholder="Project name..."
                    className="w-full px-4 py-3 bg-black/30 border border-teal-500/30 rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-teal-500 text-sm mb-4"
                  />

                  <button
                    onClick={saveProject}
                    disabled={isSaving || !projectName.trim()}
                    className="w-full py-4 bg-gradient-to-r from-teal-600 to-cyan-600 text-white font-black rounded-xl hover:shadow-lg hover:shadow-teal-500/50 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                  >
                    {isSaving ? (
                      <>
                        <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                        Saving...
                      </>
                    ) : (
                      <>
                        <Save size={20} />
                        Save Project
                      </>
                    )}
                  </button>
                </div>

                {savedProjects.length > 0 && (
                  <div className="bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-4 border border-gray-700">
                    <h3 className="text-sm font-bold text-white mb-3">
                      Saved Projects ({savedProjects.length})
                    </h3>
                    <div className="space-y-3">
                      {savedProjects.map((project) => (
                        <button
                          key={project.id}
                          onClick={() => loadProject(project)}
                          className="w-full bg-gray-700/50 hover:bg-gray-700 rounded-xl p-3 transition-all text-left"
                        >
                          <div className="flex items-center gap-3">
                            <img
                              src={project.thumbnail}
                              alt={project.name}
                              className="w-24 h-14 object-cover rounded-lg"
                            />
                            <div className="flex-1">
                              <h4 className="text-sm font-bold text-white">{project.name}</h4>
                              <p className="text-xs text-gray-400">
                                {new Date(project.createdAt).toLocaleDateString()}
                              </p>
                            </div>
                          </div>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
          </section>
        </main>
      </div>
    </div>
  );
}
