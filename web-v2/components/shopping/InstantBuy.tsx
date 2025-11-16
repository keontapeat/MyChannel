// Instant Buy Component - One-Click Purchase Flow
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { StripePaymentService } from '@/lib/stripe/payment-service';
import type { Product, Address, SavedPaymentMethod } from '@/types/shopping';

interface InstantBuyProps {
  product: Product;
  quantity: number;
  selectedVariants?: { [key: string]: string };
  onClose: () => void;
}

export default function InstantBuy({ product, quantity, selectedVariants, onClose }: InstantBuyProps) {
  const router = useRouter();
  const [savedPaymentMethods, setSavedPaymentMethods] = useState<SavedPaymentMethod[]>([]);
  const [savedAddresses, setSavedAddresses] = useState<Address[]>([]);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<string>('');
  const [selectedAddress, setSelectedAddress] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadSavedData();
  }, []);

  async function loadSavedData() {
    try {
      setLoading(true);
      // Get current user ID (replace with actual auth)
      const userId = 'current-user-id';

      // Load saved payment methods
      const methods = await StripePaymentService.getSavedPaymentMethods(userId);
      setSavedPaymentMethods(methods);

      // Load saved addresses (mock data - replace with actual API)
      const addresses: Address[] = [
        {
          fullName: 'John Doe',
          addressLine1: '123 Main St',
          addressLine2: 'Apt 4B',
          city: 'San Francisco',
          state: 'CA',
          zipCode: '94102',
          country: 'US',
          phoneNumber: '+1 (555) 123-4567',
        },
      ];
      setSavedAddresses(addresses);

      // Set defaults
      if (methods.length > 0) {
        const defaultMethod = methods.find((m) => m.isDefault) || methods[0];
        setSelectedPaymentMethod(defaultMethod.id);
      }
      if (addresses.length > 0) {
        setSelectedAddress('0'); // Index-based for demo
      }
    } catch (err) {
      console.error('Error loading saved data:', err);
      setError('Failed to load saved information');
    } finally {
      setLoading(false);
    }
  }

  async function handleInstantBuy() {
    if (!selectedPaymentMethod || !selectedAddress) {
      setError('Please select payment method and address');
      return;
    }

    try {
      setProcessing(true);
      setError(null);

      const userId = 'current-user-id';
      const result = await StripePaymentService.instantBuy(
        product.id,
        quantity,
        userId,
        selectedPaymentMethod,
        selectedAddress
      );

      if (result.success) {
        // Show success and redirect to order
        router.push(`/order/${result.orderId}`);
      } else {
        setError(result.message || 'Purchase failed');
      }
    } catch (err: any) {
      console.error('Error with instant buy:', err);
      setError(err.message || 'An error occurred');
    } finally {
      setProcessing(false);
    }
  }

  const subtotal = product.price * quantity;
  const tax = subtotal * 0.08; // 8% tax
  const shipping = subtotal >= 50 ? 0 : 5.99;
  const total = subtotal + tax + shipping;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="w-full max-w-2xl bg-[rgb(var(--color-surface))] rounded-xl overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-[rgb(var(--color-border))]">
          <div className="flex items-center gap-3">
            <svg className="w-6 h-6 text-[rgb(var(--color-primary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            <h2 className="text-[24px] font-semibold text-[rgb(var(--color-text-primary))]">
              Instant Buy
            </h2>
          </div>
          <button
            onClick={onClose}
            disabled={processing}
            className="w-10 h-10 rounded-lg bg-[rgb(var(--color-background))] flex items-center justify-center hover:bg-[rgb(var(--color-surface-hover))] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg className="w-6 h-6 text-[rgb(var(--color-text-primary))]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin w-12 h-12 border-4 border-[rgb(var(--color-primary))] border-t-transparent rounded-full" />
            </div>
          ) : (
            <div className="space-y-6">
              {/* Product Summary */}
              <div className="p-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))]">
                <div className="flex gap-4">
                  <img
                    src={product.imageURL}
                    alt={product.name}
                    className="w-20 h-20 rounded-lg object-cover flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <h3 className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-1 line-clamp-2">
                      {product.name}
                    </h3>
                    <div className="flex items-center gap-3">
                      <span className="text-[18px] font-semibold text-[rgb(var(--color-text-primary))]">
                        ${product.price.toFixed(2)}
                      </span>
                      <span className="text-[14px] text-[rgb(var(--color-text-secondary))]">
                        Qty: {quantity}
                      </span>
                    </div>
                    {selectedVariants && Object.keys(selectedVariants).length > 0 && (
                      <div className="flex flex-wrap gap-2 mt-2">
                        {Object.entries(selectedVariants).map(([key, value]) => (
                          <span
                            key={key}
                            className="px-2 py-0.5 rounded text-[12px] bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-secondary))]"
                          >
                            {key}: {value}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Payment Method */}
              <div>
                <label className="block text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">
                  Payment Method
                </label>
                {savedPaymentMethods.length === 0 ? (
                  <div className="p-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] text-center">
                    <p className="text-[14px] text-[rgb(var(--color-text-secondary))] mb-3">
                      No saved payment methods
                    </p>
                    <button
                      onClick={() => router.push('/settings/payment-methods')}
                      className="text-[14px] text-[rgb(var(--color-primary))] hover:underline font-medium"
                    >
                      Add Payment Method
                    </button>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {savedPaymentMethods.map((method) => (
                      <button
                        key={method.id}
                        onClick={() => setSelectedPaymentMethod(method.id)}
                        className={`w-full p-4 rounded-lg border-2 transition-all text-left ${
                          selectedPaymentMethod === method.id
                            ? 'border-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/5'
                            : 'border-[rgb(var(--color-border))] hover:border-[rgb(var(--color-text-secondary))]/30'
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div className="w-12 h-8 rounded bg-[rgb(var(--color-background))] flex items-center justify-center">
                              <span className="text-[12px] font-semibold text-[rgb(var(--color-text-primary))]">
                                {method.brand?.toUpperCase()}
                              </span>
                            </div>
                            <div>
                              <div className="text-[15px] font-medium text-[rgb(var(--color-text-primary))]">
                                •••• {method.last4}
                              </div>
                              <div className="text-[13px] text-[rgb(var(--color-text-secondary))]">
                                Expires {method.expiryMonth}/{method.expiryYear}
                              </div>
                            </div>
                          </div>
                          {method.isDefault && (
                            <span className="px-2 py-1 rounded text-[12px] font-medium bg-blue-500/20 text-blue-500">
                              Default
                            </span>
                          )}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Shipping Address */}
              <div>
                <label className="block text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">
                  Shipping Address
                </label>
                {savedAddresses.length === 0 ? (
                  <div className="p-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))] text-center">
                    <p className="text-[14px] text-[rgb(var(--color-text-secondary))] mb-3">
                      No saved addresses
                    </p>
                    <button
                      onClick={() => router.push('/settings/addresses')}
                      className="text-[14px] text-[rgb(var(--color-primary))] hover:underline font-medium"
                    >
                      Add Address
                    </button>
                  </div>
                ) : (
                  <div className="space-y-2">
                    {savedAddresses.map((address, index) => (
                      <button
                        key={index}
                        onClick={() => setSelectedAddress(index.toString())}
                        className={`w-full p-4 rounded-lg border-2 transition-all text-left ${
                          selectedAddress === index.toString()
                            ? 'border-[rgb(var(--color-primary))] bg-[rgb(var(--color-primary))]/5'
                            : 'border-[rgb(var(--color-border))] hover:border-[rgb(var(--color-text-secondary))]/30'
                        }`}
                      >
                        <div className="text-[15px] font-medium text-[rgb(var(--color-text-primary))] mb-1">
                          {address.fullName}
                        </div>
                        <div className="text-[14px] text-[rgb(var(--color-text-secondary))]">
                          {address.addressLine1}
                          {address.addressLine2 && `, ${address.addressLine2}`}
                        </div>
                        <div className="text-[14px] text-[rgb(var(--color-text-secondary))]">
                          {address.city}, {address.state} {address.zipCode}
                        </div>
                        <div className="text-[14px] text-[rgb(var(--color-text-secondary))]">
                          {address.phoneNumber}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Order Summary */}
              <div className="p-4 rounded-lg bg-[rgb(var(--color-background))] border border-[rgb(var(--color-border))]">
                <h3 className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))] mb-3">
                  Order Summary
                </h3>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-[14px] text-[rgb(var(--color-text-secondary))]">Subtotal</span>
                    <span className="text-[14px] font-medium text-[rgb(var(--color-text-primary))]">
                      ${subtotal.toFixed(2)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[14px] text-[rgb(var(--color-text-secondary))]">Shipping</span>
                    <span className="text-[14px] font-medium text-[rgb(var(--color-text-primary))]">
                      {shipping === 0 ? 'FREE' : `$${shipping.toFixed(2)}`}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[14px] text-[rgb(var(--color-text-secondary))]">Tax</span>
                    <span className="text-[14px] font-medium text-[rgb(var(--color-text-primary))]">
                      ${tax.toFixed(2)}
                    </span>
                  </div>
                  <div className="pt-2 border-t border-[rgb(var(--color-border))] flex items-center justify-between">
                    <span className="text-[16px] font-semibold text-[rgb(var(--color-text-primary))]">Total</span>
                    <span className="text-[20px] font-semibold text-[rgb(var(--color-text-primary))]">
                      ${total.toFixed(2)}
                    </span>
                  </div>
                </div>
              </div>

              {/* Error Message */}
              {error && (
                <div className="p-4 rounded-lg bg-red-500/10 border border-red-500/20">
                  <div className="flex items-start gap-3">
                    <svg className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                    </svg>
                    <p className="text-[14px] text-red-500">{error}</p>
                  </div>
                </div>
              )}

              {/* Action Buttons */}
              <div className="flex gap-3">
                <button
                  onClick={onClose}
                  disabled={processing}
                  className="flex-1 px-6 py-3 rounded-lg bg-[rgb(var(--color-surface))] border border-[rgb(var(--color-border))] text-[rgb(var(--color-text-primary))] text-[15px] font-semibold hover:border-[rgb(var(--color-text-secondary))]/30 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Cancel
                </button>
                <button
                  onClick={handleInstantBuy}
                  disabled={processing || !selectedPaymentMethod || !selectedAddress}
                  className="flex-1 px-6 py-3 rounded-lg bg-[rgb(var(--color-primary))] text-white text-[15px] font-semibold hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2"
                >
                  {processing ? (
                    <>
                      <div className="animate-spin w-5 h-5 border-2 border-white border-t-transparent rounded-full" />
                      Processing...
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                      </svg>
                      Complete Purchase
                    </>
                  )}
                </button>
              </div>

              {/* Security Notice */}
              <div className="flex items-center justify-center gap-2 text-[rgb(var(--color-text-secondary))]">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span className="text-[12px]">Secure payment powered by Stripe</span>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}


