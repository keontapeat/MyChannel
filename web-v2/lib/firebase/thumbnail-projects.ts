// 🔥 FIRESTORE - THUMBNAIL PROJECT STORAGE 💣

import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} from 'firebase/firestore';
import { db } from './config';

// Types
export interface ThumbnailProject {
  id: string;
  userId: string;
  name: string;
  thumbnail: string; // Base64 or URL
  createdAt: Date;
  updatedAt: Date;
  state: {
    backgroundImage: string | null;
    textLayers: any[];
    imageLayers: any[];
    filter: {
      brightness: number;
      contrast: number;
      saturation: number;
      blur: number;
    };
  };
  tags?: string[];
  isPublic?: boolean;
  views?: number;
  likes?: number;
}

// Collection reference
const PROJECTS_COLLECTION = 'thumbnail-projects';

// Save project to Firestore
export async function saveThumbnailProject(
  userId: string,
  project: Omit<ThumbnailProject, 'id' | 'userId' | 'createdAt' | 'updatedAt'>
): Promise<string> {
  try {
    const projectId = `project_${userId}_${Date.now()}`;
    const projectRef = doc(db, PROJECTS_COLLECTION, projectId);

    const projectData: ThumbnailProject = {
      id: projectId,
      userId,
      ...project,
      createdAt: new Date(),
      updatedAt: new Date(),
      views: 0,
      likes: 0,
    };

    await setDoc(projectRef, {
      ...projectData,
      createdAt: Timestamp.fromDate(projectData.createdAt),
      updatedAt: Timestamp.fromDate(projectData.updatedAt),
    });

    console.log('✅ Project saved to Firestore:', projectId);
    return projectId;
  } catch (error) {
    console.error('🚨 Failed to save project:', error);
    throw error;
  }
}

// Update existing project
export async function updateThumbnailProject(
  projectId: string,
  updates: Partial<Omit<ThumbnailProject, 'id' | 'userId' | 'createdAt'>>
): Promise<void> {
  try {
    const projectRef = doc(db, PROJECTS_COLLECTION, projectId);

    await updateDoc(projectRef, {
      ...updates,
      updatedAt: Timestamp.now(),
    });

    console.log('✅ Project updated:', projectId);
  } catch (error) {
    console.error('🚨 Failed to update project:', error);
    throw error;
  }
}

// Get project by ID
export async function getThumbnailProject(projectId: string): Promise<ThumbnailProject | null> {
  try {
    const projectRef = doc(db, PROJECTS_COLLECTION, projectId);
    const projectSnap = await getDoc(projectRef);

    if (!projectSnap.exists()) {
      return null;
    }

    const data = projectSnap.data();
    return {
      ...data,
      createdAt: data.createdAt.toDate(),
      updatedAt: data.updatedAt.toDate(),
    } as ThumbnailProject;
  } catch (error) {
    console.error('🚨 Failed to get project:', error);
    throw error;
  }
}

// Get all projects for a user
export async function getUserThumbnailProjects(
  userId: string,
  limitCount: number = 50
): Promise<ThumbnailProject[]> {
  try {
    const projectsRef = collection(db, PROJECTS_COLLECTION);
    const q = query(
      projectsRef,
      where('userId', '==', userId),
      orderBy('updatedAt', 'desc'),
      limit(limitCount)
    );

    const querySnapshot = await getDocs(q);
    const projects: ThumbnailProject[] = [];

    querySnapshot.forEach((doc) => {
      const data = doc.data();
      projects.push({
        ...data,
        createdAt: data.createdAt.toDate(),
        updatedAt: data.updatedAt.toDate(),
      } as ThumbnailProject);
    });

    console.log(`✅ Loaded ${projects.length} projects for user ${userId}`);
    return projects;
  } catch (error) {
    console.error('🚨 Failed to get user projects:', error);
    throw error;
  }
}

// Delete project
export async function deleteThumbnailProject(projectId: string): Promise<void> {
  try {
    const projectRef = doc(db, PROJECTS_COLLECTION, projectId);
    await deleteDoc(projectRef);

    console.log('✅ Project deleted:', projectId);
  } catch (error) {
    console.error('🚨 Failed to delete project:', error);
    throw error;
  }
}

