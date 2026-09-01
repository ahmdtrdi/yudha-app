'use client';

import React, { useState, useEffect } from 'react';
import {
  Boxes,
  AlertTriangle,
  Filter
} from 'lucide-react';
import { Badge } from '@/components/ui/Badge';
import { adminApi } from '@/lib/api-client';
import { SkillCoverage } from '@/types/admin';

export default function InventoryPage() {
  const [coverage, setCoverage] = useState<SkillCoverage[]>([]);
  const [loading, setLoading] = useState(true);
  const [targetFilter, setTargetFilter] = useState<string>('all');

  useEffect(() => {
    async function loadData() {
      setLoading(true);
      try {
        const data = await adminApi.getCoverage();
        setCoverage(data);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  const filteredCoverage = coverage.filter((item) => {
    if (targetFilter !== 'all' && item.target !== targetFilter) return false;
    return true;
  });

  const belowMinCount = filteredCoverage.filter((s) => s.isBelowMinimum).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-50 tracking-tight flex items-center gap-3">
            Skill Inventory & Delivery Coverage
          </h1>
          <p className="text-sm text-slate-300 mt-1.5 font-medium">
            Ensure sufficient active question bank volume and difficulty depth for matchmaking and solo practice.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={targetFilter}
            onChange={(e) => setTargetFilter(e.target.value)}
            className="admin-input py-2 text-sm"
          >
            <option value="all">All Targets</option>
            <option value="cpns">CPNS Only</option>
            <option value="bumn">BUMN Only</option>
          </select>
        </div>
      </div>

      {/* Summary Alert */}
      {belowMinCount > 0 && (
        <div className="p-5 rounded-2xl bg-amber-950/20 border border-amber-500/40 flex items-start gap-4">
          <AlertTriangle className="w-6 h-6 text-amber-400 flex-shrink-0 mt-0.5" />
          <div className="text-sm space-y-1">
            <div className="font-bold text-amber-200 text-base">
              {belowMinCount} Skill{belowMinCount > 1 ? 's' : ''} Below Minimum Delivery Quota
            </div>
            <p className="text-amber-300/90 font-medium">
              Players experiencing matchmaking or solo drills in these skills may face duplicate questions or depleted selection pools.
            </p>
          </div>
        </div>
      )}

      {/* Coverage Table */}
      <div className="glass-panel overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950/90 text-slate-400 uppercase tracking-wider font-bold text-xs border-b border-slate-800">
              <tr>
                <th className="px-6 py-4">Skill Name & ID</th>
                <th className="px-5 py-4">Target / Cat</th>
                <th className="px-5 py-4 text-center">Active / Minimum</th>
                <th className="px-6 py-4 text-center">Quota Progress</th>
                <th className="px-6 py-4">Difficulty Depth (Lvl 1 - 5)</th>
                <th className="px-5 py-4 text-center">QA Pipeline</th>
                <th className="px-5 py-4 text-center">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {filteredCoverage.map((item) => {
                const percentage = Math.min(
                  Math.round((item.activeCount / item.minimumRequired) * 100),
                  100
                );

                return (
                  <tr key={item.skillId} className="hover:bg-slate-800/40 transition-colors">
                    {/* Skill Name */}
                    <td className="px-6 py-4.5">
                      <div className="font-bold text-slate-100 text-sm">{item.skillName}</div>
                      <div className="text-xs text-slate-400 font-mono mt-1">
                        {item.skillId}
                      </div>
                    </td>

                    {/* Target & Cat */}
                    <td className="px-5 py-4.5">
                      <Badge variant="target" value={item.target} size="sm" />
                      <div className="text-xs text-slate-400 mt-1 font-medium">{item.category}</div>
                    </td>

                    {/* Active vs Min */}
                    <td className="px-5 py-4.5 text-center font-mono">
                      <span className="font-extrabold text-slate-100 text-sm">{item.activeCount}</span>
                      <span className="text-slate-400 text-xs"> / {item.minimumRequired}</span>
                    </td>

                    {/* Quota Progress */}
                    <td className="px-6 py-4.5 max-w-xs">
                      <div className="flex items-center justify-between text-xs text-slate-300 font-semibold mb-1.5">
                        <span>{percentage}% of quota</span>
                      </div>
                      <div className="w-full bg-slate-950 rounded-full h-2.5 overflow-hidden">
                        <div
                          className={`h-full rounded-full ${
                            item.isBelowMinimum ? 'bg-rose-500' : 'bg-emerald-500'
                          }`}
                          style={{ width: `${percentage}%` }}
                        />
                      </div>
                    </td>

                    {/* Difficulty Distribution */}
                    <td className="px-6 py-4.5">
                      <div className="flex items-center gap-2 font-mono text-xs">
                        {[1, 2, 3, 4, 5].map((lvl) => {
                          const count = item.difficultyDistribution[lvl] || 0;
                          return (
                            <span
                              key={lvl}
                              className={`px-2.5 py-1 rounded-lg border text-center font-bold ${
                                count === 0
                                  ? 'bg-rose-950/30 text-rose-400 border-rose-500/30'
                                  : 'bg-slate-900 text-slate-200 border-slate-800'
                              }`}
                              title={`Level ${lvl}: ${count} questions`}
                            >
                              L{lvl}:{count}
                            </span>
                          );
                        })}
                      </div>
                    </td>

                    {/* Review Pipeline */}
                    <td className="px-5 py-4.5 text-center text-xs">
                      {item.underReviewCount > 0 && (
                        <span className="text-amber-400 font-bold block">
                          {item.underReviewCount} review
                        </span>
                      )}
                      {item.disabledCount > 0 && (
                        <span className="text-rose-400 font-bold block">
                          {item.disabledCount} disabled
                        </span>
                      )}
                      {item.underReviewCount === 0 && item.disabledCount === 0 && (
                        <span className="text-slate-400">0 pending</span>
                      )}
                    </td>

                    {/* Status Badge */}
                    <td className="px-5 py-4.5 text-center">
                      {item.isBelowMinimum ? (
                        <span className="px-3 py-1 rounded-full text-xs font-bold bg-rose-500/15 text-rose-300 border border-rose-500/30">
                          Low Quota
                        </span>
                      ) : (
                        <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-500/15 text-emerald-300 border border-emerald-500/30">
                          Sufficient
                        </span>
                      )}
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
