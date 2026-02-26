import ProductList from "../components/ProductList";

export default function Home() {
  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Product Catalog</h1>
      <ProductList />
    </div>
  );
}
