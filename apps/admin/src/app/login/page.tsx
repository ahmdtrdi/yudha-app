'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ShieldCheck, Lock, Mail, Sparkles, ArrowRight } from 'lucide-react';
import { adminAuth } from '@/lib/api-client';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('admin@yudha.app');
  const [password, setPassword] = useState('••••••••••••');
  const [loading, setLoading] = useState(false);

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    adminAuth.login(email);
    setTimeout(() => {
      router.push('/dashboard');
    }, 300);
  };

  const handleQuickLogin = (demoEmail: string) => {
    setEmail(demoEmail);
    adminAuth.login(demoEmail);
    router.push('/dashboard');
  };

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center p-4 relative overflow-hidden">
      {/* Background glow effects */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-indigo-600/10 rounded-full blur-3xl pointer-events-none"></div>
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-violet-600/10 rounded-full blur-3xl pointer-events-none"></div>

      <div className="w-full max-w-md space-y-6 relative z-10">
        {/* Brand Header */}
        <div className="text-center space-y-2">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-tr from-indigo-600 to-violet-500 shadow-xl shadow-indigo-500/30 mb-2">
            <Sparkles className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-100 tracking-tight">
            YUDHA <span className="text-indigo-400">ADMIN</span> PORTAL
          </h1>
          <p className="text-sm text-slate-400 font-medium">
            Content Quality Review & Triage System (PRD V2)
          </p>
        </div>

        {/* Login Card */}
        <div className="glass-panel p-8 space-y-6 shadow-2xl border-slate-800">
          <div className="flex items-center justify-between pb-4 border-b border-slate-800">
            <div className="flex items-center gap-2 text-xs font-bold text-slate-200">
              <ShieldCheck className="w-4 h-4 text-emerald-400" />
              <span>Server-Managed Admin Auth</span>
            </div>
            <span className="text-xs font-mono text-slate-300 bg-slate-900 px-2.5 py-1 rounded-md border border-slate-800 font-semibold">
              Port: 3002
            </span>
          </div>

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                Admin Email Address
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="w-full admin-input pl-10 text-sm"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                Admin Secret / Password
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full admin-input pl-10 text-sm font-mono"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full admin-button-primary text-sm py-3 mt-2 cursor-pointer"
            >
              <span>{loading ? 'Authenticating...' : 'Sign In as Administrator'}</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </form>

          {/* Quick Demo Shortcuts */}
          <div className="pt-5 border-t border-slate-800 space-y-2.5">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block">
              Quick Role Test Logins:
            </span>
            <div className="grid grid-cols-2 gap-2.5">
              <button
                type="button"
                onClick={() => handleQuickLogin('admin@yudha.app')}
                className="p-3 rounded-xl bg-slate-900/90 hover:bg-indigo-950/40 border border-slate-800 hover:border-indigo-500/50 text-left transition-all cursor-pointer"
              >
                <span className="text-xs font-bold text-indigo-300 block">Admin QA Lead</span>
                <span className="text-[11px] text-slate-400 block font-mono mt-0.5">admin@yudha.app</span>
              </button>

              <button
                type="button"
                onClick={() => handleQuickLogin('sme-review@yudha.app')}
                className="p-3 rounded-xl bg-slate-900/90 hover:bg-violet-950/40 border border-slate-800 hover:border-violet-500/50 text-left transition-all cursor-pointer"
              >
                <span className="text-xs font-bold text-violet-300 block">SME Reviewer</span>
                <span className="text-[11px] text-slate-400 block font-mono mt-0.5">sme-review@yudha.app</span>
              </button>
            </div>
          </div>
        </div>

        {/* Security Note */}
        <p className="text-center text-xs text-slate-400">
          Enforces server-managed admin role. Mobile clients are never authoritative.
        </p>
      </div>
    </div>
  );
}
