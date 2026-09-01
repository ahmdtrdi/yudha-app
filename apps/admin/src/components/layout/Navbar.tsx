'use client';

import React, { useState, useEffect } from 'react';
import { Search, Bell, ShieldCheck, UserCheck } from 'lucide-react';
import { adminAuth } from '@/lib/api-client';
import { AdminUser } from '@/types/admin';

export const Navbar: React.FC = () => {
  const [user, setUser] = useState<AdminUser | null>(null);

  useEffect(() => {
    setUser(adminAuth.getUser());
  }, []);

  return (
    <header className="h-16 flex-shrink-0 border-b border-slate-800 bg-slate-900/80 backdrop-blur-md px-6 md:px-8 flex items-center justify-between z-10 w-full">
      {/* Search / Context */}
      <div className="flex items-center gap-4 flex-1 max-w-lg">
        <div className="relative w-full">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search questions by ID, prompt stem, or skill..."
            className="w-full bg-slate-950/80 border border-slate-800 text-sm text-slate-200 pl-10 pr-4 py-2 rounded-xl outline-none focus:border-indigo-500/60 focus:ring-1 focus:ring-indigo-500/30 transition-all placeholder:text-slate-400"
          />
        </div>
      </div>

      {/* Right Controls */}
      <div className="flex items-center gap-4 ml-4">
        {/* Environment Badge */}
        <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-800/80 border border-slate-700 text-xs text-slate-300 font-mono font-medium">
          <span className="w-2 h-2 rounded-full bg-indigo-400 animate-pulse"></span>
          <span>ADMIN PORT: 3002</span>
        </div>

        {/* Notifications */}
        <button className="relative p-2.5 rounded-xl text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors cursor-pointer">
          <Bell className="w-4 h-4" />
          <span className="absolute top-2 right-2 w-2 h-2 rounded-full bg-rose-500"></span>
        </button>

        <div className="h-6 w-px bg-slate-800"></div>

        {/* Profile */}
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-indigo-600/20 border border-indigo-500/30 flex items-center justify-center text-indigo-300 font-bold text-sm">
            <UserCheck className="w-4 h-4" />
          </div>
          <div className="text-left hidden sm:block">
            <div className="text-sm font-semibold text-slate-200 flex items-center gap-1.5">
              <span>{user?.name || 'Admin QA'}</span>
              <ShieldCheck className="w-4 h-4 text-indigo-400" />
            </div>
            <div className="text-xs text-slate-400">{user?.email || 'admin@yudha.app'}</div>
          </div>
        </div>
      </div>
    </header>
  );
};
