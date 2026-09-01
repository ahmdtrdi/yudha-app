'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  FileCheck2,
  AlertTriangle,
  Inbox,
  Boxes,
  ArrowRight,
  Clock,
  ShieldCheck,
  BarChart3,
  RefreshCw
} from 'lucide-react';
import { StatCard } from '@/components/ui/StatCard';
import { Badge } from '@/components/ui/Badge';
import { adminApi } from '@/lib/api-client';
import { QuestionItem, ReviewCase, SkillCoverage } from '@/types/admin';

export default function DashboardPage() {
  const [questions, setQuestions] = useState<QuestionItem[]>([]);
  const [cases, setCases] = useState<ReviewCase[]>([]);
  const [coverage, setCoverage] = useState<SkillCoverage[]>([]);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const [qList, cList, covList] = await Promise.all([
        adminApi.getQuestions(),
        adminApi.getReviewCases(),
        adminApi.getCoverage()
      ]);
      setQuestions(qList);
      setCases(cList);
      setCoverage(covList);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const activeQuestionsCount = questions.filter((q) => q.active).length;
  const underReviewCount = questions.filter(
    (q) => q.qualityState === 'under_review' || q.metrics.signals.length > 0
  ).length;
  const openCasesCount = cases.filter((c) => c.status === 'open' || c.status === 'in_review').length;
  const belowMinimumSkills = coverage.filter((s) => s.isBelowMinimum).length;

  const flaggedQuestions = questions.filter((q) => q.metrics.signals.length > 0);

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-50 tracking-tight flex items-center gap-3">
            Content Quality & Triage Dashboard
          </h1>
          <p className="text-sm text-slate-300 mt-1.5 font-medium">
            Server-managed psychometric monitoring, question health alerts, and triage pipeline.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Link
            href="/content-quality"
            className="admin-button-secondary text-sm"
          >
            <BarChart3 className="w-4 h-4" />
            <span>Question Explorer</span>
          </Link>
          <Link
            href="/review-cases"
            className="admin-button-primary text-sm"
          >
            <Inbox className="w-4 h-4" />
            <span>Triage Cases ({openCasesCount})</span>
          </Link>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <StatCard
          title="Active Questions"
          value={activeQuestionsCount}
          subtitle="Ready for match delivery"
          change="+12%"
          changeType="positive"
          icon={FileCheck2}
          iconColor="text-emerald-400"
        />
        <StatCard
          title="Flagged / Under Review"
          value={underReviewCount}
          subtitle="Psychometric signals active"
          change="3 urgent"
          changeType="negative"
          icon={AlertTriangle}
          iconColor="text-amber-400"
        />
        <StatCard
          title="Open Review Cases"
          value={openCasesCount}
          subtitle="Awaiting triage disposition"
          icon={Inbox}
          iconColor="text-indigo-400"
        />
        <StatCard
          title="Below Delivery Min"
          value={belowMinimumSkills}
          subtitle="Skills need content authoring"
          change="3 skills"
          changeType="negative"
          icon={Boxes}
          iconColor="text-rose-400"
        />
      </div>

      {/* Main Grid: Quality Alerts + Triage Cases */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: High Priority Question Alerts */}
        <div className="lg:col-span-2 space-y-6">
          <div className="glass-panel p-6">
            <div className="flex items-center justify-between mb-5">
              <div>
                <h2 className="text-base sm:text-lg font-bold text-slate-100 flex items-center gap-2">
                  <AlertTriangle className="w-5 h-5 text-amber-400" />
                  Item Quality Alerts
                </h2>
                <p className="text-sm text-slate-400 mt-1">
                  Questions exhibiting extreme low accuracy, high timeout rates, or distractor traps.
                </p>
              </div>
              <Link
                href="/content-quality?hasSignals=true"
                className="text-sm font-semibold text-indigo-400 hover:text-indigo-300 flex items-center gap-1.5 transition-colors"
              >
                <span>View all ({flaggedQuestions.length})</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>

            <div className="space-y-3.5">
              {flaggedQuestions.slice(0, 3).map((q) => (
                <Link
                  key={q.id}
                  href={`/content-quality/${q.id}`}
                  className="block p-4.5 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-indigo-500/50 hover:bg-slate-850 transition-all group"
                >
                  <div className="flex items-start justify-between gap-3 mb-2.5">
                    <div className="flex items-center gap-2.5">
                      <Badge variant="target" value={q.target} size="sm" />
                      <span className="text-sm font-mono font-bold text-slate-200">
                        {q.sourceKey}
                      </span>
                      <span className="text-xs text-slate-400">&bull; {q.category}</span>
                    </div>
                    <Badge variant="quality" value={q.qualityState} size="sm" />
                  </div>

                  <p className="text-sm text-slate-200 font-medium line-clamp-2 mb-3.5">
                    {q.prompt}
                  </p>

                  <div className="flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-slate-800 text-xs">
                    <div className="flex items-center gap-5 text-slate-400">
                      <span>
                        Accuracy: <strong className="text-slate-200 font-semibold">{q.metrics.overallAccuracy}%</strong>
                      </span>
                      <span>
                        Timeout: <strong className="text-slate-200 font-semibold">{q.metrics.timeoutRate}%</strong>
                      </span>
                      <span>
                        Resp Time: <strong className="text-slate-200 font-semibold">{(q.metrics.medianResponseTimeMs / 1000).toFixed(1)}s</strong>
                      </span>
                    </div>

                    <div className="flex items-center gap-2">
                      {q.metrics.signals.map((sig, i) => (
                        <Badge key={i} variant="signal" value={sig} size="sm" />
                      ))}
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          </div>

          {/* Quick Coverage Warning */}
          <div className="glass-panel p-6">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-base sm:text-lg font-bold text-slate-100 flex items-center gap-2">
                  <Boxes className="w-5 h-5 text-indigo-400" />
                  Inventory Delivery Minimums
                </h2>
                <p className="text-sm text-slate-400 mt-1">
                  Skills that need immediate authoring to prevent question exhaustion.
                </p>
              </div>
              <Link
                href="/inventory"
                className="text-sm font-semibold text-indigo-400 hover:text-indigo-300 flex items-center gap-1.5 transition-colors"
              >
                <span>Full Matrix</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              {coverage.slice(0, 3).map((item) => {
                const percent = Math.min(Math.round((item.activeCount / item.minimumRequired) * 100), 100);
                return (
                  <div
                    key={item.skillId}
                    className="p-4 rounded-xl bg-slate-900/80 border border-slate-800"
                  >
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-sm font-bold text-slate-200 truncate">
                        {item.skillName}
                      </span>
                      <Badge variant="target" value={item.target} size="sm" />
                    </div>
                    <div className="flex items-baseline justify-between text-xs mb-2.5">
                      <span className="text-slate-400">Inventory</span>
                      <span className="font-bold text-slate-100 font-mono text-sm">
                        {item.activeCount} / {item.minimumRequired}
                      </span>
                    </div>
                    <div className="w-full bg-slate-950 rounded-full h-2 overflow-hidden">
                      <div
                        className={`h-full rounded-full ${
                          item.isBelowMinimum ? 'bg-rose-500' : 'bg-emerald-500'
                        }`}
                        style={{ width: `${percent}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Right Col: Active Triage Cases */}
        <div className="space-y-6">
          <div className="glass-panel p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-base sm:text-lg font-bold text-slate-100 flex items-center gap-2">
                <Inbox className="w-5 h-5 text-indigo-400" />
                Active Triage Cases
              </h2>
              <Link
                href="/review-cases"
                className="text-sm font-semibold text-indigo-400 hover:text-indigo-300"
              >
                Board
              </Link>
            </div>

            <div className="space-y-3.5">
              {cases.slice(0, 4).map((c) => (
                <Link
                  key={c.id}
                  href="/review-cases"
                  className="block p-4 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-slate-700 space-y-2.5 transition-all"
                >
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-mono font-bold text-slate-200">
                      {c.id}
                    </span>
                    <div className="flex items-center gap-1.5">
                      <Badge variant="priority" value={c.priority} size="sm" />
                      <Badge variant="status" value={c.status} size="sm" />
                    </div>
                  </div>

                  <p className="text-xs text-slate-300 font-medium line-clamp-2">
                    {c.manualReason}
                  </p>

                  <div className="flex items-center justify-between text-xs text-slate-400 pt-2 border-t border-slate-800">
                    <span>Target: <strong className="text-slate-300">{c.target.toUpperCase()}</strong></span>
                    <span className="flex items-center gap-1 font-mono">
                      <Clock className="w-3.5 h-3.5" />
                      {new Date(c.updatedAt).toLocaleDateString()}
                    </span>
                  </div>
                </Link>
              ))}
            </div>
          </div>

          {/* Quick System Info */}
          <div className="glass-panel p-6 border-indigo-500/30 bg-gradient-to-br from-slate-900/95 to-indigo-950/30">
            <div className="flex items-center gap-2.5 text-indigo-300 text-xs font-bold uppercase tracking-wider mb-2.5">
              <ShieldCheck className="w-5 h-5 text-indigo-400" />
              <span>PRD V2 Quality Mandate</span>
            </div>
            <p className="text-xs text-slate-300 leading-relaxed font-normal">
              Automated signals never deactivate questions without human review. All deactivations require explicit audit logging and admin verification.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
