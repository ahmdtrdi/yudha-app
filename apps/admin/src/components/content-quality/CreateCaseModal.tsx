'use client';

import React, { useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { QuestionItem, ReviewCase, CasePriority } from '@/types/admin';
import { Inbox, Loader2, ShieldAlert } from 'lucide-react';
import { adminApi } from '@/lib/api-client';

interface CreateCaseModalProps {
  isOpen: boolean;
  onClose: () => void;
  question: QuestionItem;
  onSuccess: (newCase: ReviewCase) => void;
}

export const CreateCaseModal: React.FC<CreateCaseModalProps> = ({
  isOpen,
  onClose,
  question,
  onSuccess
}) => {
  const [priority, setPriority] = useState<CasePriority>('medium');
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reason.trim()) {
      setError('Please provide a reason or observation for opening this triage case.');
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const created = await adminApi.createReviewCase({
        questionId: question.id,
        priority,
        reason,
        signals: question.metrics.signals
      });

      onSuccess(created);
      onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create review case');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Create Review & Triage Case"
      subtitle={`For Question ${question.sourceKey} (Revision ${question.revision})`}
      maxWidth="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Context Summary */}
        <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 space-y-2 text-xs">
          <div className="flex items-center justify-between">
            <span className="text-slate-400">Target / Category:</span>
            <span className="font-semibold text-slate-200">
              {question.target.toUpperCase()} &bull; {question.category} ({question.primarySkillId})
            </span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-slate-400">Current Accuracy / Attempts:</span>
            <span className="font-semibold text-slate-200">
              {question.metrics.overallAccuracy}% ({question.metrics.totalAttempts} valid attempts)
            </span>
          </div>
          {question.metrics.signals.length > 0 && (
            <div className="pt-2 border-t border-slate-800/80">
              <span className="text-slate-400 block mb-1">Active Automated Signals:</span>
              <div className="flex flex-wrap gap-1.5">
                {question.metrics.signals.map((sig, i) => (
                  <span
                    key={i}
                    className="text-[11px] px-2 py-0.5 rounded-full bg-rose-500/15 text-rose-300 border border-rose-500/30 font-medium"
                  >
                    {sig.replace(/_/g, ' ')}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Priority Selection */}
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1.5">
            Triage Priority
          </label>
          <div className="grid grid-cols-4 gap-2">
            {(['low', 'medium', 'high', 'critical'] as CasePriority[]).map((p) => {
              const isSelected = priority === p;
              return (
                <button
                  type="button"
                  key={p}
                  onClick={() => setPriority(p)}
                  className={`py-2 px-3 rounded-lg text-xs font-semibold uppercase tracking-wider border transition-all ${
                    isSelected
                      ? p === 'critical'
                        ? 'bg-rose-600 text-white border-rose-500 shadow-md shadow-rose-600/30'
                        : p === 'high'
                        ? 'bg-orange-600 text-white border-orange-500 shadow-md shadow-orange-600/30'
                        : p === 'medium'
                        ? 'bg-amber-600 text-white border-amber-500 shadow-md shadow-amber-600/30'
                        : 'bg-slate-700 text-white border-slate-600 shadow-md'
                      : 'bg-slate-900 text-slate-400 border-slate-800 hover:border-slate-700 hover:text-slate-200'
                  }`}
                >
                  {p}
                </button>
              );
            })}
          </div>
        </div>

        {/* Observation / Reason */}
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1.5">
            Reason & Investigation Details <span className="text-rose-400">*</span>
          </label>
          <textarea
            rows={3}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Explain why this case is opened (e.g. distractor anomaly, suspicious learner response time, SME revision required)..."
            className="w-full admin-input resize-none"
            required
          />
        </div>

        {error && (
          <div className="p-3 rounded-lg bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2">
            <ShieldAlert className="w-4 h-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex items-center justify-end gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="admin-button-secondary text-xs"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="admin-button-primary text-xs"
          >
            {loading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Inbox className="w-3.5 h-3.5" />}
            <span>Open Review Case</span>
          </button>
        </div>
      </form>
    </Modal>
  );
};
