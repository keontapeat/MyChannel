// 🔥 3D TEXT EFFECTS - CRAZY DEPTH & LIGHTING 💣

import * as THREE from 'three';
import { FontLoader } from 'three/examples/jsm/loaders/FontLoader';
import { TextGeometry } from 'three/examples/jsm/geometries/TextGeometry';

// Types
export interface Text3DOptions {
  text: string;
  fontSize: number;
  depth: number;
  bevelEnabled: boolean;
  bevelThickness: number;
  bevelSize: number;
  bevelSegments: number;
  color: string;
  metalness: number;
  roughness: number;
  rotation: { x: number; y: number; z: number };
  position: { x: number; y: number; z: number };
  lighting: LightingConfig;
}

export interface LightingConfig {
  ambient: { color: string; intensity: number };
  directional: { color: string; intensity: number; position: { x: number; y: number; z: number } };
  point?: { color: string; intensity: number; position: { x: number; y: number; z: number } };
}

export interface Material3D {
  type: 'standard' | 'phong' | 'lambert' | 'toon' | 'physical';
  color: string;
  metalness?: number;
  roughness?: number;
  emissive?: string;
  emissiveIntensity?: number;
  envMapIntensity?: number;
}

// Create 3D text scene
export class Text3DRenderer {
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private renderer: THREE.WebGLRenderer;
  private textMesh: THREE.Mesh | null = null;
  private fontLoader: FontLoader;
  private font: any = null;

  constructor(width: number = 1280, height: number = 720) {
    // Scene
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x000000);

    // Camera
    this.camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000);
    this.camera.position.z = 5;

    // Renderer
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.setSize(width, height);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    // Font loader
    this.fontLoader = new FontLoader();
  }

  // Load font
  async loadFont(fontUrl: string = '/fonts/helvetiker_bold.typeface.json'): Promise<void> {
    return new Promise((resolve, reject) => {
      this.fontLoader.load(
        fontUrl,
        (font) => {
          this.font = font;
          resolve();
        },
        undefined,
        reject
      );
    });
  }

  // Create 3D text
  createText(options: Text3DOptions): void {
    if (!this.font) {
      throw new Error('Font not loaded. Call loadFont() first.');
    }

    // Remove existing text
    if (this.textMesh) {
      this.scene.remove(this.textMesh);
    }

    // Create text geometry
    const textGeometry = new TextGeometry(options.text, {
      font: this.font,
      size: options.fontSize,
      height: options.depth,
      curveSegments: 12,
      bevelEnabled: options.bevelEnabled,
      bevelThickness: options.bevelThickness,
      bevelSize: options.bevelSize,
      bevelSegments: options.bevelSegments,
    });

    // Center geometry
    textGeometry.computeBoundingBox();
    const centerOffset =
      -0.5 * (textGeometry.boundingBox!.max.x - textGeometry.boundingBox!.min.x);
    textGeometry.translate(centerOffset, 0, 0);

    // Create material
    const material = new THREE.MeshStandardMaterial({
      color: new THREE.Color(options.color),
      metalness: options.metalness,
      roughness: options.roughness,
    });

    // Create mesh
    this.textMesh = new THREE.Mesh(textGeometry, material);
    this.textMesh.castShadow = true;
    this.textMesh.receiveShadow = true;

    // Set rotation
    this.textMesh.rotation.x = options.rotation.x;
    this.textMesh.rotation.y = options.rotation.y;
    this.textMesh.rotation.z = options.rotation.z;

    // Set position
    this.textMesh.position.x = options.position.x;
    this.textMesh.position.y = options.position.y;
    this.textMesh.position.z = options.position.z;

    this.scene.add(this.textMesh);

    // Setup lighting
    this.setupLighting(options.lighting);
  }

  // Setup lighting
  private setupLighting(config: LightingConfig): void {
    // Clear existing lights
    this.scene.children = this.scene.children.filter(
      (child) => !(child instanceof THREE.Light)
    );

    // Ambient light
    const ambientLight = new THREE.AmbientLight(
      new THREE.Color(config.ambient.color),
      config.ambient.intensity
    );
    this.scene.add(ambientLight);

    // Directional light
    const directionalLight = new THREE.DirectionalLight(
      new THREE.Color(config.directional.color),
      config.directional.intensity
    );
    directionalLight.position.set(
      config.directional.position.x,
      config.directional.position.y,
      config.directional.position.z
    );
    directionalLight.castShadow = true;
    this.scene.add(directionalLight);

    // Point light (optional)
    if (config.point) {
      const pointLight = new THREE.PointLight(
        new THREE.Color(config.point.color),
        config.point.intensity
      );
      pointLight.position.set(
        config.point.position.x,
        config.point.position.y,
        config.point.position.z
      );
      this.scene.add(pointLight);
    }
  }

  // Render to canvas
  render(): HTMLCanvasElement {
    this.renderer.render(this.scene, this.camera);
    return this.renderer.domElement;
  }

  // Render to data URL
  renderToDataURL(): string {
    this.render();
    return this.renderer.domElement.toDataURL('image/png');
  }

  // Animate rotation
  animateRotation(duration: number = 2000, fps: number = 30): string[] {
    if (!this.textMesh) return [];

    const frames: string[] = [];
    const frameCount = (duration / 1000) * fps;
    const rotationStep = (Math.PI * 2) / frameCount;

    for (let i = 0; i < frameCount; i++) {
      this.textMesh.rotation.y = i * rotationStep;
      frames.push(this.renderToDataURL());
    }

    return frames;
  }

  // Update material
  updateMaterial(material: Material3D): void {
    if (!this.textMesh) return;

    let newMaterial: THREE.Material;

    switch (material.type) {
      case 'standard':
        newMaterial = new THREE.MeshStandardMaterial({
          color: new THREE.Color(material.color),
          metalness: material.metalness ?? 0.5,
          roughness: material.roughness ?? 0.5,
        });
        break;
      case 'phong':
        newMaterial = new THREE.MeshPhongMaterial({
          color: new THREE.Color(material.color),
          shininess: 100,
        });
        break;
      case 'lambert':
        newMaterial = new THREE.MeshLambertMaterial({
          color: new THREE.Color(material.color),
        });
        break;
      case 'toon':
        newMaterial = new THREE.MeshToonMaterial({
          color: new THREE.Color(material.color),
        });
        break;
      case 'physical':
        newMaterial = new THREE.MeshPhysicalMaterial({
          color: new THREE.Color(material.color),
          metalness: material.metalness ?? 0.5,
          roughness: material.roughness ?? 0.5,
          clearcoat: 1.0,
          clearcoatRoughness: 0.1,
        });
        break;
    }

    this.textMesh.material = newMaterial;
  }

  // Dispose
  dispose(): void {
    if (this.textMesh) {
      this.scene.remove(this.textMesh);
      this.textMesh.geometry.dispose();
      (this.textMesh.material as THREE.Material).dispose();
    }
    this.renderer.dispose();
  }
}

