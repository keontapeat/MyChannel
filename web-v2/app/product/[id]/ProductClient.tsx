'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';

interface ProductClientProps {
  productId: string;
}

export default function ProductClient({ productId: initialProductId }: ProductClientProps) {
  const [productId, setProductId] = useState(initialProductId === '_fallback' ? '' : initialProductId);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (initialProductId !== '_fallback') return;
    const segments = window.location.pathname.split('/').filter(Boolean);
    const productIndex = segments.indexOf('product');
    const pathId = productIndex >= 0 ? segments[productIndex + 1] : '';
    if (pathId && pathId !== '_fallback') setProductId(decodeURIComponent(pathId));
  }, [initialProductId]);

  useEffect(() => {
    if (!productId) return;
    setLoading(false);
  }, [productId]);

  return (
    <div className="min-h-screen bg-white dark:bg-black">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <Link 
          href="/" 
          className="inline-flex items-center text-gray-600 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-500 mb-6"
        >
          ← Back to Home
        </Link>

        {loading ? (
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="text-gray-500">Loading product...</div>
          </div>
        ) : (
          <div className="bg-gray-50 dark:bg-gray-900 rounded-2xl p-8 text-center">
            <h1 className="text-2xl font-bold text-black dark:text-white mb-4">
              Product Details
            </h1>
            <p className="text-gray-600 dark:text-gray-400 mb-4">
              Product ID: {productId}
            </p>
            <p className="text-gray-500 dark:text-gray-500">
              Product feature coming soon...
            </p>
          </div>
        )}
      </div>
    </div>
  );
}






