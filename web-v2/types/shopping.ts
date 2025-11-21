// Live Shopping Types - Professional TypeScript Definitions

export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  originalPrice?: number;
  discount?: number;
  imageURL: string;
  images: string[]; // Multiple product images
  category: ProductCategory;
  subcategory?: string;
  brand?: string;
  inStock: boolean;
  stockQuantity: number;
  rating: number;
  reviewCount: number;
  specifications: ProductSpecification[];
  variants?: ProductVariant[]; // Size, color, etc.
  shippingInfo: ShippingInfo;
  returnPolicy: string;
  sellerId: string;
  seller: Seller;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
  isFeatured: boolean;
  isFlashSale: boolean;
  flashSaleEndsAt?: Date;
  arEnabled: boolean; // AR Try-On available
  videoURL?: string; // Product demo video
}

export interface ProductSpecification {
  name: string;
  value: string;
}

export interface ProductVariant {
  id: string;
  name: string; // "Size", "Color", etc.
  options: VariantOption[];
}

export interface VariantOption {
  id: string;
  value: string; // "Small", "Red", etc.
  priceModifier?: number; // +/- price change
  inStock: boolean;
  imageURL?: string;
}

export interface ShippingInfo {
  freeShipping: boolean;
  shippingCost?: number;
  estimatedDays: string; // "2-3 days"
  international: boolean;
}

export interface Seller {
  id: string;
  name: string;
  displayName: string;
  profileImageURL: string;
  isVerified: boolean;
  rating: number;
  totalSales: number;
  responseTime: string; // "Usually responds in 24 hours"
}

export enum ProductCategory {
  Fashion = 'fashion',
  Electronics = 'electronics',
  Beauty = 'beauty',
  Home = 'home',
  Sports = 'sports',
  Toys = 'toys',
  Books = 'books',
  Food = 'food',
  Health = 'health',
  Automotive = 'automotive',
}

export interface LiveShoppingStream {
  id: string;
  title: string;
  description: string;
  thumbnailURL: string;
  hlsURL: string;
  isLive: boolean;
  startedAt: Date;
  scheduledAt?: Date;
  endedAt?: Date;
  viewerCount: number;
  peakViewerCount: number;
  likeCount: number;
  streamer: StreamerInfo;
  category: ProductCategory;
  tags: string[];
  featuredProducts: string[]; // Product IDs
  products: Product[]; // Full product objects
  chatEnabled: boolean;
  donationsEnabled: boolean;
  status: StreamStatus;
  language: string;
  region: string;
}

export interface StreamerInfo {
  id: string;
  username: string;
  displayName: string;
  profileImageURL: string;
  bannerImageURL?: string;
  isVerified: boolean;
  subscriberCount: number;
  bio?: string;
  socialLinks?: SocialLinks;
}

export interface SocialLinks {
  instagram?: string;
  twitter?: string;
  tiktok?: string;
  website?: string;
}

export enum StreamStatus {
  Scheduled = 'scheduled',
  Live = 'live',
  Ended = 'ended',
  Cancelled = 'cancelled',
}

export interface ShoppingCart {
  id: string;
  userId: string;
  items: CartItem[];
  subtotal: number;
  tax: number;
  shipping: number;
  total: number;
  createdAt: Date;
  updatedAt: Date;
  expiresAt: Date; // Cart expires after 24 hours
}

export interface CartItem {
  id: string;
  productId: string;
  product: Product;
  quantity: number;
  selectedVariants?: { [key: string]: string }; // { "Size": "Medium", "Color": "Blue" }
  price: number; // Price at time of adding to cart
  subtotal: number; // price * quantity
  addedAt: Date;
  fromLiveStream?: string; // Live stream ID if added during stream
}

export interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  subtotal: number;
  tax: number;
  shipping: number;
  discount: number;
  total: number;
  status: OrderStatus;
  paymentMethod: PaymentMethod;
  paymentIntentId: string; // Stripe Payment Intent ID
  shippingAddress: Address;
  billingAddress: Address;
  trackingNumber?: string;
  estimatedDelivery?: Date;
  createdAt: Date;
  updatedAt: Date;
  notes?: string;
}

export interface OrderItem {
  id: string;
  productId: string;
  productName: string;
  productImageURL: string;
  quantity: number;
  price: number;
  subtotal: number;
  selectedVariants?: { [key: string]: string };
  sellerId: string;
}

export enum OrderStatus {
  Pending = 'pending',
  Processing = 'processing',
  Shipped = 'shipped',
  Delivered = 'delivered',
  Cancelled = 'cancelled',
  Refunded = 'refunded',
}

export enum PaymentMethod {
  Card = 'card',
  ApplePay = 'apple_pay',
  GooglePay = 'google_pay',
  PayPal = 'paypal',
}

export interface Address {
  fullName: string;
  addressLine1: string;
  addressLine2?: string;
  city: string;
  state: string;
  zipCode: string;
  country: string;
  phoneNumber: string;
}

export interface ProductReview {
  id: string;
  productId: string;
  userId: string;
  userName: string;
  userProfileImageURL: string;
  rating: number; // 1-5
  title: string;
  content: string;
  images?: string[];
  verified: boolean; // Verified purchase
  helpful: number; // Helpful count
  createdAt: Date;
  updatedAt: Date;
}

export interface ARTryOnSession {
  id: string;
  userId: string;
  productId: string;
  sessionStartedAt: Date;
  sessionEndedAt?: Date;
  screenshots: string[]; // URLs to screenshots
  addedToCart: boolean;
  purchased: boolean;
}

export interface InstantBuyConfig {
  enabled: boolean;
  savedPaymentMethods: SavedPaymentMethod[];
  defaultPaymentMethodId?: string;
  savedAddresses: Address[];
  defaultAddressId?: string;
}

export interface SavedPaymentMethod {
  id: string;
  type: PaymentMethod;
  last4?: string; // Last 4 digits of card
  brand?: string; // Visa, Mastercard, etc.
  expiryMonth?: number;
  expiryYear?: number;
  isDefault: boolean;
}

export interface FlashSale {
  id: string;
  title: string;
  description: string;
  productIds: string[];
  products: Product[];
  discount: number;
  startAt: Date;
  endAt: Date;
  isActive: boolean;
  totalStock: number;
  remainingStock: number;
  bannerImageURL?: string;
}

export interface WishlistItem {
  id: string;
  userId: string;
  productId: string;
  product: Product;
  addedAt: Date;
  priceAtAdd: number;
  notifyOnSale: boolean;
  notifyOnRestock: boolean;
}




