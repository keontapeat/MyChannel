// Stripe Payment Service - Professional Implementation
'use client';

import type { ShoppingCart, Order, PaymentMethod } from '@/types/shopping';

// Stripe configuration
const STRIPE_PUBLIC_KEY = process.env.NEXT_PUBLIC_STRIPE_PUBLIC_KEY || '';
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '';

export interface PaymentIntentResponse {
  clientSecret: string;
  paymentIntentId: string;
  amount: number;
  currency: string;
}

export interface PaymentConfirmation {
  success: boolean;
  paymentIntentId: string;
  orderId: string;
  message: string;
}

export class StripePaymentService {
  // ==================== CREATE PAYMENT INTENT ====================

  static async createPaymentIntent(
    cart: ShoppingCart,
    userId: string
  ): Promise<PaymentIntentResponse> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/payments/create-intent`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          amount: Math.round(cart.total * 100), // Convert to cents
          currency: 'usd',
          userId,
          cartId: cart.id,
          metadata: {
            userId,
            cartId: cart.id,
            itemCount: cart.items.length,
          },
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to create payment intent');
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error creating payment intent:', error);
      throw error;
    }
  }

  // ==================== CONFIRM PAYMENT ====================

  static async confirmPayment(
    paymentIntentId: string,
    paymentMethodId: string
  ): Promise<PaymentConfirmation> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/payments/confirm`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          paymentIntentId,
          paymentMethodId,
        }),
      });

      if (!response.ok) {
        throw new Error('Payment confirmation failed');
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error confirming payment:', error);
      throw error;
    }
  }

  // ==================== INSTANT BUY ====================

  static async instantBuy(
    productId: string,
    quantity: number,
    userId: string,
    savedPaymentMethodId: string,
    savedAddressId: string
  ): Promise<PaymentConfirmation> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/payments/instant-buy`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          productId,
          quantity,
          userId,
          paymentMethodId: savedPaymentMethodId,
          addressId: savedAddressId,
        }),
      });

      if (!response.ok) {
        throw new Error('Instant buy failed');
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error with instant buy:', error);
      throw error;
    }
  }

  // ==================== SAVE PAYMENT METHOD ====================

  static async savePaymentMethod(
    userId: string,
    paymentMethodId: string,
    setAsDefault: boolean = false
  ): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/payments/save-method`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          userId,
          paymentMethodId,
          setAsDefault,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to save payment method');
      }
    } catch (error) {
      console.error('Error saving payment method:', error);
      throw error;
    }
  }

  // ==================== GET SAVED PAYMENT METHODS ====================

  static async getSavedPaymentMethods(userId: string): Promise<any[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/payments/methods?userId=${userId}`);

      if (!response.ok) {
        throw new Error('Failed to fetch payment methods');
      }

      const data = await response.json();
      return data.paymentMethods || [];
    } catch (error) {
      console.error('Error fetching payment methods:', error);
      throw error;
    }
  }

  // ==================== REFUND ====================

  static async refundPayment(
    paymentIntentId: string,
    amount?: number,
    reason?: string
  ): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/payments/refund`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          paymentIntentId,
          amount: amount ? Math.round(amount * 100) : undefined,
          reason,
        }),
      });

      if (!response.ok) {
        throw new Error('Refund failed');
      }
    } catch (error) {
      console.error('Error processing refund:', error);
      throw error;
    }
  }

  // ==================== CALCULATE TAX ====================

  static calculateTax(subtotal: number, state: string): number {
    // Tax rates by state (simplified - use Stripe Tax API in production)
    const taxRates: { [key: string]: number } = {
      CA: 0.0725, // California
      NY: 0.08, // New York
      TX: 0.0625, // Texas
      FL: 0.06, // Florida
      // Add more states...
    };

    const taxRate = taxRates[state] || 0.08; // Default 8%
    return subtotal * taxRate;
  }

  // ==================== CALCULATE SHIPPING ====================

  static calculateShipping(subtotal: number, items: number): number {
    // Free shipping over $50
    if (subtotal >= 50) return 0;

    // $5.99 base + $1 per additional item
    return 5.99 + Math.max(0, items - 1) * 1.0;
  }

  // ==================== VALIDATE CARD ====================

  static validateCardNumber(cardNumber: string): boolean {
    // Luhn algorithm for card validation
    const digits = cardNumber.replace(/\D/g, '');
    if (digits.length < 13 || digits.length > 19) return false;

    let sum = 0;
    let isEven = false;

    for (let i = digits.length - 1; i >= 0; i--) {
      let digit = parseInt(digits[i]);

      if (isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      isEven = !isEven;
    }

    return sum % 10 === 0;
  }

  static validateCVV(cvv: string): boolean {
    return /^\d{3,4}$/.test(cvv);
  }

  static validateExpiry(month: string, year: string): boolean {
    const now = new Date();
    const expiry = new Date(parseInt(year), parseInt(month) - 1);
    return expiry > now;
  }

  // ==================== FORMAT CARD NUMBER ====================

  static formatCardNumber(cardNumber: string): string {
    const digits = cardNumber.replace(/\D/g, '');
    const groups = digits.match(/.{1,4}/g) || [];
    return groups.join(' ');
  }

  static getCardBrand(cardNumber: string): string {
    const digits = cardNumber.replace(/\D/g, '');

    if (/^4/.test(digits)) return 'Visa';
    if (/^5[1-5]/.test(digits)) return 'Mastercard';
    if (/^3[47]/.test(digits)) return 'American Express';
    if (/^6(?:011|5)/.test(digits)) return 'Discover';

    return 'Unknown';
  }
}

// ==================== STRIPE ELEMENTS SETUP ====================

export const stripeElementsOptions = {
  mode: 'payment' as const,
  amount: 0, // Will be set dynamically
  currency: 'usd',
  appearance: {
    theme: 'night' as const,
    variables: {
      colorPrimary: '#ff0000',
      colorBackground: '#0f0f0f',
      colorText: '#ffffff',
      colorDanger: '#ff0000',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      spacingUnit: '4px',
      borderRadius: '8px',
    },
    rules: {
      '.Input': {
        backgroundColor: '#212121',
        border: '1px solid #303030',
        color: '#ffffff',
      },
      '.Input:focus': {
        border: '1px solid #ff0000',
        boxShadow: '0 0 0 1px #ff0000',
      },
      '.Label': {
        color: '#aaaaaa',
        fontSize: '14px',
        fontWeight: '500',
      },
    },
  },
};


