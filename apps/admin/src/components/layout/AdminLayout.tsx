'use client';

import React from 'react';
import { Sidebar } from './Sidebar';
import { Navbar } from './Navbar';

interface AdminLayoutProps {
  children: React.ReactNode;
}

export const AdminLayout: React.FC<AdminLayoutProps> = ({ children }) => {
  return (
    <div className="flex h-screen w-full overflow-hidden bg-slate-950 text-slate-100 antialiased">
      {/* Sidebar: Flex child with fixed width, never overlaps content */}
      <Sidebar />

      {/* Main Content Area: Fills remaining width with independent scrolling */}
      <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden bg-slate-950">
        <Navbar />
        <main className="flex-1 overflow-y-auto p-6 md:p-8">
          <div className="max-w-7xl mx-auto space-y-6 pb-12">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
};
