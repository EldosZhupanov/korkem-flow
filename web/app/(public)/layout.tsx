import { PublicNav } from "@/components/public-nav";
import { PublicFooter } from "@/components/public-footer";

export default function PublicLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <PublicNav />
      {/* Nav is fixed; pages get top offset, the home hero pulls itself under it. */}
      <main className="flex-1 pt-20 sm:pt-24">{children}</main>
      <PublicFooter />
    </div>
  );
}
