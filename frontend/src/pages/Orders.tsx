import { useEffect, useState } from "react";
import axios from "axios";
import { useAuth } from "../App";

interface OrderItem {
  id: string;
  product_id: string;
  quantity: number;
  unit_price: number;
}

interface Order {
  id: string;
  status: string;
  total: number;
  created_at: string;
  items: OrderItem[];
}

export default function Orders() {
  const { userId } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!userId) return;
    axios
      .get<Order[]>(`/orders/user/${userId}`, { withCredentials: true })
      .then((r) => setOrders(r.data))
      .catch(() => setError("Failed to load orders"))
      .finally(() => setLoading(false));
  }, [userId]);

  if (loading) return <p className="text-center py-12 text-gray-500">Loading orders…</p>;
  if (error) return <p className="text-center py-12 text-red-500">{error}</p>;
  if (orders.length === 0)
    return <p className="text-center py-12 text-gray-400">No orders yet.</p>;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">My Orders</h1>
      <div className="space-y-4">
        {orders.map((order) => (
          <div key={order.id} className="bg-white rounded-xl shadow p-5">
            <div className="flex items-center justify-between mb-3">
              <div>
                <p className="font-semibold text-sm"># {order.id}</p>
                <p className="text-xs text-gray-400">
                  {new Date(order.created_at).toLocaleString()}
                </p>
              </div>
              <span
                className={`text-xs font-medium px-2 py-1 rounded-full ${
                  order.status === "pending"
                    ? "bg-yellow-100 text-yellow-700"
                    : order.status === "shipped"
                    ? "bg-blue-100 text-blue-700"
                    : "bg-green-100 text-green-700"
                }`}
              >
                {order.status}
              </span>
            </div>
            <ul className="divide-y divide-gray-100 text-sm">
              {order.items.map((item) => (
                <li key={item.id} className="py-1 flex justify-between">
                  <span>
                    Product <code className="text-xs">{item.product_id}</code> × {item.quantity}
                  </span>
                  <span>${(item.unit_price * item.quantity).toFixed(2)}</span>
                </li>
              ))}
            </ul>
            <div className="mt-3 text-right font-semibold">
              Total: ${Number(order.total).toFixed(2)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
