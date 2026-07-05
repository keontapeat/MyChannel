import ProductClient from './ProductClient';

export async function generateStaticParams() {
  return [{ id: '_fallback' }];
}

export default async function ProductPage(props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  return <ProductClient productId={params.id} />;
}
