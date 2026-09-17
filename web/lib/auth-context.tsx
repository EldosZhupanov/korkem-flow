"use client";

import * as React from "react";
import { useRouter, usePathname } from "next/navigation";
import { korkemApi, type CompanyDetails } from "./korkem-api";

interface AuthContextType {
  user: string | null;
  company: CompanyDetails | null;
  loading: boolean;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
}

const AuthContext = React.createContext<AuthContextType>({
  user: null,
  company: null,
  loading: true,
  logout: async () => {},
  refresh: async () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = React.useState<string | null>(null);
  const [company, setCompany] = React.useState<CompanyDetails | null>(null);
  const [loading, setLoading] = React.useState(true);

  const checkAuth = React.useCallback(async () => {
    try {
      setLoading(true);
      const loggedUser = await korkemApi.getLoggedUser();
      
      if (!loggedUser || loggedUser === "Guest") {
        setUser(null);
        setCompany(null);
        if (pathname.startsWith("/app")) {
          router.push(`/login?redirect=${encodeURIComponent(pathname)}`);
        }
        return;
      }

      setUser(loggedUser);

      // Fetch company details for current user context
      try {
        const details = await korkemApi.getCompanyDetails();
        setCompany(details);
      } catch (companyErr) {
        console.warn("Failed to load company details:", companyErr);
      }
    } catch (err) {
      setUser(null);
      setCompany(null);
      if (pathname.startsWith("/app")) {
        router.push(`/login?redirect=${encodeURIComponent(pathname)}`);
      }
    } finally {
      setLoading(false);
    }
  }, [pathname, router]);

  React.useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  async function handleLogout() {
    try {
      await korkemApi.logout();
    } catch (e) {
      console.warn("Logout error:", e);
    } finally {
      setUser(null);
      setCompany(null);
      router.push("/login");
    }
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        company,
        loading,
        logout: handleLogout,
        refresh: checkAuth,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return React.useContext(AuthContext);
}
