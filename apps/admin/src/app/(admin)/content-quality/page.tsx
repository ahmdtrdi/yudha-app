'use client';

import React, { useState, useEffect, Suspense } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import {
  Search,
  Filter,
  ArrowUpDown,
  AlertTriangle,
  Eye,
  RefreshCw
} from 'lucide-react';
import { Badge } from '@/components/ui/Badge';
import { adminApi } from '@/lib/api-client';
import { QuestionItem } from '@/types/admin';

function ContentQualityContent() {
  const searchParams = useSearchParams();
  const initialSignalsOnly = searchParams.get('hasSignals') === 'true';

  const [questions, setQuestions] = useState<QuestionItem[]>([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [search, setSearch] = useState('');
  const [targetFilter, setTargetFilter] = useState<string>('all');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [stateFilter, setStateFilter] = useState<string>('all');
  const [signalsOnly, setSignalsOnly] = useState<boolean>(initialSignalsOnly);
  const [sortBy, setSortBy] = useState<'accuracy_asc' | 'accuracy_desc' | 'attempts' | 'timeout' | 'time'>('accuracy_asc');

  const loadQuestions = async () => {
    setLoading(true);
    try {
      const data = await adminApi.getQuestions({
        target: targetFilter,
        category: categoryFilter,
        qualityState: stateFilter,
        search,
        hasSignals: signalsOnly
      });
      setQuestions(data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadQuestions();
  }, [targetFilter, categoryFilter, stateFilter, signalsOnly]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadQuestions();
  };

  // Client-side sorting
  const sortedQuestions = [...questions].sort((a, b) => {
    if (sortBy === 'accuracy_asc') return a.metrics.overallAccuracy - b.metrics.overallAccuracy;
    if (sortBy === 'accuracy_desc') return b.metrics.overallAccuracy - a.metrics.overallAccuracy;
    if (sortBy === 'attempts') return b.metrics.totalAttempts - a.metrics.totalAttempts;
    if (sortBy === 'timeout') return b.metrics.timeoutRate - a.metrics.timeoutRate;
    if (sortBy === 'time') return b.metrics.medianResponseTimeMs - a.metrics.medianResponseTimeMs;
    return 0;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-50 tracking-tight flex items-center gap-3">
            Question Quality Explorer
          </h1>
          <p className="text-sm text-slate-300 mt-1.5 font-medium">
            Examine item psychometrics, distractor efficacy, response latencies, and flag anomalous items.
          </p>
        </div>
        <button
          onClick={loadQuestions}
          className="admin-button-secondary text-sm self-start sm:self-auto cursor-pointer"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Data</span>
        </button>
      </div>

      {/* Filter Bar */}
      <div className="glass-panel p-5 space-y-4">
        <form onSubmit={handleSearchSubmit} className="flex flex-col md:flex-row gap-3">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search prompt stem, sourceKey, or skill ID..."
              className="w-full admin-input pl-11 text-sm"
            />
          </div>
          <button type="submit" className="admin-button-primary text-sm flex-shrink-0 cursor-pointer">
            Search
          </button>
        </form>

        <div className="flex flex-wrap items-center justify-between gap-4 pt-3.5 border-t border-slate-800">
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <span className="text-slate-300 font-semibold flex items-center gap-1.5 mr-1">
              <Filter className="w-4 h-4 text-indigo-400" /> Filters:
            </span>

            {/* Target Filter */}
            <select
              value={targetFilter}
              onChange={(e) => setTargetFilter(e.target.value)}
              className="admin-input py-1.5 text-sm"
            >
              <option value="all">All Targets</option>
              <option value="cpns">CPNS</option>
              <option value="bumn">BUMN</option>
            </select>

            {/* Category Filter */}
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="admin-input py-1.5 text-sm"
            >
              <option value="all">All Categories</option>
              <option value="TIU">TIU</option>
              <option value="TWK">TWK</option>
              <option value="TKP">TKP</option>
              <option value="Core Values">Core Values (AKHLAK)</option>
            </select>

            {/* State Filter */}
            <select
              value={stateFilter}
              onChange={(e) => setStateFilter(e.target.value)}
              className="admin-input py-1.5 text-sm"
            >
              <option value="all">All States</option>
              <option value="approved">Approved</option>
              <option value="under_review">Under Review</option>
              <option value="disabled">Disabled</option>
            </select>

            {/* Signals Toggle */}
            <button
              type="button"
              onClick={() => setSignalsOnly(!signalsOnly)}
              className={`px-3 py-1.5 rounded-xl border text-sm font-semibold flex items-center gap-2 transition-all cursor-pointer ${
                signalsOnly
                  ? 'bg-rose-500/20 text-rose-300 border-rose-500/40 shadow-sm'
                  : 'bg-slate-900 text-slate-400 border-slate-800 hover:border-slate-700 hover:text-slate-200'
              }`}
            >
              <AlertTriangle className="w-4 h-4 text-rose-400" />
              <span>Flagged Signals Only</span>
            </button>
          </div>

          {/* Sort By */}
          <div className="flex items-center gap-2.5 text-sm">
            <span className="text-slate-300 font-semibold flex items-center gap-1.5">
              <ArrowUpDown className="w-4 h-4 text-indigo-400" /> Sort:
            </span>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as typeof sortBy)}
              className="admin-input py-1.5 text-sm"
            >
              <option value="accuracy_asc">Lowest Accuracy First</option>
              <option value="accuracy_desc">Highest Accuracy First</option>
              <option value="timeout">Highest Timeout Rate</option>
              <option value="time">Longest Response Time</option>
              <option value="attempts">Most Attempts</option>
            </select>
          </div>
        </div>
      </div>

      {/* Questions Table */}
      <div className="glass-panel overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-950/90 text-slate-400 uppercase tracking-wider font-bold text-xs border-b border-slate-800">
              <tr>
                <th className="px-6 py-4">Question / Stem</th>
                <th className="px-5 py-4">Category & Skill</th>
                <th className="px-4 py-4 text-center">Difficulty</th>
                <th className="px-5 py-4 text-right">Accuracy</th>
                <th className="px-5 py-4 text-right">Latency / Timeout</th>
                <th className="px-4 py-4 text-center">State</th>
                <th className="px-6 py-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-16 text-center text-slate-400">
                    <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-3 text-indigo-400" />
                    <p className="font-medium">Loading question metrics...</p>
                  </td>
                </tr>
              ) : sortedQuestions.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-16 text-center text-slate-400">
                    <p className="font-medium">No questions matching your criteria.</p>
                  </td>
                </tr>
              ) : (
                sortedQuestions.map((q) => (
                  <tr
                    key={q.id}
                    className="hover:bg-slate-800/40 transition-colors group"
                  >
                    {/* Prompt & Source */}
                    <td className="px-6 py-4.5 max-w-md">
                      <div className="flex items-center gap-2 mb-1.5">
                        <Badge variant="target" value={q.target} size="sm" />
                        <span className="font-mono font-bold text-slate-200 text-xs">
                          {q.sourceKey}
                        </span>
                        <span className="text-slate-400 text-xs font-mono">
                          v{q.revision}
                        </span>
                      </div>
                      <p className="text-slate-200 font-medium line-clamp-2 leading-relaxed">
                        {q.prompt}
                      </p>
                      {q.metrics.signals.length > 0 && (
                        <div className="flex flex-wrap gap-1.5 mt-2.5">
                          {q.metrics.signals.map((sig, i) => (
                            <Badge key={i} variant="signal" value={sig} size="sm" />
                          ))}
                        </div>
                      )}
                    </td>

                    {/* Category & Skill */}
                    <td className="px-5 py-4.5">
                      <div className="font-bold text-slate-100">{q.category}</div>
                      <div className="text-xs text-slate-400 font-mono mt-1">
                        {q.primarySkillId}
                      </div>
                    </td>

                    {/* Difficulty */}
                    <td className="px-4 py-4.5 text-center">
                      <div className="inline-flex items-center gap-1 font-mono font-bold text-slate-200 bg-slate-800/90 px-2.5 py-1 rounded-lg border border-slate-700 text-xs">
                        <span>Lvl {q.difficulty}</span>
                      </div>
                    </td>

                    {/* Accuracy */}
                    <td className="px-5 py-4.5 text-right">
                      <div className="font-extrabold text-slate-100 font-mono text-sm">
                        {q.metrics.overallAccuracy}%
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5 font-mono">
                        {q.metrics.totalAttempts.toLocaleString()} attempts
                      </div>
                    </td>

                    {/* Response Latency & Timeout */}
                    <td className="px-5 py-4.5 text-right">
                      <div className="font-bold text-slate-200 font-mono text-sm">
                        {(q.metrics.medianResponseTimeMs / 1000).toFixed(1)}s
                      </div>
                      <div
                        className={`text-xs font-mono mt-0.5 ${
                          q.metrics.timeoutRate > 10 ? 'text-rose-400 font-bold' : 'text-slate-400'
                        }`}
                      >
                        {q.metrics.timeoutRate}% timeout
                      </div>
                    </td>

                    {/* State */}
                    <td className="px-4 py-4.5 text-center">
                      <Badge variant="quality" value={q.qualityState} size="sm" />
                    </td>

                    {/* Action */}
                    <td className="px-6 py-4.5 text-right">
                      <Link
                        href={`/content-quality/${q.id}`}
                        className="inline-flex items-center gap-1.5 text-xs font-bold text-indigo-300 hover:text-white bg-indigo-600/20 hover:bg-indigo-600 px-3.5 py-2 rounded-xl border border-indigo-500/30 transition-all cursor-pointer"
                      >
                        <Eye className="w-4 h-4" />
                        <span>Inspect</span>
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default function ContentQualityPage() {
  return (
    <Suspense fallback={<div className="p-12 text-center text-sm text-slate-400">Loading Content Quality Explorer...</div>}>
      <ContentQualityContent />
    </Suspense>
  );
}
