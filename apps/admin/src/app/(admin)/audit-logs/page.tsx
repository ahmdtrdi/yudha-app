'use client';

import React, { useState, useEffect } from 'react';
import { ShieldCheck, RefreshCw, User, Clock } from 'lucide-react';
import { adminApi } from '@/lib/api-client';
import { AuditLogEntry } from '@/types/admin';

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<AuditLogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const loadLogs = async () => {
    setLoading(true);
    try {
      const data = await adminApi.getAuditLogs();
      setLogs(data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, []);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-50 tracking-tight flex items-center gap-3">
            Immutable Administrative Audit Trail
          </h1>
          <p className="text-sm text-slate-300 mt-1.5 font-medium">
            Cryptographically tracked audit entries for question deactivations, case resolutions, and psychometric invalidations.
          </p>
        </div>
        <button
          onClick={loadLogs}
          className="admin-button-secondary text-sm self-start sm:self-auto cursor-pointer"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Trail</span>
        </button>
      </div>

      {/* Security Banner */}
      <div className="p-5 rounded-2xl bg-slate-900/90 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-indigo-500/10 text-indigo-400 border border-indigo-500/25 flex-shrink-0">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <div>
            <div className="text-sm font-bold text-slate-100">
              PRD Section 16 & 17 Compliance
            </div>
            <div className="text-xs text-slate-300 mt-0.5 font-medium">
              All administrative actions require explicit justification, server-managed admin role, and stable idempotency keys.
            </div>
          </div>
        </div>
        <span className="text-xs font-mono font-bold text-emerald-400 bg-emerald-500/10 px-3.5 py-1.5 rounded-lg border border-emerald-500/25 self-start sm:self-auto">
          AUDIT ENFORCED
        </span>
      </div>

      {/* Logs Table */}
      <div className="glass-panel overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950/90 text-slate-400 uppercase tracking-wider font-bold text-xs border-b border-slate-800">
              <tr>
                <th className="px-6 py-4">Timestamp (UTC)</th>
                <th className="px-5 py-4">Admin Operator</th>
                <th className="px-5 py-4">Action</th>
                <th className="px-5 py-4">Resource ID</th>
                <th className="px-6 py-4">Mandatory Reason</th>
                <th className="px-5 py-4 text-right">Idempotency Key</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {logs.map((entry) => {
                const isDeactivate = entry.action === 'deactivate_question';
                const isReactivate = entry.action === 'reactivate_question';

                return (
                  <tr key={entry.id} className="hover:bg-slate-800/40 transition-colors">
                    {/* Timestamp */}
                    <td className="px-6 py-4.5 font-mono text-xs text-slate-300 whitespace-nowrap">
                      <div className="flex items-center gap-2">
                        <Clock className="w-4 h-4 text-slate-400" />
                        {new Date(entry.timestamp).toLocaleString()}
                      </div>
                    </td>

                    {/* Admin Operator */}
                    <td className="px-5 py-4.5">
                      <div className="flex items-center gap-2 text-slate-200 font-semibold text-xs font-mono">
                        <User className="w-4 h-4 text-slate-400" />
                        {entry.adminEmail}
                      </div>
                    </td>

                    {/* Action */}
                    <td className="px-5 py-4.5">
                      <span
                        className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-bold uppercase tracking-wider font-mono ${
                          isDeactivate
                            ? 'bg-rose-500/15 text-rose-300 border border-rose-500/30'
                            : isReactivate
                            ? 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/30'
                            : 'bg-indigo-500/15 text-indigo-300 border border-indigo-500/30'
                        }`}
                      >
                        {entry.action.replace(/_/g, ' ')}
                      </span>
                    </td>

                    {/* Resource ID */}
                    <td className="px-5 py-4.5 font-mono text-slate-200 font-bold text-xs">
                      {entry.resourceId}
                    </td>

                    {/* Reason */}
                    <td className="px-6 py-4.5 text-slate-200 font-medium text-xs leading-relaxed max-w-sm">
                      {entry.reason}
                    </td>

                    {/* Idempotency Key */}
                    <td className="px-5 py-4.5 text-right font-mono text-xs text-slate-400">
                      <span className="bg-slate-950 px-2.5 py-1 rounded-lg border border-slate-800 inline-block font-mono">
                        {entry.idempotencyKey.slice(0, 18)}...
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
