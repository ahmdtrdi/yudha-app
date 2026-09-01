'use client';

import React, { useState } from 'react';
import { Modal } from '@/components/ui/Modal';
import { QuestionItem } from '@/types/admin';
import { AlertOctagon, ShieldAlert, CheckCircle2, Loader2 } from 'lucide-react';
import { adminApi } from '@/lib/api-client';

interface DeactivateModalProps {
  isOpen: boolean;
  onClose: () => void;
  question: QuestionItem;
  onSuccess: (updated: QuestionItem) => void;
}

export const DeactivateModal: React.FC<DeactivateModalProps> = ({
  isOpen,
  onClose,
  question,
  onSuccess
}) => {
  const [reason, setReason] = useState('');
  const [invalidateRevision, setInvalidateRevision] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isReactivating = !question.active;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reason.trim()) {
      setError('An explicit audit reason is required by PRD Section 16.5.');
      return;
    }

    try {
      setLoading(true);
      setError(null);

      let res;
      if (isReactivating) {
        res = await adminApi.reactivateQuestion(question.id, reason);
      } else {
        res = await adminApi.deactivateQuestion(question.id, reason, invalidateRevision);
      }

      onSuccess(res.question);
      onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to update question status');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={isReactivating ? 'Reactivate Question' : 'Controlled Question Deactivation'}
      subtitle={`Question ID: ${question.sourceKey} (Revision ${question.revision})`}
      maxWidth="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Warning Banner */}
        <div
          className={`p-4 rounded-xl border flex items-start gap-3 ${
            isReactivating
              ? 'bg-emerald-950/20 border-emerald-500/30 text-emerald-300'
              : 'bg-rose-950/20 border-rose-500/30 text-rose-300'
          }`}
        >
          {isReactivating ? (
            <CheckCircle2 className="w-5 h-5 flex-shrink-0 mt-0.5 text-emerald-400" />
          ) : (
            <AlertOctagon className="w-5 h-5 flex-shrink-0 mt-0.5 text-rose-400" />
          )}
          <div className="text-xs space-y-1">
            <div className="font-semibold text-sm">
              {isReactivating
                ? 'Re-enabling question for session delivery'
                : 'Controlled Manual Deactivation Notice'}
            </div>
            <p className="opacity-90">
              {isReactivating
                ? 'This question will immediately become eligible for player solo matches and assessments.'
                : 'Deactivating this question takes effect immediately and removes it from future matchmaking and solo queues. All actions are immutably logged with admin role authorization.'}
            </p>
          </div>
        </div>

        {/* Question Prompt Preview */}
        <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800 text-xs">
          <span className="text-slate-400 font-medium">Stem Preview: </span>
          <span className="text-slate-200">{question.prompt}</span>
        </div>

        {/* Reason Input */}
        <div>
          <label className="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1.5">
            Audit Reason <span className="text-rose-400">*</span>
          </label>
          <textarea
            rows={3}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={
              isReactivating
                ? 'e.g., Content ambiguity fixed in revision, verified by SME team.'
                : 'e.g., Severe distractor trap found, confusing premise syntax reported in review case.'
            }
            className="w-full admin-input resize-none"
            required
          />
          <p className="text-[11px] text-slate-400 mt-1">
            Required audit log documentation for administrative compliance.
          </p>
        </div>

        {/* Invalidation Checkbox (Deactivation only) */}
        {!isReactivating && (
          <div className="p-3.5 rounded-lg bg-slate-950 border border-slate-800 flex items-start gap-3">
            <input
              type="checkbox"
              id="invalidateRev"
              checked={invalidateRevision}
              onChange={(e) => setInvalidateRevision(e.target.checked)}
              className="mt-0.5 rounded border-slate-700 text-indigo-600 focus:ring-indigo-500"
            />
            <label htmlFor="invalidateRev" className="text-xs cursor-pointer select-none">
              <span className="font-semibold text-slate-200 block">
                Invalidate Revision Psychometrics (V2 Recalibration)
              </span>
              <span className="text-slate-400 block mt-0.5">
                Mark revision as invalid and trigger learner proficiency recalculations, while preserving raw attempt audit history.
              </span>
            </label>
          </div>
        )}

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
            className={
              isReactivating
                ? 'admin-button-primary text-xs'
                : 'admin-button-danger text-xs'
            }
          >
            {loading && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
            <span>
              {isReactivating ? 'Confirm Reactivation' : 'Confirm Controlled Deactivation'}
            </span>
          </button>
        </div>
      </form>
    </Modal>
  );
};
