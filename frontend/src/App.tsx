import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import Header from "./components/Header";
import Home from "./pages/Home";
import Login from "./pages/Login";
import Orders from "./pages/Orders";
import { createContext, useContext, useState, type ReactNode } from "react";

interface AuthCtx {
  userId: string | null;
  setUserId: (id: string | null) => void;
}

export const AuthContext = createContext<AuthCtx>({ userId: null, setUserId: () => {} });
export const useAuth = () => useContext(AuthContext);

function PrivateRoute({ children }: { children: ReactNode }) {
  const { userId } = useAuth();
  return userId ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  const [userId, setUserId] = useState<string | null>(null);

  return (
    <AuthContext.Provider value={{ userId, setUserId }}>
      <BrowserRouter>
        <Header />
        <main className="container mx-auto px-4 py-8">
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/" element={<PrivateRoute><Home /></PrivateRoute>} />
            <Route path="/orders" element={<PrivateRoute><Orders /></PrivateRoute>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
      </BrowserRouter>
    </AuthContext.Provider>
  );
}
