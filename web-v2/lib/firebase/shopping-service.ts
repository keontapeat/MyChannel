// Live Shopping Firebase Service - Professional Implementation
'use client';

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
  startAfter,
  Timestamp,
  increment,
  arrayUnion,
  arrayRemove,
  DocumentSnapshot,
} from 'firebase/firestore';
import { db } from './config';
import type {
  Product,
  LiveShoppingStream,
  ShoppingCart,
  CartItem,
  Order,
  ProductReview,
  FlashSale,
  WishlistItem,
  ProductCategory,
  StreamStatus,
  OrderStatus,
} from '@/types/shopping';

export class ShoppingService {
  // ==================== PRODUCTS ====================

  static async getProduct(productId: string): Promise<Product | null> {
    try {
      const docRef = doc(db, 'products', productId);
      const docSnap = await getDoc(docRef);

      if (!docSnap.exists()) return null;

      const data = docSnap.data();
      return {
        ...data,
        id: docSnap.id,
        createdAt: data.createdAt?.toDate(),
        updatedAt: data.updatedAt?.toDate(),
        flashSaleEndsAt: data.flashSaleEndsAt?.toDate(),
      } as Product;
    } catch (error) {
      console.error('Error fetching product:', error);
      throw error;
    }
  }

  static async getProducts(
    categoryFilter?: ProductCategory,
    limitCount: number = 20,
    lastDoc?: DocumentSnapshot
  ): Promise<{ products: Product[]; lastDoc: DocumentSnapshot | null }> {
    try {
      let q = query(
        collection(db, 'products'),
        where('inStock', '==', true),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );

      if (categoryFilter) {
        q = query(
          collection(db, 'products'),
          where('category', '==', categoryFilter),
          where('inStock', '==', true),
          orderBy('createdAt', 'desc'),
          limit(limitCount)
        );
      }

      if (lastDoc) {
        q = query(q, startAfter(lastDoc));
      }

      const snapshot = await getDocs(q);
      const products = snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        createdAt: doc.data().createdAt?.toDate(),
        updatedAt: doc.data().updatedAt?.toDate(),
        flashSaleEndsAt: doc.data().flashSaleEndsAt?.toDate(),
      })) as Product[];

      return {
        products,
        lastDoc: snapshot.docs[snapshot.docs.length - 1] || null,
      };
    } catch (error) {
      console.error('Error fetching products:', error);
      throw error;
    }
  }

  static async getTrendingProducts(limitCount: number = 20): Promise<Product[]> {
    try {
      const q = query(
        collection(db, 'products'),
        where('inStock', '==', true),
        orderBy('rating', 'desc'),
        orderBy('reviewCount', 'desc'),
        limit(limitCount)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        createdAt: doc.data().createdAt?.toDate(),
        updatedAt: doc.data().updatedAt?.toDate(),
        flashSaleEndsAt: doc.data().flashSaleEndsAt?.toDate(),
      })) as Product[];
    } catch (error) {
      console.error('Error fetching trending products:', error);
      throw error;
    }
  }

  static async searchProducts(searchQuery: string, limitCount: number = 20): Promise<Product[]> {
    try {
      // Note: For production, use Algolia or Elasticsearch for better search
      // This is a basic Firestore search
      const q = query(
        collection(db, 'products'),
        where('tags', 'array-contains', searchQuery.toLowerCase()),
        where('inStock', '==', true),
        limit(limitCount)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        createdAt: doc.data().createdAt?.toDate(),
        updatedAt: doc.data().updatedAt?.toDate(),
      })) as Product[];
    } catch (error) {
      console.error('Error searching products:', error);
      throw error;
    }
  }

  // ==================== LIVE SHOPPING STREAMS ====================

  static async getLiveStream(streamId: string): Promise<LiveShoppingStream | null> {
    try {
      const docRef = doc(db, 'live_shopping_streams', streamId);
      const docSnap = await getDoc(docRef);

      if (!docSnap.exists()) return null;

      const data = docSnap.data();
      return {
        ...data,
        id: docSnap.id,
        startedAt: data.startedAt?.toDate(),
        scheduledAt: data.scheduledAt?.toDate(),
        endedAt: data.endedAt?.toDate(),
      } as LiveShoppingStream;
    } catch (error) {
      console.error('Error fetching live stream:', error);
      throw error;
    }
  }

  static async getLiveStreams(
    status: StreamStatus = StreamStatus.Live,
    limitCount: number = 20
  ): Promise<LiveShoppingStream[]> {
    try {
      const q = query(
        collection(db, 'live_shopping_streams'),
        where('status', '==', status),
        orderBy('viewerCount', 'desc'),
        limit(limitCount)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        startedAt: doc.data().startedAt?.toDate(),
        scheduledAt: doc.data().scheduledAt?.toDate(),
        endedAt: doc.data().endedAt?.toDate(),
      })) as LiveShoppingStream[];
    } catch (error) {
      console.error('Error fetching live streams:', error);
      throw error;
    }
  }

  static async incrementStreamViewers(streamId: string): Promise<void> {
    try {
      const docRef = doc(db, 'live_shopping_streams', streamId);
      await updateDoc(docRef, {
        viewerCount: increment(1),
      });
    } catch (error) {
      console.error('Error incrementing viewers:', error);
      throw error;
    }
  }

  // ==================== SHOPPING CART ====================

  static async getCart(userId: string): Promise<ShoppingCart | null> {
    try {
      const docRef = doc(db, 'shopping_carts', userId);
      const docSnap = await getDoc(docRef);

      if (!docSnap.exists()) {
        // Create empty cart
        const emptyCart: ShoppingCart = {
          id: userId,
          userId,
          items: [],
          subtotal: 0,
          tax: 0,
          shipping: 0,
          total: 0,
          createdAt: new Date(),
          updatedAt: new Date(),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
        };
        await setDoc(docRef, {
          ...emptyCart,
          createdAt: Timestamp.fromDate(emptyCart.createdAt),
          updatedAt: Timestamp.fromDate(emptyCart.updatedAt),
          expiresAt: Timestamp.fromDate(emptyCart.expiresAt),
        });
        return emptyCart;
      }

      const data = docSnap.data();
      return {
        ...data,
        id: docSnap.id,
        createdAt: data.createdAt?.toDate(),
        updatedAt: data.updatedAt?.toDate(),
        expiresAt: data.expiresAt?.toDate(),
        items: data.items?.map((item: any) => ({
          ...item,
          addedAt: item.addedAt?.toDate(),
        })),
      } as ShoppingCart;
    } catch (error) {
      console.error('Error fetching cart:', error);
      throw error;
    }
  }

  static async addToCart(
    userId: string,
    product: Product,
    quantity: number = 1,
    selectedVariants?: { [key: string]: string },
    fromLiveStream?: string
  ): Promise<ShoppingCart> {
    try {
      const cart = await this.getCart(userId);
      if (!cart) throw new Error('Cart not found');

      // Check if product already in cart
      const existingItemIndex = cart.items.findIndex(
        (item) => item.productId === product.id
      );

      const cartItem: CartItem = {
        id: `${product.id}_${Date.now()}`,
        productId: product.id,
        product,
        quantity,
        selectedVariants,
        price: product.price,
        subtotal: product.price * quantity,
        addedAt: new Date(),
        fromLiveStream,
      };

      if (existingItemIndex >= 0) {
        // Update quantity
        cart.items[existingItemIndex].quantity += quantity;
        cart.items[existingItemIndex].subtotal =
          cart.items[existingItemIndex].price * cart.items[existingItemIndex].quantity;
      } else {
        // Add new item
        cart.items.push(cartItem);
      }

      // Recalculate totals
      cart.subtotal = cart.items.reduce((sum, item) => sum + item.subtotal, 0);
      cart.tax = cart.subtotal * 0.08; // 8% tax (adjust based on region)
      cart.shipping = cart.subtotal > 50 ? 0 : 5.99; // Free shipping over $50
      cart.total = cart.subtotal + cart.tax + cart.shipping;
      cart.updatedAt = new Date();

      // Save to Firestore
      const docRef = doc(db, 'shopping_carts', userId);
      await updateDoc(docRef, {
        items: cart.items.map((item) => ({
          ...item,
          addedAt: Timestamp.fromDate(item.addedAt),
        })),
        subtotal: cart.subtotal,
        tax: cart.tax,
        shipping: cart.shipping,
        total: cart.total,
        updatedAt: Timestamp.fromDate(cart.updatedAt),
      });

      return cart;
    } catch (error) {
      console.error('Error adding to cart:', error);
      throw error;
    }
  }

  static async updateCartItemQuantity(
    userId: string,
    itemId: string,
    quantity: number
  ): Promise<ShoppingCart> {
    try {
      const cart = await this.getCart(userId);
      if (!cart) throw new Error('Cart not found');

      const itemIndex = cart.items.findIndex((item) => item.id === itemId);
      if (itemIndex < 0) throw new Error('Item not found in cart');

      if (quantity <= 0) {
        // Remove item
        cart.items.splice(itemIndex, 1);
      } else {
        // Update quantity
        cart.items[itemIndex].quantity = quantity;
        cart.items[itemIndex].subtotal = cart.items[itemIndex].price * quantity;
      }

      // Recalculate totals
      cart.subtotal = cart.items.reduce((sum, item) => sum + item.subtotal, 0);
      cart.tax = cart.subtotal * 0.08;
      cart.shipping = cart.subtotal > 50 ? 0 : 5.99;
      cart.total = cart.subtotal + cart.tax + cart.shipping;
      cart.updatedAt = new Date();

      // Save to Firestore
      const docRef = doc(db, 'shopping_carts', userId);
      await updateDoc(docRef, {
        items: cart.items.map((item) => ({
          ...item,
          addedAt: Timestamp.fromDate(item.addedAt),
        })),
        subtotal: cart.subtotal,
        tax: cart.tax,
        shipping: cart.shipping,
        total: cart.total,
        updatedAt: Timestamp.fromDate(cart.updatedAt),
      });

      return cart;
    } catch (error) {
      console.error('Error updating cart item:', error);
      throw error;
    }
  }

  static async removeFromCart(userId: string, itemId: string): Promise<ShoppingCart> {
    return this.updateCartItemQuantity(userId, itemId, 0);
  }

  static async clearCart(userId: string): Promise<void> {
    try {
      const docRef = doc(db, 'shopping_carts', userId);
      await updateDoc(docRef, {
        items: [],
        subtotal: 0,
        tax: 0,
        shipping: 0,
        total: 0,
        updatedAt: Timestamp.now(),
      });
    } catch (error) {
      console.error('Error clearing cart:', error);
      throw error;
    }
  }

  // ==================== ORDERS ====================

  static async createOrder(userId: string, cart: ShoppingCart, order: Partial<Order>): Promise<Order> {
    try {
      const orderId = `order_${Date.now()}`;
      const newOrder: Order = {
        id: orderId,
        userId,
        items: cart.items.map((item) => ({
          id: item.id,
          productId: item.productId,
          productName: item.product.name,
          productImageURL: item.product.imageURL,
          quantity: item.quantity,
          price: item.price,
          subtotal: item.subtotal,
          selectedVariants: item.selectedVariants,
          sellerId: item.product.sellerId,
        })),
        subtotal: cart.subtotal,
        tax: cart.tax,
        shipping: cart.shipping,
        discount: 0,
        total: cart.total,
        status: OrderStatus.Pending,
        ...order,
        createdAt: new Date(),
        updatedAt: new Date(),
      } as Order;

      const docRef = doc(db, 'orders', orderId);
      await setDoc(docRef, {
        ...newOrder,
        createdAt: Timestamp.fromDate(newOrder.createdAt),
        updatedAt: Timestamp.fromDate(newOrder.updatedAt),
        estimatedDelivery: newOrder.estimatedDelivery
          ? Timestamp.fromDate(newOrder.estimatedDelivery)
          : null,
      });

      // Clear cart after order
      await this.clearCart(userId);

      return newOrder;
    } catch (error) {
      console.error('Error creating order:', error);
      throw error;
    }
  }

  static async getOrder(orderId: string): Promise<Order | null> {
    try {
      const docRef = doc(db, 'orders', orderId);
      const docSnap = await getDoc(docRef);

      if (!docSnap.exists()) return null;

      const data = docSnap.data();
      return {
        ...data,
        id: docSnap.id,
        createdAt: data.createdAt?.toDate(),
        updatedAt: data.updatedAt?.toDate(),
        estimatedDelivery: data.estimatedDelivery?.toDate(),
      } as Order;
    } catch (error) {
      console.error('Error fetching order:', error);
      throw error;
    }
  }

  static async getUserOrders(userId: string, limitCount: number = 20): Promise<Order[]> {
    try {
      const q = query(
        collection(db, 'orders'),
        where('userId', '==', userId),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        createdAt: doc.data().createdAt?.toDate(),
        updatedAt: doc.data().updatedAt?.toDate(),
        estimatedDelivery: doc.data().estimatedDelivery?.toDate(),
      })) as Order[];
    } catch (error) {
      console.error('Error fetching user orders:', error);
      throw error;
    }
  }

  // ==================== REVIEWS ====================

  static async getProductReviews(productId: string, limitCount: number = 20): Promise<ProductReview[]> {
    try {
      const q = query(
        collection(db, 'product_reviews'),
        where('productId', '==', productId),
        orderBy('createdAt', 'desc'),
        limit(limitCount)
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        createdAt: doc.data().createdAt?.toDate(),
        updatedAt: doc.data().updatedAt?.toDate(),
      })) as ProductReview[];
    } catch (error) {
      console.error('Error fetching reviews:', error);
      throw error;
    }
  }

  // ==================== WISHLIST ====================

  static async addToWishlist(userId: string, product: Product): Promise<void> {
    try {
      const wishlistItem: WishlistItem = {
        id: `${userId}_${product.id}`,
        userId,
        productId: product.id,
        product,
        addedAt: new Date(),
        priceAtAdd: product.price,
        notifyOnSale: true,
        notifyOnRestock: true,
      };

      const docRef = doc(db, 'wishlists', wishlistItem.id);
      await setDoc(docRef, {
        ...wishlistItem,
        addedAt: Timestamp.fromDate(wishlistItem.addedAt),
      });
    } catch (error) {
      console.error('Error adding to wishlist:', error);
      throw error;
    }
  }

  static async removeFromWishlist(userId: string, productId: string): Promise<void> {
    try {
      const docRef = doc(db, 'wishlists', `${userId}_${productId}`);
      await deleteDoc(docRef);
    } catch (error) {
      console.error('Error removing from wishlist:', error);
      throw error;
    }
  }

  static async getWishlist(userId: string): Promise<WishlistItem[]> {
    try {
      const q = query(
        collection(db, 'wishlists'),
        where('userId', '==', userId),
        orderBy('addedAt', 'desc')
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        addedAt: doc.data().addedAt?.toDate(),
      })) as WishlistItem[];
    } catch (error) {
      console.error('Error fetching wishlist:', error);
      throw error;
    }
  }

  // ==================== FLASH SALES ====================

  static async getActiveFlashSales(): Promise<FlashSale[]> {
    try {
      const now = Timestamp.now();
      const q = query(
        collection(db, 'flash_sales'),
        where('isActive', '==', true),
        where('endAt', '>', now),
        orderBy('endAt', 'asc')
      );

      const snapshot = await getDocs(q);
      return snapshot.docs.map((doc) => ({
        ...doc.data(),
        id: doc.id,
        startAt: doc.data().startAt?.toDate(),
        endAt: doc.data().endAt?.toDate(),
      })) as FlashSale[];
    } catch (error) {
      console.error('Error fetching flash sales:', error);
      throw error;
    }
  }
}


