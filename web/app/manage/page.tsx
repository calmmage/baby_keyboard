import { redirect } from 'next/navigation';
import { createClient } from "@/lib/supabase/server";
import AdminDashboard from "@/components/admin-dashboard";

export default async function AdminPage() {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user) {
    redirect("/auth/login");
  }

  return <AdminDashboard user={data.user} />;
}