// Preset 3D text styles
export const text3DPresets = {
  chrome: {
    depth: 0.5,
    bevelEnabled: true,
    bevelThickness: 0.1,
    bevelSize: 0.05,
    bevelSegments: 5,
    color: '#CCCCCC',
    metalness: 1.0,
    roughness: 0.1,
    lighting: {
      ambient: { color: '#FFFFFF', intensity: 0.3 },
      directional: { color: '#FFFFFF', intensity: 0.8, position: { x: 5, y: 5, z: 5 } },
      point: { color: '#FFFFFF', intensity: 0.5, position: { x: -5, y: 5, z: 5 } },
    },
  },
  gold: {
    depth: 0.4,
    bevelEnabled: true,
    bevelThickness: 0.08,
    bevelSize: 0.04,
    bevelSegments: 5,
    color: '#FFD700',
    metalness: 0.9,
    roughness: 0.2,
    lighting: {
      ambient: { color: '#FFA500', intensity: 0.4 },
      directional: { color: '#FFFFFF', intensity: 0.7, position: { x: 5, y: 5, z: 5 } },
    },
  },
  neon: {
    depth: 0.2,
    bevelEnabled: false,
    bevelThickness: 0,
    bevelSize: 0,
    bevelSegments: 0,
    color: '#00FFFF',
    metalness: 0.0,
    roughness: 0.5,
    lighting: {
      ambient: { color: '#00FFFF', intensity: 0.8 },
      directional: { color: '#FFFFFF', intensity: 0.3, position: { x: 0, y: 0, z: 5 } },
      point: { color: '#00FFFF', intensity: 2.0, position: { x: 0, y: 0, z: 2 } },
    },
  },
  plastic: {
    depth: 0.3,
    bevelEnabled: true,
    bevelThickness: 0.05,
    bevelSize: 0.03,
    bevelSegments: 3,
    color: '#FF0000',
    metalness: 0.0,
    roughness: 0.8,
    lighting: {
      ambient: { color: '#FFFFFF', intensity: 0.5 },
      directional: { color: '#FFFFFF', intensity: 0.6, position: { x: 5, y: 5, z: 5 } },
    },
  },
  glass: {
    depth: 0.3,
    bevelEnabled: true,
    bevelThickness: 0.06,
    bevelSize: 0.03,
    bevelSegments: 5,
    color: '#88CCFF',
    metalness: 0.1,
    roughness: 0.0,
    lighting: {
      ambient: { color: '#FFFFFF', intensity: 0.6 },
      directional: { color: '#FFFFFF', intensity: 0.9, position: { x: 5, y: 5, z: 5 } },
      point: { color: '#FFFFFF', intensity: 0.7, position: { x: -5, y: 5, z: 5 } },
    },
  },
};

// Apply preset
export function apply3DPreset(
  renderer: Text3DRenderer,
  text: string,
  preset: keyof typeof text3DPresets,
  fontSize: number = 1
): void {
  const presetConfig = text3DPresets[preset];

  renderer.createText({
    text,
    fontSize,
    ...presetConfig,
    rotation: { x: 0, y: 0, z: 0 },
    position: { x: 0, y: 0, z: 0 },
  });
}

// Export 3D text as image
export async function export3DText(
  text: string,
  options: Partial<Text3DOptions> = {},
  width: number = 1280,
  height: number = 720
): Promise<string> {
  const renderer = new Text3DRenderer(width, height);

  // Load font
  await renderer.loadFont();

  // Create text with default options
  const defaultOptions: Text3DOptions = {
    text,
    fontSize: 1,
    depth: 0.5,
    bevelEnabled: true,
    bevelThickness: 0.1,
    bevelSize: 0.05,
    bevelSegments: 5,
    color: '#FFFFFF',
    metalness: 0.5,
    roughness: 0.5,
    rotation: { x: 0, y: 0, z: 0 },
    position: { x: 0, y: 0, z: 0 },
    lighting: {
      ambient: { color: '#FFFFFF', intensity: 0.4 },
      directional: { color: '#FFFFFF', intensity: 0.8, position: { x: 5, y: 5, z: 5 } },
    },
  };

  renderer.createText({ ...defaultOptions, ...options });

  // Render
  const dataURL = renderer.renderToDataURL();

  // Cleanup
  renderer.dispose();

  return dataURL;
}






