import React from 'react';
import { QualityState, TargetType, CaseStatus, CasePriority } from '@/types/admin';

interface BadgeProps {
  variant?: 'target' | 'quality' | 'status' | 'priority' | 'neutral' | 'signal';
  value: string;
  size?: 'sm' | 'md';
}

export const Badge: React.FC<BadgeProps> = ({ variant = 'neutral', value, size = 'md' }) => {
  const sizeClasses = size === 'sm' ? 'px-2.5 py-0.5 text-xs' : 'px-3 py-1 text-xs';

  if (variant === 'target') {
    const isCpns = value.toLowerCase() === 'cpns';
    return (
      <span
        className={`inline-flex items-center font-bold uppercase tracking-wider rounded-lg ${sizeClasses} ${
          isCpns ? 'badge-cpns' : 'badge-bumn'
        }`}
      >
        {value}
      </span>
    );
  }

  if (variant === 'quality') {
    const state = value as QualityState;
    let className = 'badge-approved';
    let label = 'Approved';

    switch (state) {
      case 'approved':
        className = 'badge-approved';
        label = 'Approved';
        break;
      case 'under_review':
        className = 'badge-under-review';
        label = 'Under Review';
        break;
      case 'disabled':
        className = 'badge-disabled';
        label = 'Disabled';
        break;
      case 'invalidated':
        className = 'badge-disabled';
        label = 'Invalidated';
        break;
      case 'development':
        className = 'bg-slate-800 text-slate-300 border border-slate-700';
        label = 'Draft';
        break;
    }

    return (
      <span className={`inline-flex items-center font-semibold rounded-lg ${sizeClasses} ${className}`}>
        <span className="w-2 h-2 rounded-full bg-current mr-1.5 flex-shrink-0"></span>
        {label}
      </span>
    );
  }

  if (variant === 'status') {
    const status = value as CaseStatus;
    const styles: Record<CaseStatus, string> = {
      open: 'bg-amber-500/15 text-amber-300 border border-amber-500/30',
      in_review: 'bg-blue-500/15 text-blue-300 border border-blue-500/30',
      resolved: 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/30',
      dismissed: 'bg-slate-800 text-slate-400 border border-slate-700'
    };

    return (
      <span className={`inline-flex items-center font-semibold capitalize rounded-lg ${sizeClasses} ${styles[status] || styles.open}`}>
        {value.replace('_', ' ')}
      </span>
    );
  }

  if (variant === 'priority') {
    const priority = value as CasePriority;
    const styles: Record<CasePriority, string> = {
      low: 'bg-slate-800 text-slate-300 border border-slate-700',
      medium: 'bg-yellow-500/15 text-yellow-300 border border-yellow-500/30',
      high: 'bg-orange-500/15 text-orange-300 border border-orange-500/30',
      critical: 'bg-rose-500/20 text-rose-300 border border-rose-500/40'
    };

    return (
      <span className={`inline-flex items-center font-bold uppercase tracking-wider rounded-lg ${sizeClasses} ${styles[priority] || styles.medium}`}>
        {value}
      </span>
    );
  }

  if (variant === 'signal') {
    return (
      <span className="badge-signal">
        <span className="w-1.5 h-1.5 rounded-full bg-rose-400"></span>
        {value.replace(/_/g, ' ')}
      </span>
    );
  }

  return (
    <span className={`inline-flex items-center font-medium bg-slate-800/80 text-slate-300 border border-slate-700/60 rounded-lg ${sizeClasses}`}>
      {value}
    </span>
  );
};
