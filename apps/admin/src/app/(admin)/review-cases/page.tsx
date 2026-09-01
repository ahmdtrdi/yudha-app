'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  Inbox,
  Filter,
  CheckCircle2,
  Clock,
  MessageSquare,
  ArrowRight,
  ChevronRight,
  RefreshCw,
  FolderOpen
} from 'lucide-react';
import { Badge } from '@/components/ui/Badge';
import { Modal } from '@/components/ui/Modal';
import { adminApi } from '@/lib/api-client';
import { ReviewCase, CaseStatus, CaseDisposition } from '@/types/admin';

export default function ReviewCasesPage() {
  const [cases, setCases] = useState<ReviewCase[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [selectedCase, setSelectedCase] = useState<ReviewCase | null>(null);

  // Form states for selected case update
  const [noteInput, setNoteInput] = useState('');
  const [nextStatus, setNextStatus] = useState<CaseStatus>('in_review');
  const [disposition, setDisposition] = useState<CaseDisposition | ''>('');
  const [updating, setUpdating] = useState(false);

  const loadCases = async () => {
    setLoading(true);
    try {
      const data = await adminApi.getReviewCases({
        status: statusFilter
      });
      setCases(data);
      if (selectedCase) {
        const updated = data.find((c) => c.id === selectedCase.id);
        if (updated) setSelectedCase(updated);
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCases();
  }, [statusFilter]);

  const handleOpenCaseModal = (c: ReviewCase) => {
    setSelectedCase(c);
    setNextStatus(c.status);
    setDisposition(c.disposition || '');
    setNoteInput('');
  };

  const handleUpdateCase = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCase) return;

    setUpdating(true);
    try {
      const updated = await adminApi.updateCaseStatus(
        selectedCase.id,
        nextStatus,
        disposition ? (disposition as CaseDisposition) : undefined,
        noteInput.trim() ? noteInput : undefined
      );
      setSelectedCase(updated);
      setNoteInput('');
      loadCases();
    } finally {
      setUpdating(false);
    }
  };

  const statuses: { label: string; value: string; count: number }[] = [
    { label: 'All Cases', value: 'all', count: cases.length },
    { label: 'Open', value: 'open', count: cases.filter((c) => c.status === 'open').length },
    { label: 'In Review', value: 'in_review', count: cases.filter((c) => c.status === 'in_review').length },
    { label: 'Resolved', value: 'resolved', count: cases.filter((c) => c.status === 'resolved').length },
    { label: 'Dismissed', value: 'dismissed', count: cases.filter((c) => c.status === 'dismissed').length }
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-50 tracking-tight flex items-center gap-3">
            Content Quality Triage Board
          </h1>
          <p className="text-sm text-slate-300 mt-1.5 font-medium">
            Investigate reported anomalies, record SME findings, and execute formal case dispositions.
          </p>
        </div>
        <button
          onClick={loadCases}
          className="admin-button-secondary text-sm self-start sm:self-auto cursor-pointer"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Cases</span>
        </button>
      </div>

      {/* Status Filter Tabs */}
      <div className="flex items-center gap-2.5 border-b border-slate-800 pb-4 overflow-x-auto">
        {statuses.map((tab) => {
          const isActive = statusFilter === tab.value;
          return (
            <button
              key={tab.value}
              onClick={() => setStatusFilter(tab.value)}
              className={`px-4 py-2 rounded-xl text-sm font-bold flex items-center gap-2.5 transition-all whitespace-nowrap cursor-pointer ${
                isActive
                  ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
                  : 'bg-slate-900 text-slate-400 border border-slate-800 hover:border-slate-700 hover:text-slate-200'
              }`}
            >
              <span>{tab.label}</span>
              <span
                className={`text-xs px-2 py-0.5 rounded-full font-extrabold ${
                  isActive ? 'bg-white/20 text-white' : 'bg-slate-800 text-slate-400'
                }`}
              >
                {tab.count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Cases Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {loading ? (
          <div className="col-span-full py-20 text-center text-slate-400">
            <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-3 text-indigo-400" />
            <p className="text-sm font-medium">Loading triage cases...</p>
          </div>
        ) : cases.length === 0 ? (
          <div className="col-span-full py-20 text-center text-slate-400 glass-panel">
            <FolderOpen className="w-10 h-10 mx-auto mb-3 text-slate-500" />
            <p className="text-sm font-medium">No triage cases found in this category.</p>
          </div>
        ) : (
          cases.map((c) => (
            <div
              key={c.id}
              onClick={() => handleOpenCaseModal(c)}
              className="glass-panel-interactive p-6 cursor-pointer flex flex-col justify-between space-y-4 shadow-sm"
            >
              <div className="space-y-3.5">
                <div className="flex items-center justify-between">
                  <span className="font-mono text-sm font-extrabold text-slate-100">
                    {c.id}
                  </span>
                  <div className="flex items-center gap-2">
                    <Badge variant="priority" value={c.priority} size="sm" />
                    <Badge variant="status" value={c.status} size="sm" />
                  </div>
                </div>

                <div className="flex items-center gap-2.5 text-xs">
                  <Badge variant="target" value={c.target} size="sm" />
                  <span className="text-slate-300 font-mono font-semibold">{c.questionId}</span>
                </div>

                <p className="text-sm text-slate-200 font-medium line-clamp-2 leading-relaxed">
                  {c.manualReason}
                </p>

                {/* Evidence Snapshot Pill */}
                <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800 text-xs grid grid-cols-3 gap-2 text-center">
                  <div>
                    <span className="text-slate-400 block text-[11px] uppercase font-bold tracking-wider">Accuracy</span>
                    <span className="font-extrabold text-slate-100 font-mono text-sm">
                      {c.evidenceSnapshot.overallAccuracy}%
                    </span>
                  </div>
                  <div>
                    <span className="text-slate-400 block text-[11px] uppercase font-bold tracking-wider">Timeout</span>
                    <span className="font-extrabold text-rose-400 font-mono text-sm">
                      {c.evidenceSnapshot.timeoutRate}%
                    </span>
                  </div>
                  <div>
                    <span className="text-slate-400 block text-[11px] uppercase font-bold tracking-wider">Attempts</span>
                    <span className="font-extrabold text-slate-100 font-mono text-sm">
                      {c.evidenceSnapshot.totalAttempts}
                    </span>
                  </div>
                </div>

                {c.signals.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {c.signals.map((sig, i) => (
                      <Badge key={i} variant="signal" value={sig} size="sm" />
                    ))}
                  </div>
                )}
              </div>

              <div className="pt-3.5 border-t border-slate-800 flex items-center justify-between text-xs text-slate-400 font-medium">
                <span className="flex items-center gap-1.5">
                  <MessageSquare className="w-4 h-4 text-slate-400" />
                  {c.notes.length} notes
                </span>
                <span className="text-indigo-400 font-bold flex items-center gap-1 group-hover:translate-x-1 transition-transform">
                  Inspect & Triage <ChevronRight className="w-4 h-4" />
                </span>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Case Detail & Workflow Modal */}
      {selectedCase && (
        <Modal
          isOpen={!!selectedCase}
          onClose={() => setSelectedCase(null)}
          title={`Triage Case ${selectedCase.id}`}
          subtitle={`Target: ${selectedCase.target.toUpperCase()} &bull; Question: ${selectedCase.questionId} (Rev ${selectedCase.questionRevision})`}
          maxWidth="xl"
        >
          <div className="space-y-6">
            {/* Top Info & Link to Question */}
            <div className="flex items-center justify-between p-4 rounded-xl bg-slate-950/90 border border-slate-800">
              <div className="flex items-center gap-2.5">
                <Badge variant="priority" value={selectedCase.priority} />
                <Badge variant="status" value={selectedCase.status} />
                {selectedCase.disposition && (
                  <span className="px-3 py-1 text-xs font-bold rounded-lg bg-purple-500/20 text-purple-300 border border-purple-500/30">
                    Disposition: {selectedCase.disposition.replace(/_/g, ' ')}
                  </span>
                )}
              </div>
              <Link
                href={`/content-quality/${selectedCase.questionId}`}
                className="text-xs font-bold text-indigo-400 hover:text-indigo-300 flex items-center gap-1.5 transition-colors"
              >
                <span>View Question Item</span>
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>

            {/* Manual Reason / Observations */}
            <div className="space-y-2">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-300">
                Case Opening Observations
              </label>
              <div className="p-4 rounded-xl bg-slate-950/80 border border-slate-800 text-sm text-slate-200 leading-relaxed font-medium">
                {selectedCase.manualReason}
              </div>
            </div>

            {/* Evidence Snapshot */}
            <div className="space-y-2">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-300">
                Evidence Snapshot at Case Creation
              </label>
              <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
                <div>
                  <span className="text-slate-400 block text-xs font-semibold">Overall Accuracy</span>
                  <span className="font-extrabold text-slate-100 font-mono text-base">
                    {selectedCase.evidenceSnapshot.overallAccuracy}%
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-xs font-semibold">Unseen Accuracy</span>
                  <span className="font-extrabold text-slate-100 font-mono text-base">
                    {selectedCase.evidenceSnapshot.unseenAccuracy}%
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-xs font-semibold">Timeout Rate</span>
                  <span className="font-extrabold text-rose-400 font-mono text-base">
                    {selectedCase.evidenceSnapshot.timeoutRate}%
                  </span>
                </div>
                <div>
                  <span className="text-slate-400 block text-xs font-semibold">Median Response</span>
                  <span className="font-extrabold text-slate-100 font-mono text-base">
                    {(selectedCase.evidenceSnapshot.medianResponseTimeMs / 1000).toFixed(1)}s
                  </span>
                </div>
              </div>
            </div>

            {/* Internal QA & SME Notes */}
            <div className="space-y-2.5">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-300">
                Discussion & Review Notes ({selectedCase.notes.length})
              </label>

              <div className="space-y-2.5 max-h-52 overflow-y-auto pr-1">
                {selectedCase.notes.length === 0 ? (
                  <p className="text-xs text-slate-400 italic p-3 bg-slate-950/40 rounded-lg">No notes recorded yet.</p>
                ) : (
                  selectedCase.notes.map((note) => (
                    <div
                      key={note.id}
                      className="p-3.5 rounded-xl bg-slate-950/90 border border-slate-800 text-sm space-y-1.5"
                    >
                      <div className="flex items-center justify-between text-xs text-slate-400">
                        <span className="font-bold text-slate-200">
                          {note.author} ({note.authorRole})
                        </span>
                        <span className="font-mono">{new Date(note.timestamp).toLocaleString()}</span>
                      </div>
                      <p className="text-slate-200 font-normal leading-relaxed">{note.content}</p>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Triage Update Form */}
            <form onSubmit={handleUpdateCase} className="pt-4 border-t border-slate-800 space-y-4">
              {/* Add Note */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                  Add Review Note
                </label>
                <textarea
                  rows={2}
                  value={noteInput}
                  onChange={(e) => setNoteInput(e.target.value)}
                  placeholder="Record SME findings, distractor evaluation, or resolution plan..."
                  className="w-full admin-input resize-none text-sm"
                />
              </div>

              {/* Status and Disposition Row */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                    Triage State
                  </label>
                  <select
                    value={nextStatus}
                    onChange={(e) => setNextStatus(e.target.value as CaseStatus)}
                    className="w-full admin-input text-sm"
                  >
                    <option value="open">Open</option>
                    <option value="in_review">In Review</option>
                    <option value="resolved">Resolved</option>
                    <option value="dismissed">Dismissed</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                    Final Disposition (If resolving)
                  </label>
                  <select
                    value={disposition}
                    onChange={(e) => setDisposition(e.target.value as CaseDisposition)}
                    className="w-full admin-input text-sm"
                  >
                    <option value="">-- No Disposition Yet --</option>
                    <option value="no_issue">No Issue Found</option>
                    <option value="revise_content">Revise Content Prompt</option>
                    <option value="revise_answer_or_explanation">Revise Answer / Explanation</option>
                    <option value="remap_skill_or_difficulty">Remap Skill or Difficulty</option>
                    <option value="invalidate_revision">Invalidate Revision Psychometrics</option>
                    <option value="deactivate_question">Deactivate Question</option>
                    <option value="reactivate_question">Reactivate Question</option>
                  </select>
                </div>
              </div>

              {/* Submit */}
              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setSelectedCase(null)}
                  className="admin-button-secondary text-sm cursor-pointer"
                >
                  Close
                </button>
                <button
                  type="submit"
                  disabled={updating}
                  className="admin-button-primary text-sm cursor-pointer"
                >
                  {updating ? 'Saving...' : 'Save Triage Update'}
                </button>
              </div>
            </form>
          </div>
        </Modal>
      )}
    </div>
  );
}
