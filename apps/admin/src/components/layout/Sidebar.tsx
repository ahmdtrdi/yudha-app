'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  FileCheck2,
  Inbox,
  Boxes,
  ScrollText,
  ShieldAlert,
  LogOut,
  Sparkles
} from 'lucide-react';
import { adminAuth } from '@/lib/api-client';

const navItems = [
  {
    label: 'Overview',
    href: '/dashboard',
    icon: LayoutDashboard
  },
  {
    label: 'Content Quality',
    href: '/content-quality',
    icon: FileCheck2,
    badge: 'Core QA'
  },
  {
    label: 'Review Cases',
    href: '/review-cases',
    icon: Inbox,
    badge: 'Triage'
  },
  {
    label: 'Inventory & Coverage',
    href: '/inventory',
    icon: Boxes
  },
  {
    label: 'Audit Trail',
    href: '/audit-logs',
    icon: ScrollText
  }
];

export const Sidebar: React.FC = () => {
  const pathname = usePathname();

  return (
    <aside className="w-64 flex-shrink-0 bg-slate-900/95 border-r border-slate-800 flex flex-col justify-between h-full z-20 select-none">
      {/* Brand Header */}
      <div>
        <div className="h-16 px-5 flex items-center gap-3 border-b border-slate-800">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-indigo-600 to-violet-500 flex items-center justify-center shadow-lg shadow-indigo-500/20 flex-shrink-0">
            <Sparkles className="w-5 h-5 text-white" />
          </div>
          <div className="min-w-0">
            <h1 className="font-bold text-sm text-slate-100 tracking-tight flex items-center gap-1.5">
              YUDHA <span className="text-[11px] px-1.5 py-0.5 rounded bg-indigo-500/20 text-indigo-300 font-semibold border border-indigo-500/30">ADMIN</span>
            </h1>
            <p className="text-xs text-slate-400 font-medium truncate">Content QA & Triage</p>
          </div>
        </div>

        {/* System Role Indicator */}
        <div className="mx-4 my-4 p-3 rounded-xl bg-slate-950/70 border border-slate-800 flex items-center gap-2.5">
          <div className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse flex-shrink-0"></div>
          <div className="flex-1 min-w-0">
            <div className="text-xs font-semibold text-slate-200 truncate">Server Admin Role</div>
            <div className="text-[11px] text-slate-400 truncate">V2 Authoritative Guard</div>
          </div>
          <ShieldAlert className="w-4 h-4 text-emerald-400 flex-shrink-0" />
        </div>

        {/* Navigation List */}
        <div className="px-3 py-2">
          <p className="px-3 text-xs font-semibold uppercase tracking-wider text-slate-400 mb-2">
            Operations
          </p>
          <nav className="space-y-1.5">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = pathname === item.href || (item.href !== '/dashboard' && pathname.startsWith(item.href));

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-medium transition-all ${
                    isActive
                      ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/40 shadow-sm font-semibold'
                      : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <Icon className={`w-4 h-4 ${isActive ? 'text-indigo-400' : 'text-slate-400'}`} />
                    <span>{item.label}</span>
                  </div>
                  {item.badge && (
                    <span
                      className={`text-xs px-2 py-0.5 rounded-md font-semibold ${
                        isActive
                          ? 'bg-indigo-500/30 text-indigo-200'
                          : 'bg-slate-800 text-slate-400'
                      }`}
                    >
                      {item.badge}
                    </span>
                  )}
                </Link>
              );
            })}
          </nav>
        </div>
      </div>

      {/* Footer Info */}
      <div className="p-4 border-t border-slate-800 bg-slate-950/40">
        <div className="flex items-center justify-between text-xs text-slate-400 mb-3 px-1">
          <span>Backend API</span>
          <span className="text-emerald-400 font-mono font-medium flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
            :3000
          </span>
        </div>
        <button
          onClick={() => {
            adminAuth.logout();
            window.location.href = '/login';
          }}
          className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-xs font-semibold text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 border border-slate-800 hover:border-rose-500/20 transition-all cursor-pointer"
        >
          <LogOut className="w-4 h-4" />
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  );
};
