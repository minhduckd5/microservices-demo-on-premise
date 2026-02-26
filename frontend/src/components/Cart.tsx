import axios from "axios";
import { useState } from "react";
import { useAuth } from "../App";

interface Product {
  id: string;
  name: string;
  price: number;
}

interface CartItem {
  product: Product;
  quantity: number;
}

interface Props {
  cart: CartItem[];
  setCart: React.Dispatch<React.SetStateAction<CartItem[]>>;
}

export default function Cart({ cart, setCart }: Props) {
  const { userId } = useAuth();
  const [status, setStatus] = useState<{ ok: boolean; msg: string } | null>(null);

  const total = cart.reduce((sum, i) => sum + i.product.price * i.quantity, 0);

  const removeItem = (productId: string) => {
    setCart((prev) => prev.filter((i) => i.product.id !== productId));
  };

  const placeOrder = async () => {
    if (!userId || cart.length === 0) return;
    try {
      await axios.post(
        "/orders",
        {
          user_id: userId,
          items: cart.map((i) => ({
            product_id: i.product.id,
            quantity: i.quantity,
            unit_price: i.product.price,
          })),
        },
        { withCredentials: true }
      );
      setCart([]);
      setStatus({ ok: true, msg: "Order placed successfully!" });
    } catch {
      setStatus({ ok: false, msg: "Failed to place order. Please try again." });
    }
  };

  return (
    <aside className="w-full lg:w-80 bg-white rounded-xl shadow p-5 h-fit sticky top-4">
      <h2 className="text-lg font-bold mb-4">🛒 Cart</h2>
      {status && (
        <p
          className={`text-sm mb-3 px-3 py-2 rounded ${
            status.ok
              ? "bg-green-50 text-green-700 border border-green-200"
              : "bg-red-50 text-red-600 border border-red-200"
          }`}
        >
          {status.msg}
        </p>
      )}
      {cart.length === 0 ? (
        <p className="text-sm text-gray-400">Your cart is empty.</p>
      ) : (
        <>
          <ul className="divide-y divide-gray-100">
            {cart.map((item) => (
              <li key={item.product.id} className="flex items-center justify-between py-2">
                <div>
                  <p className="text-sm font-medium">{item.product.name}</p>
                  <p className="text-xs text-gray-400">
                    {item.quantity} × ${Number(item.product.price).toFixed(2)}
                  </p>
                </div>
                <button
                  onClick={() => removeItem(item.product.id)}
                  className="text-red-400 hover:text-red-600 text-xs"
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
          <div className="mt-4 border-t pt-3 flex items-center justify-between font-semibold">
            <span>Total</span>
            <span>${total.toFixed(2)}</span>
          </div>
          <button
            onClick={placeOrder}
            className="mt-4 w-full bg-indigo-600 text-white py-2 rounded hover:bg-indigo-700 transition text-sm font-medium"
          >
            Place Order
          </button>
        </>
      )}
    </aside>
  );
}
