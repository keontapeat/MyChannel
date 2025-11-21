// 🔥 TEMPLATE MARKETPLACE - BUY & SELL TEMPLATES 💣

import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  updateDoc,
  increment,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

// Types
export interface MarketplaceTemplate {
  id: string;
  name: string;
  description: string;
  category: TemplateCategory;
  tags: string[];
  price: number; // in cents (0 = free)
  currency: string;
  creatorId: string;
  creatorName: string;
  creatorAvatar?: string;
  previewImages: string[]; // URLs
  thumbnailUrl: string;
  templateData: any; // Serialized template
  downloads: number;
  rating: number; // 0-5
  ratingCount: number;
  revenue: number; // Total revenue in cents
  isFeatured: boolean;
  isVerified: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export type TemplateCategory =
  | 'gaming'
  | 'vlog'
  | 'tutorial'
  | 'music'
  | 'sports'
  | 'comedy'
  | 'tech'
  | 'food'
  | 'travel'
  | 'fitness'
  | 'business'
  | 'education'
  | 'other';

export interface TemplatePurchase {
  id: string;
  templateId: string;
  templateName: string;
  buyerId: string;
  buyerName: string;
  sellerId: string;
  sellerName: string;
  price: number;
  currency: string;
  paymentMethod: string;
  transactionId: string;
  purchasedAt: Timestamp;
}

export interface TemplateRating {
  id: string;
  templateId: string;
  userId: string;
  userName: string;
  rating: number; // 1-5
  review?: string;
  createdAt: Timestamp;
}

export interface CreatorEarnings {
  creatorId: string;
  totalRevenue: number; // cents
  totalSales: number;
  availableBalance: number; // cents
  pendingBalance: number; // cents
  lastPayoutAt?: Timestamp;
  lastPayoutAmount?: number;
}

// Publish template to marketplace
export async function publishTemplate(
  template: Omit<MarketplaceTemplate, 'id' | 'downloads' | 'rating' | 'ratingCount' | 'revenue' | 'createdAt' | 'updatedAt'>
): Promise<MarketplaceTemplate> {
  try {
    const templateId = `template_${Date.now()}`;
    const templateRef = doc(db, 'marketplace-templates', templateId);

    const fullTemplate: MarketplaceTemplate = {
      ...template,
      id: templateId,
      downloads: 0,
      rating: 0,
      ratingCount: 0,
      revenue: 0,
      createdAt: serverTimestamp() as Timestamp,
      updatedAt: serverTimestamp() as Timestamp,
    };

    await setDoc(templateRef, fullTemplate);

    console.log('✅ Published template:', templateId);
    return fullTemplate;
  } catch (error) {
    console.error('🚨 Failed to publish template:', error);
    throw error;
  }
}

// Get marketplace templates
export async function getMarketplaceTemplates(
  filters: {
    category?: TemplateCategory;
    priceRange?: { min: number; max: number };
    featured?: boolean;
    sortBy?: 'popular' | 'recent' | 'rating' | 'price-low' | 'price-high';
    limit?: number;
  } = {}
): Promise<MarketplaceTemplate[]> {
  try {
    const templatesRef = collection(db, 'marketplace-templates');
    let q = query(templatesRef);

    // Apply filters
    if (filters.category) {
      q = query(q, where('category', '==', filters.category));
    }

    if (filters.featured) {
      q = query(q, where('isFeatured', '==', true));
    }

    // Apply sorting
    switch (filters.sortBy) {
      case 'popular':
        q = query(q, orderBy('downloads', 'desc'));
        break;
      case 'recent':
        q = query(q, orderBy('createdAt', 'desc'));
        break;
      case 'rating':
        q = query(q, orderBy('rating', 'desc'));
        break;
      case 'price-low':
        q = query(q, orderBy('price', 'asc'));
        break;
      case 'price-high':
        q = query(q, orderBy('price', 'desc'));
        break;
      default:
        q = query(q, orderBy('createdAt', 'desc'));
    }

    // Apply limit
    if (filters.limit) {
      q = query(q, limit(filters.limit));
    }

    const snapshot = await getDocs(q);
    let templates = snapshot.docs.map((doc) => doc.data() as MarketplaceTemplate);

    // Filter by price range (client-side)
    if (filters.priceRange) {
      templates = templates.filter(
        (t) =>
          t.price >= filters.priceRange!.min && t.price <= filters.priceRange!.max
      );
    }

    return templates;
  } catch (error) {
    console.error('🚨 Failed to get marketplace templates:', error);
    return [];
  }
}

// Get template by ID
export async function getTemplate(templateId: string): Promise<MarketplaceTemplate | null> {
  try {
    const templateRef = doc(db, 'marketplace-templates', templateId);
    const snapshot = await getDoc(templateRef);

    if (!snapshot.exists()) return null;

    return snapshot.data() as MarketplaceTemplate;
  } catch (error) {
    console.error('🚨 Failed to get template:', error);
    return null;
  }
}

// Purchase template
export async function purchaseTemplate(
  templateId: string,
  buyerId: string,
  buyerName: string,
  paymentMethod: string,
  transactionId: string
): Promise<TemplatePurchase> {
  try {
    const template = await getTemplate(templateId);
    if (!template) throw new Error('Template not found');

    // Create purchase record
    const purchaseId = `purchase_${Date.now()}`;
    const purchaseRef = doc(db, 'template-purchases', purchaseId);

    const purchase: TemplatePurchase = {
      id: purchaseId,
      templateId,
      templateName: template.name,
      buyerId,
      buyerName,
      sellerId: template.creatorId,
      sellerName: template.creatorName,
      price: template.price,
      currency: template.currency,
      paymentMethod,
      transactionId,
      purchasedAt: serverTimestamp() as Timestamp,
    };

    await setDoc(purchaseRef, purchase);

    // Update template stats
    const templateRef = doc(db, 'marketplace-templates', templateId);
    await updateDoc(templateRef, {
      downloads: increment(1),
      revenue: increment(template.price),
      updatedAt: serverTimestamp(),
    });

    // Update creator earnings
    await updateCreatorEarnings(template.creatorId, template.price);

    console.log('✅ Template purchased:', templateId);
    return purchase;
  } catch (error) {
    console.error('🚨 Failed to purchase template:', error);
    throw error;
  }
}

// Rate template
export async function rateTemplate(
  templateId: string,
  userId: string,
  userName: string,
  rating: number,
  review?: string
): Promise<void> {
  try {
    // Validate rating
    if (rating < 1 || rating > 5) {
      throw new Error('Rating must be between 1 and 5');
    }

    // Create rating record
    const ratingId = `rating_${userId}_${templateId}`;
    const ratingRef = doc(db, 'template-ratings', ratingId);

    const ratingData: TemplateRating = {
      id: ratingId,
      templateId,
      userId,
      userName,
      rating,
      review,
      createdAt: serverTimestamp() as Timestamp,
    };

    await setDoc(ratingRef, ratingData);

    // Update template rating
    await updateTemplateRating(templateId);

    console.log('✅ Template rated:', templateId, rating);
  } catch (error) {
    console.error('🚨 Failed to rate template:', error);
    throw error;
  }
}

// Update template rating
async function updateTemplateRating(templateId: string): Promise<void> {
  try {
    // Get all ratings for template
    const ratingsRef = collection(db, 'template-ratings');
    const q = query(ratingsRef, where('templateId', '==', templateId));
    const snapshot = await getDocs(q);

    const ratings = snapshot.docs.map((doc) => doc.data() as TemplateRating);

    // Calculate average rating
    const totalRating = ratings.reduce((sum, r) => sum + r.rating, 0);
    const averageRating = totalRating / ratings.length;

    // Update template
    const templateRef = doc(db, 'marketplace-templates', templateId);
    await updateDoc(templateRef, {
      rating: averageRating,
      ratingCount: ratings.length,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    console.error('🚨 Failed to update template rating:', error);
  }
}

// Update creator earnings
async function updateCreatorEarnings(
  creatorId: string,
  amount: number
): Promise<void> {
  try {
    const earningsRef = doc(db, 'creator-earnings', creatorId);
    const earningsDoc = await getDoc(earningsRef);

    if (earningsDoc.exists()) {
      // Update existing earnings
      await updateDoc(earningsRef, {
        totalRevenue: increment(amount),
        totalSales: increment(1),
        pendingBalance: increment(amount),
      });
    } else {
      // Create new earnings record
      const earnings: CreatorEarnings = {
        creatorId,
        totalRevenue: amount,
        totalSales: 1,
        availableBalance: 0,
        pendingBalance: amount,
      };
      await setDoc(earningsRef, earnings);
    }

    console.log('✅ Creator earnings updated:', creatorId, amount);
  } catch (error) {
    console.error('🚨 Failed to update creator earnings:', error);
  }
}

// Get creator earnings
export async function getCreatorEarnings(
  creatorId: string
): Promise<CreatorEarnings | null> {
  try {
    const earningsRef = doc(db, 'creator-earnings', creatorId);
    const snapshot = await getDoc(earningsRef);

    if (!snapshot.exists()) return null;

    return snapshot.data() as CreatorEarnings;
  } catch (error) {
    console.error('🚨 Failed to get creator earnings:', error);
    return null;
  }
}

// Get user's purchased templates
export async function getUserPurchases(userId: string): Promise<TemplatePurchase[]> {
  try {
    const purchasesRef = collection(db, 'template-purchases');
    const q = query(purchasesRef, where('buyerId', '==', userId), orderBy('purchasedAt', 'desc'));
    const snapshot = await getDocs(q);

    return snapshot.docs.map((doc) => doc.data() as TemplatePurchase);
  } catch (error) {
    console.error('🚨 Failed to get user purchases:', error);
    return [];
  }
}

// Get creator's templates
export async function getCreatorTemplates(creatorId: string): Promise<MarketplaceTemplate[]> {
  try {
    const templatesRef = collection(db, 'marketplace-templates');
    const q = query(templatesRef, where('creatorId', '==', creatorId), orderBy('createdAt', 'desc'));
    const snapshot = await getDocs(q);

    return snapshot.docs.map((doc) => doc.data() as MarketplaceTemplate);
  } catch (error) {
    console.error('🚨 Failed to get creator templates:', error);
    return [];
  }
}

// Search templates
export async function searchTemplates(searchQuery: string): Promise<MarketplaceTemplate[]> {
  try {
    // Get all templates (Firestore doesn't support full-text search)
    const templatesRef = collection(db, 'marketplace-templates');
    const snapshot = await getDocs(templatesRef);

    const allTemplates = snapshot.docs.map((doc) => doc.data() as MarketplaceTemplate);

    // Filter by search query (client-side)
    const query = searchQuery.toLowerCase();
    return allTemplates.filter(
      (template) =>
        template.name.toLowerCase().includes(query) ||
        template.description.toLowerCase().includes(query) ||
        template.tags.some((tag) => tag.toLowerCase().includes(query)) ||
        template.category.toLowerCase().includes(query)
    );
  } catch (error) {
    console.error('🚨 Failed to search templates:', error);
    return [];
  }
}

// Get featured templates
export async function getFeaturedTemplates(limit: number = 10): Promise<MarketplaceTemplate[]> {
  return getMarketplaceTemplates({
    featured: true,
    sortBy: 'popular',
    limit,
  });
}

// Get trending templates
export async function getTrendingTemplates(limit: number = 10): Promise<MarketplaceTemplate[]> {
  return getMarketplaceTemplates({
    sortBy: 'popular',
    limit,
  });
}

// Format price
export function formatPrice(cents: number, currency: string = 'USD'): string {
  if (cents === 0) return 'FREE';

  const dollars = cents / 100;
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
  }).format(dollars);
}

// Calculate creator payout (70% of revenue, 30% platform fee)
export function calculateCreatorPayout(revenue: number): {
  creatorAmount: number;
  platformFee: number;
} {
  const platformFee = Math.floor(revenue * 0.3);
  const creatorAmount = revenue - platformFee;

  return { creatorAmount, platformFee };
}