// Get public projects (for inspiration/templates)
export async function getPublicThumbnailProjects(
  limitCount: number = 20
): Promise<ThumbnailProject[]> {
  try {
    const projectsRef = collection(db, PROJECTS_COLLECTION);
    const q = query(
      projectsRef,
      where('isPublic', '==', true),
      orderBy('views', 'desc'),
      limit(limitCount)
    );

    const querySnapshot = await getDocs(q);
    const projects: ThumbnailProject[] = [];

    querySnapshot.forEach((doc) => {
      const data = doc.data();
      projects.push({
        ...data,
        createdAt: data.createdAt.toDate(),
        updatedAt: data.updatedAt.toDate(),
      } as ThumbnailProject);
    });

    console.log(`✅ Loaded ${projects.length} public projects`);
    return projects;
  } catch (error) {
    console.error('🚨 Failed to get public projects:', error);
    throw error;
  }
}

// Increment project views
export async function incrementProjectViews(projectId: string): Promise<void> {
  try {
    const projectRef = doc(db, PROJECTS_COLLECTION, projectId);
    const projectSnap = await getDoc(projectRef);

    if (projectSnap.exists()) {
      const currentViews = projectSnap.data().views || 0;
      await updateDoc(projectRef, {
        views: currentViews + 1,
      });
    }
  } catch (error) {
    console.error('🚨 Failed to increment views:', error);
    // Don't throw - views are not critical
  }
}

// Like/Unlike project
export async function toggleProjectLike(
  projectId: string,
  userId: string,
  isLiked: boolean
): Promise<void> {
  try {
    const projectRef = doc(db, PROJECTS_COLLECTION, projectId);
    const projectSnap = await getDoc(projectRef);

    if (projectSnap.exists()) {
      const currentLikes = projectSnap.data().likes || 0;
      await updateDoc(projectRef, {
        likes: isLiked ? currentLikes + 1 : Math.max(0, currentLikes - 1),
      });

      // Also track user likes in separate collection
      const userLikeRef = doc(db, 'thumbnail-project-likes', `${userId}_${projectId}`);
      if (isLiked) {
        await setDoc(userLikeRef, {
          userId,
          projectId,
          likedAt: Timestamp.now(),
        });
      } else {
        await deleteDoc(userLikeRef);
      }
    }
  } catch (error) {
    console.error('🚨 Failed to toggle like:', error);
    throw error;
  }
}

// Duplicate project (for templates)
export async function duplicateThumbnailProject(
  projectId: string,
  userId: string,
  newName: string
): Promise<string> {
  try {
    const originalProject = await getThumbnailProject(projectId);
    if (!originalProject) {
      throw new Error('Project not found');
    }

    const newProjectId = await saveThumbnailProject(userId, {
      name: newName,
      thumbnail: originalProject.thumbnail,
      state: originalProject.state,
      tags: originalProject.tags,
      isPublic: false, // Duplicates are private by default
    });

    console.log('✅ Project duplicated:', newProjectId);
    return newProjectId;
  } catch (error) {
    console.error('🚨 Failed to duplicate project:', error);
    throw error;
  }
}

// Search projects by tags
export async function searchThumbnailProjectsByTags(
  tags: string[],
  limitCount: number = 20
): Promise<ThumbnailProject[]> {
  try {
    const projectsRef = collection(db, PROJECTS_COLLECTION);
    const q = query(
      projectsRef,
      where('isPublic', '==', true),
      where('tags', 'array-contains-any', tags),
      orderBy('views', 'desc'),
      limit(limitCount)
    );

    const querySnapshot = await getDocs(q);
    const projects: ThumbnailProject[] = [];

    querySnapshot.forEach((doc) => {
      const data = doc.data();
      projects.push({
        ...data,
        createdAt: data.createdAt.toDate(),
        updatedAt: data.updatedAt.toDate(),
      } as ThumbnailProject);
    });

    console.log(`✅ Found ${projects.length} projects with tags:`, tags);
    return projects;
  } catch (error) {
    console.error('🚨 Failed to search projects:', error);
    throw error;
  }
}

// Export project as JSON (for backup/sharing)
export function exportProjectAsJSON(project: ThumbnailProject): string {
  return JSON.stringify(project, null, 2);
}

// Import project from JSON
export async function importProjectFromJSON(
  userId: string,
  jsonData: string
): Promise<string> {
  try {
    const project = JSON.parse(jsonData) as ThumbnailProject;

    // Remove old ID and timestamps
    const { id, userId: oldUserId, createdAt, updatedAt, ...projectData } = project;

    // Save as new project
    const newProjectId = await saveThumbnailProject(userId, projectData);

    console.log('✅ Project imported:', newProjectId);
    return newProjectId;
  } catch (error) {
    console.error('🚨 Failed to import project:', error);
    throw error;
  }
}




