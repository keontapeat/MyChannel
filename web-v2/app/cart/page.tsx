// Shopping Cart Page - YouTube-Level Professional Design
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ShoppingService } from '@/lib/firebase/shopping-service';
import type { ShoppingCart, CartItem } from '@/types/shopping';

export default function CartPage() {
  const router = useRouter();
  const [cart, setCart] = useState<ShoppingCart | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState<string | null>(null);

  useEffect(() => {
    loadCart();
  }, []);

  async function loadCart() {
    try {
      setLoading(true);
      // Get current user ID (replace with actual auth)
      const userId = 'current-user-id';
      const cartData = await ShoppingService.getCart(userId);
      setCart(cartData);
    } catch (error) {
      console.error('Error loading cart:', error);
    } finally {
      setLoading(false);
    }
  }

  async function updateQuantity(itemId: string, newQuantity: number) {
    if (!cart) return;

    try {
      setUpdating(itemId);
      const userId = 'current-user-id';
      const updatedCart = await ShoppingService.updateCartItemQuantity(userId, itemId, newQuantity);
      setCart(updatedCart);
    } catch (error) {
      console.error('Error updating quantity:', error);
    } finally {
      setUpdating(null);
    }
  }

  async function removeItem(itemId: string) {
    if (!cart) return;

    try {
      setUpdating(itemId);
      const userId = 'current-user-id';
      const updatedCart = await ShoppingService.removeFromCart(userId, itemId);
      setCart(updatedCart);
    } catch (error) {
      console.error('Error removing item:', error);
    } finally {
      setUpdating(null);
    }
  }

  function handleCheckout() {
    router.push('/checkout');
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <div className="animate-spin w-12 h-12 border-4 border-[rgb(var(--color-primary))] border-t-transparent rounded-full" />
      </div>
    );
  }

  if (!cart || cart.items.length === 0) {
    return (
      <div className="min-h-screen bg-[rgb(var(--color-background))] flex items-center justify-center">
        <div className="text-center">
          <svg className="w-24 h-24 mx-auto mb-6 text-[rgb(var(--color-text-secondary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
          <h1 className="text-[24px] font-semibold text-[rgb(var(--color-text-primary))] mb-2">
            Your cart is empty
          </h1>
          <p className="text-[15px] text-[rgb(var(--color-text-secondary))] mb-6">
            Add items to get started
          </p>
          <button
            onClick={() => router.push('/live/shopping')}
            className="px-6 py-3 rounded-lg bg-[rgb(var(--color-primary))] text-white text-[15px] font-semibold hover:opacity-90 transition-all"
          >
            Start Shopping
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[1400px] mx-auto px-4 md:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <h1 className="text-[28px] font-semibold text-[rgb(var(--color-text-primary))]">
            Shopping Cart ({cart.items.length} {cart.items.length === 1 ? 'item' : 'items'})
          </h1>
          <button
            onClick={() => router.back()}
            className="text-[15px] text-[rgb(var(--color-text-secondary))] hover:text-[rgb(var(--color-text-primary))] transition-colors"
          >
            Continue Shopping
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Cart Items */}
          <div className="lg:col-span-2 space-y-4">
            {cart.items.map((item) => (
              <div
                key={item.id}
                className="p-6 rounded-xl bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))]"
              >
                <div className="flex gap-6">
                  {/* Product Image */}
                  <div className="flex-shrink-0">
                    <img
                      src={item.product.imageURL}
                      alt={item.product.name}
                      className="w-32 h-32 rounded-lg object-cover"
                    />
                  </div>

                  {/* Product Info */}
                  <div className="flex-1 min-w-0">
                    <h3 className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-2 line-clamp-2">
                      {item.product.name}
                    </h3>
                    
                    {/* Variants */}
                    {item.selectedVariants && Object.keys(item.selectedVariants).length > 0 && (
                      <div className="flex flex-wrap gap-2 mb-3">
                        {Object.entries(item.selectedVariants).map(([key, value]) => (
                          <span
                            key={key}
                            className="px-2 py-1 rounded text-[13px] bg-[rgb(var(--color-background))] text-[rgb(var(--color-text-secondary))]"
                          >
                            {key}: {value}
                          </span>
                        ))}
                      </div>
                    )}

                    {/* Price */}
                    <div className="flex items-center gap-3 mb-4">
                      <span className="text-[20px] font-semibold text-[rgb(var(--color-text-primary))]">
                        ${item.price.toFixed(2)}
                      </span>
                      {item.product.originalPrice && item.product.originalPrice > item.price && (
                        <span className="text-[15px] text-[rgb(var(--color-text-secondary))] line-through">
                          ${item.product.originalPrice.toFixed(2)}
                        </span>
                      )}
                    </div>

                    {/* Quantity Controls */}
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <button
                          onClick={() => updateQuantity(item.id, item.quantity - 1)}
                          disabled={updating === item.id || item.quantity <= 1}
                          className="w-8 h-8 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] hover:border-[rgb(var(--color-text-secondary))]/30 flex items-center justify-center transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <svg className="w-4 h-4 text-[rgb(var(--color-text-primary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 12H4" />
                          </svg>
                        </button>
                        <span className="text-[15px] font-medium text-[rgb(var(--color-text-primary))] w-8 text-center">
                          {item.quantity}
                        </span>
                        <button
                          onClick={() => updateQuantity(item.id, item.quantity + 1)}
                          disabled={updating === item.id || item.quantity >= item.product.stockQuantity}
                          className="w-8 h-8 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] hover:border-[rgb(var(--color-text-secondary))]/30 flex items-center justify-center transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <svg className="w-4 h-4 text-[rgb(var(--color-text-primary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                          </svg>
                        </button>
                      </div>

                      {/* Remove Button */}
                      <button
                        onClick={() => removeItem(item.id)}
                        disabled={updating === item.id}
                        className="text-[14px] text-red-500 hover:text-red-600 font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        Remove
                      </button>
                    </div>

                    {/* Subtotal */}
                    <div className="mt-3 pt-3 border-t border-[rgb(var(--color-border))]">
                      <div className="flex items-center justify-between">
                        <span className="text-[14px] text-[rgb(var(--color-text-secondary))]">
                          Subtotal
                        </span>
                        <span className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))]">
                          ${item.subtotal.toFixed(2)}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Order Summary */}
          <div className="lg:col-span-1">
            <div className="sticky top-8 p-6 rounded-xl bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))]">
              <h2 className="text-[20px] font-semibold text-[rgb(var(--color-text-primary))] mb-6">
                Order Summary
              </h2>

              <div className="space-y-4 mb-6">
                <div className="flex items-center justify-between">
                  <span className="text-[15px] text-[rgb(var(--color-text-secondary))]">
                    Subtotal
                  </span>
                  <span className="text-[15px] font-medium text-[rgb(var(--color-text-primary))]">
                    ${cart.subtotal.toFixed(2)}
                  </span>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-[15px] text-[rgb(var(--color-text-secondary))]">
                    Shipping
                  </span>
                  <span className="text-[15px] font-medium text-[rgb(var(--color-text-primary))]">
                    {cart.shipping === 0 ? 'FREE' : `$${cart.shipping.toFixed(2)}`}
                  </span>
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-[15px] text-[rgb(var(--color-text-secondary))]">
                    Tax
                  </span>
                  <span className="text-[15px] font-medium text-[rgb(var(--color-text-primary))]">
                    ${cart.tax.toFixed(2)}
                  </span>
                </div>

                {cart.shipping === 0 && (
                  <div className="flex items-center gap-2 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                    <svg className="w-5 h-5 text-green-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-[13px] text-green-500 font-medium">
                      You saved on shipping!
                    </span>
                  </div>
                )}

                {cart.subtotal < 50 && cart.shipping > 0 && (
                  <div className="flex items-center gap-2 p-3 rounded-lg bg-blue-500/10 border border-blue-500/20">
                    <svg className="w-5 h-5 text-blue-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                    </svg>
                    <span className="text-[13px] text-blue-500 font-medium">
                      Add ${(50 - cart.subtotal).toFixed(2)} for free shipping
                    </span>
                  </div>
                )}
              </div>

              <div className="pt-4 border-t border-[rgb(var(--color-border))] mb-6">
                <div className="flex items-center justify-between">
                  <span className="text-[18px] font-semibold text-[rgb(var(--color-text-primary))]">
                    Total
                  </span>
                  <span className="text-[24px] font-semibold text-[rgb(var(--color-text-primary))]">
                    ${cart.total.toFixed(2)}
                  </span>
                </div>
              </div>

              <button
                onClick={handleCheckout}
                className="w-full px-6 py-3 rounded-lg bg-[rgb(var(--color-primary))] text-white text-[15px] font-semibold hover:opacity-90 transition-all mb-3"
              >
                Proceed to Checkout
              </button>

              <button
                onClick={() => router.push('/live/shopping')}
                className="w-full px-6 py-3 rounded-lg bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] text-[rgb(var(--color-text-primary))] text-[15px] font-semibold hover:border-[rgb(var(--color-text-secondary))]/30 transition-all"
              >
                Continue Shopping
              </button>

              {/* Security Badge */}
              <div className="mt-6 pt-6 border-t border-[rgb(var(--color-border))]">
                <div className="flex items-center justify-center gap-2 text-[rgb(var(--color-text-secondary))]">
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span className="text-[13px] font-medium">
                    Secure Checkout with Stripe
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}






