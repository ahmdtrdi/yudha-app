import React from 'react';
import { LucideIcon } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  change?: string;
  changeType?: 'positive' | 'negative' | 'neutral';
  icon: LucideIcon;
  iconColor?: string;
}

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  subtitle,
  change,
  changeType = 'neutral',
  icon: Icon,
  iconColor = 'text-indigo-400'
}) => {
  return (
    <div className="glass-panel p-6 relative overflow-hidden group hover:border-indigo-500/40 transition-all duration-200 shadow-sm">
      <div className="flex items-start justify-between">
        <div className="space-y-1">
          <p className="text-xs font-bold uppercase tracking-wider text-slate-400">{title}</p>
          <h3 className="text-3xl font-extrabold text-slate-50 tracking-tight">{value}</h3>
          {subtitle && <p className="text-sm text-slate-300 font-medium">{subtitle}</p>}
          {change && (
            <div className="flex items-center gap-1.5 pt-1 text-xs font-semibold">
              <span
                className={
                  changeType === 'positive'
                    ? 'text-emerald-400'
                    : changeType === 'negative'
                    ? 'text-rose-400'
                    : 'text-slate-400'
                }
              >
                {change}
              </span>
              <span className="text-slate-400">vs last 30d</span>
            </div>
          )}
        </div>
        <div className={`p-3.5 rounded-2xl bg-slate-800/90 border border-slate-700/60 ${iconColor} flex-shrink-0`}>
          <Icon className="w-6 h-6" />
        </div>
      </div>
      <div className="absolute -bottom-10 -right-10 w-28 h-28 bg-indigo-500/5 rounded-full blur-2xl group-hover:bg-indigo-500/10 transition-all"></div>
    </div>
  );
};
