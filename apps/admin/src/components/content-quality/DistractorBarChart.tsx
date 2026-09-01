'use client';

import React from 'react';
import { DistractorStat } from '@/types/admin';
import { CheckCircle2, AlertTriangle } from 'lucide-react';

interface DistractorBarChartProps {
  distractors: DistractorStat[];
  totalAttempts: number;
}

export const DistractorBarChart: React.FC<DistractorBarChartProps> = ({
  distractors,
  totalAttempts
}) => {
  return (
    <div className="space-y-3">
      {distractors.map((item, idx) => {
        const optionLetter = String.fromCharCode(65 + item.optionIndex);
        const isSuspiciousTrap = !item.isCorrect && item.percentage > 35;
        const isNonFunctioning = !item.isCorrect && item.percentage < 2.0 && totalAttempts > 200;

        return (
          <div
            key={idx}
            className={`p-3.5 rounded-xl border transition-all ${
              item.isCorrect
                ? 'bg-emerald-950/20 border-emerald-500/30'
                : isSuspiciousTrap
                ? 'bg-rose-950/20 border-rose-500/30'
                : 'bg-slate-900/60 border-slate-800'
            }`}
          >
            <div className="flex items-start justify-between gap-3 mb-2">
              <div className="flex items-center gap-2.5 flex-1 min-w-0">
                <span
                  className={`w-6 h-6 rounded-lg text-xs font-bold flex items-center justify-center flex-shrink-0 ${
                    item.isCorrect
                      ? 'bg-emerald-500 text-slate-950'
                      : 'bg-slate-800 text-slate-300'
                  }`}
                >
                  {optionLetter}
                </span>
                <span className="text-xs text-slate-200 font-medium truncate">
                  {item.text}
                </span>
                {item.isCorrect && (
                  <span className="flex items-center gap-1 text-[11px] font-semibold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-md border border-emerald-500/20">
                    <CheckCircle2 className="w-3 h-3" />
                    Correct Answer
                  </span>
                )}
                {isSuspiciousTrap && (
                  <span className="flex items-center gap-1 text-[11px] font-semibold text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded-md border border-rose-500/20">
                    <AlertTriangle className="w-3 h-3" />
                    Distractor Trap ({item.percentage}%)
                  </span>
                )}
                {isNonFunctioning && (
                  <span className="text-[11px] font-medium text-amber-400 bg-amber-500/10 px-1.5 py-0.5 rounded border border-amber-500/20">
                    Non-functioning ({item.percentage}%)
                  </span>
                )}
              </div>

              <div className="text-right flex-shrink-0">
                <span className="text-xs font-bold text-slate-100">{item.percentage}%</span>
                <span className="text-[11px] text-slate-400 ml-1.5 font-mono">
                  ({item.count.toLocaleString()} attempts)
                </span>
              </div>
            </div>

            {/* Visual Bar */}
            <div className="w-full bg-slate-950 rounded-full h-2 overflow-hidden">
              <div
                className={`h-full rounded-full transition-all duration-500 ${
                  item.isCorrect
                    ? 'bg-gradient-to-r from-emerald-500 to-teal-400'
                    : isSuspiciousTrap
                    ? 'bg-gradient-to-r from-rose-500 to-pink-500'
                    : 'bg-slate-600'
                }`}
                style={{ width: `${Math.max(item.percentage, 1)}%` }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
};
