'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft,
  ShieldAlert,
  AlertTriangle,
  Clock,
  Inbox,
  PowerOff,
  CheckCircle2,
  HelpCircle,
  BarChart2
} from 'lucide-react';
import { Badge } from '@/components/ui/Badge';
import { DistractorBarChart } from '@/components/content-quality/DistractorBarChart';
import { DeactivateModal } from '@/components/content-quality/DeactivateModal';
import { CreateCaseModal } from '@/components/content-quality/CreateCaseModal';
import { adminApi } from '@/lib/api-client';
import { QuestionItem } from '@/types/admin';

export default function QuestionDetailPage() {
  const params = useParams();
  const router = useRouter();
  const questionId = params.questionId as string;

  const [question, setQuestion] = useState<QuestionItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [isDeactivateOpen, setIsDeactivateOpen] = useState(false);
  const [isCreateCaseOpen, setIsCreateCaseOpen] = useState(false);

  const loadQuestion = async () => {
    setLoading(true);
    try {
      const data = await adminApi.getQuestionById(questionId);
      setQuestion(data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadQuestion();
  }, [questionId]);

  if (loading) {
    return (
      <div className="py-24 text-center text-slate-400">
        <div className="w-10 h-10 border-3 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        <p className="text-sm font-medium">Loading item psychometrics and distractor data...</p>
      </div>
    );
  }

  if (!question) {
    return (
      <div className="glass-panel p-10 text-center space-y-4 max-w-lg mx-auto">
        <ShieldAlert className="w-12 h-12 text-rose-400 mx-auto" />
        <h2 className="text-lg font-bold text-slate-100">Question Not Found</h2>
        <p className="text-sm text-slate-400">The requested question ID could not be loaded from storage or backend.</p>
        <Link href="/content-quality" className="admin-button-secondary text-sm inline-flex">
          <ArrowLeft className="w-4 h-4" /> Back to Explorer
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Top Breadcrumb & Action Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <Link
            href="/content-quality"
            className="p-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
          >
            <ArrowLeft className="w-5 h-5" />
          </Link>
          <div>
            <div className="flex items-center gap-2.5">
              <Badge variant="target" value={question.target} size="sm" />
              <h1 className="text-xl sm:text-2xl font-extrabold text-slate-100 font-mono">
                {question.sourceKey}
              </h1>
              <span className="text-xs text-slate-400 font-mono">Revision {question.revision}</span>
              <Badge variant="quality" value={question.qualityState} size="sm" />
            </div>
            <p className="text-sm text-slate-300 mt-1 font-medium">
              Category: <strong className="text-slate-100">{question.category}</strong> &bull; Primary Skill: <span className="font-mono text-indigo-300">{question.primarySkillId}</span>
            </p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-3">
          <button
            onClick={() => setIsCreateCaseOpen(true)}
            className="admin-button-secondary text-sm cursor-pointer"
          >
            <Inbox className="w-4 h-4" />
            <span>Open Triage Case</span>
          </button>

          <button
            onClick={() => setIsDeactivateOpen(true)}
            className={question.active ? 'admin-button-danger text-sm cursor-pointer' : 'admin-button-primary text-sm cursor-pointer'}
          >
            {question.active ? (
              <>
                <PowerOff className="w-4 h-4" />
                <span>Deactivate Question</span>
              </>
            ) : (
              <>
                <CheckCircle2 className="w-4 h-4" />
                <span>Reactivate Question</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Deactivation Banner if disabled */}
      {!question.active && (
        <div className="p-5 rounded-2xl bg-rose-950/30 border border-rose-500/40 flex items-start gap-3.5">
          <ShieldAlert className="w-6 h-6 text-rose-400 flex-shrink-0 mt-0.5" />
          <div className="text-sm space-y-1">
            <div className="font-bold text-rose-200">
              Question Currently Disabled from Session Queues
            </div>
            <p className="text-rose-300/90 font-medium">
              Reason: &ldquo;{question.deactivationReason || 'Administrative content review'}&rdquo;
            </p>
            {question.deactivatedBy && (
              <p className="text-slate-400 text-xs mt-1">
                Deactivated by <span className="text-slate-300 font-semibold">{question.deactivatedBy}</span> at {new Date(question.deactivatedAt || '').toLocaleString()}
              </p>
            )}
          </div>
        </div>
      )}

      {/* Main Grid: Left Stem & Options, Right Psychometrics */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Stem, Options, Explanation (7 cols) */}
        <div className="lg:col-span-7 space-y-6">
          {/* Question Prompt */}
          <div className="glass-panel p-6 space-y-4">
            <div className="flex items-center justify-between pb-3.5 border-b border-slate-800">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                Question Stem
              </span>
              <span className="text-xs font-mono text-slate-400">
                Difficulty Level: <strong className="text-slate-100 font-bold">Lvl {question.difficulty} / 5</strong>
              </span>
            </div>

            <p className="text-base font-semibold text-slate-100 leading-relaxed whitespace-pre-wrap">
              {question.prompt}
            </p>
          </div>

          {/* Options Breakdown */}
          <div className="glass-panel p-6 space-y-4">
            <div className="flex items-center justify-between pb-3.5 border-b border-slate-800">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
                Options & Distractor Efficacy
              </span>
              <span className="text-xs font-semibold text-slate-400">
                {question.options.length} Choices
              </span>
            </div>

            <DistractorBarChart
              distractors={question.metrics.distractors}
              totalAttempts={question.metrics.totalAttempts}
            />
          </div>

          {/* Solution & Explanation */}
          <div className="glass-panel p-6 space-y-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
              <HelpCircle className="w-4 h-4 text-indigo-400" />
              Official SME Explanation
            </span>
            <p className="text-sm text-slate-200 leading-relaxed bg-slate-950/80 p-4.5 rounded-xl border border-slate-800">
              {question.explanation}
            </p>
          </div>
        </div>

        {/* Right Column: Psychometric Evidence & Signals (5 cols) */}
        <div className="lg:col-span-5 space-y-6">
          {/* Quality Signals */}
          <div className="glass-panel p-6 space-y-3.5">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-400" />
              Automated Psychometric Signals
            </span>

            {question.metrics.signals.length === 0 ? (
              <div className="p-4 rounded-xl bg-emerald-950/20 border border-emerald-500/30 text-sm text-emerald-300 flex items-center gap-2.5">
                <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                <span className="font-medium">No anomalous signals detected. Psychometrics within normal thresholds.</span>
              </div>
            ) : (
              <div className="space-y-2.5">
                {question.metrics.signals.map((sig, i) => (
                  <div
                    key={i}
                    className="p-3.5 rounded-xl bg-rose-950/20 border border-rose-500/30 flex items-center justify-between text-sm"
                  >
                    <span className="font-bold text-rose-300 capitalize">
                      {sig.replace(/_/g, ' ')}
                    </span>
                    <span className="text-xs text-rose-400 font-mono font-semibold">Flagged</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Psychometric Scorecard */}
          <div className="glass-panel p-6 space-y-4">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
              <BarChart2 className="w-4 h-4 text-indigo-400" />
              Item Performance Scorecard (V2 Evidence)
            </span>

            <div className="space-y-3 text-sm">
              {/* Overall vs Unseen Accuracy */}
              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Overall Accuracy</span>
                  <span className="text-xs text-slate-400">All valid player attempts</span>
                </div>
                <div className="text-right font-mono font-extrabold text-base text-slate-100">
                  {question.metrics.overallAccuracy}%
                </div>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Unseen Accuracy</span>
                  <span className="text-xs text-slate-400">First-time encounters</span>
                </div>
                <div className="text-right font-mono font-extrabold text-base text-slate-100">
                  {question.metrics.unseenAccuracy}%
                </div>
              </div>

              {/* Seen-vs-Unseen Gap */}
              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Seen vs Unseen Gap</span>
                  <span className="text-xs text-slate-400">Memory retention inflation</span>
                </div>
                <div className="text-right font-mono font-extrabold text-base text-indigo-300">
                  +{question.metrics.seenUnseenGap}%
                </div>
              </div>

              {/* Median Response Time */}
              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Median Response Time</span>
                  <span className="text-xs text-slate-400">Expected: {(question.expectedTimeMs || 30000) / 1000}s</span>
                </div>
                <div className="text-right font-mono font-extrabold text-base text-slate-100">
                  {(question.metrics.medianResponseTimeMs / 1000).toFixed(1)}s
                </div>
              </div>

              {/* Timeout & Hint Rates */}
              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Timeout Rate</span>
                  <span className="text-xs text-slate-400">Standard limit: {question.standardTimeLimitMs / 1000}s</span>
                </div>
                <div className="text-right font-mono font-extrabold text-base text-rose-300">
                  {question.metrics.timeoutRate}%
                </div>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Hint Request Rate</span>
                  <span className="text-xs text-slate-400">Solo sessions</span>
                </div>
                <div className="text-right font-mono font-extrabold text-base text-slate-100">
                  {question.metrics.hintRate}%
                </div>
              </div>

              {/* Discrimination Index */}
              <div className="p-3.5 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-300 font-semibold block">Discrimination Index</span>
                  <span className="text-xs text-slate-400">Psychometric benchmark &ge; 0.30</span>
                </div>
                <div
                  className={`text-right font-mono font-extrabold text-base ${
                    question.metrics.discriminationIndex >= 0.3
                      ? 'text-emerald-400'
                      : 'text-rose-400'
                  }`}
                >
                  {question.metrics.discriminationIndex.toFixed(2)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Modals */}
      <DeactivateModal
        isOpen={isDeactivateOpen}
        onClose={() => setIsDeactivateOpen(false)}
        question={question}
        onSuccess={(updated) => setQuestion(updated)}
      />

      <CreateCaseModal
        isOpen={isCreateCaseOpen}
        onClose={() => setIsCreateCaseOpen(false)}
        question={question}
        onSuccess={(newCase) => {
          router.push('/review-cases');
        }}
      />
    </div>
  );
}
