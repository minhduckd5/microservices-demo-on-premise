import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../App";
import axios from "axios";

export default function Header() {
  const { userId, setUserId } = useAuth();
  const navigate = useNavigate();

  const logout = async () => {
    await axios.post("/auth/logout", {}, { withCredentials: true });
    setUserId(null);
    navigate("/login");
  };

  return (
    <header className="bg-indigo-600 text-white shadow">
      <div className="container mx-auto px-4 py-3 flex items-center justify-between">
        <Link to="/" className="text-xl font-bold tracking-tight">
          🛒 MicroShop
        </Link>
        <nav className="flex items-center gap-6 text-sm font-medium">
          {userId ? (
            <>
              <Link to="/" className="hover:underline">Catalog</Link>
              <Link to="/orders" className="hover:underline">My Orders</Link>
              <button
                onClick={logout}
                className="bg-white text-indigo-600 px-3 py-1 rounded hover:bg-indigo-50 transition"
              >
                Logout
              </button>
            </>
          ) : (
            <Link to="/login" className="hover:underline">Login</Link>
          )}
        </nav>
      </div>
    </header>
  );
}
