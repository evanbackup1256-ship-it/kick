import { AdminApp } from "@/components/admin/AdminApp";
import { AdminGate } from "@/components/guard/AdminGate";

export default function AdminPage() {
  return (
    <AdminGate>
      <AdminApp />
    </AdminGate>
  );
}