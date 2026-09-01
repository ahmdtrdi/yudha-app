import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export interface DistractorStat {
  optionIndex: number;
  text: string;
  count: number;
  percentage: number;
  isCorrect: boolean;
}

export interface QuestionMetrics {
  totalAttempts: number;
  unseenAttempts: number;
  overallAccuracy: number;
  unseenAccuracy: number;
  seenUnseenGap: number;
  medianResponseTimeMs: number;
  timeoutRate: number;
  hintRate: number;
  discriminationIndex: number;
  distractors: DistractorStat[];
  signals: string[];
}

export interface AdminQuestionItem {
  id: string;
  sourceKey: string;
  revision: number;
  target: 'cpns' | 'bumn';
  category: string;
  subcategory: string | null;
  primarySkillId: string;
  prerequisiteSkillIds: string[];
  prompt: string;
  options: string[];
  correctOptionIndex: number;
  explanation: string;
  difficulty: number;
  standardTimeLimitMs: number;
  expectedTimeMs: number | null;
  curriculumWeight: number;
  assessmentEligible: boolean;
  qualityState: string;
  smeApproved: boolean;
  approvedAt: string | null;
  approverReference: string | null;
  active: boolean;
  metrics: QuestionMetrics;
  lastUsedAt: string;
  deactivatedAt?: string | null;
  deactivationReason?: string | null;
  deactivatedBy?: string | null;
}

export interface AdminReviewCase {
  id: string;
  questionId: string;
  questionRevision: number;
  target: string;
  category: string;
  skillId: string;
  promptSnippet: string;
  status: 'open' | 'in_review' | 'resolved' | 'dismissed';
  priority: 'low' | 'medium' | 'high' | 'critical';
  signals: string[];
  manualReason: string;
  evidenceSnapshot: {
    overallAccuracy: number;
    unseenAccuracy: number;
    timeoutRate: number;
    hintRate: number;
    medianResponseTimeMs: number;
    totalAttempts: number;
    flaggedDistractors?: number[];
  };
  assignedTo: string;
  notes: {
    id: string;
    author: string;
    authorRole: string;
    timestamp: string;
    content: string;
  }[];
  disposition: string | null;
  createdAt: string;
  updatedAt: string;
  resolvedAt: string | null;
  resolvedBy: string | null;
}

@Injectable()
export class AdminContentQualityService {
  constructor(private readonly supabaseService: SupabaseService) {}

  // In-memory / DB state store
  private questions: AdminQuestionItem[] = [
    {
      id: 'q-tiu-analogi-01',
      sourceKey: 'TIU-ANA-2024-001',
      revision: 2,
      target: 'cpns',
      category: 'TIU',
      subcategory: 'Verbal',
      primarySkillId: 'analogi_kata',
      prerequisiteSkillIds: ['kosakata_dasar'],
      prompt: 'KOSONG : HAMPA = KELAS : ... ?',
      options: ['Sekolah', 'Ruang Belajar', 'Tingkatan', 'Siswa', 'Pelajaran'],
      correctOptionIndex: 2,
      explanation: 'Kosong dan hampa merupakan sinonim. Hubungan yang sama berlaku untuk Kelas dan Tingkatan.',
      difficulty: 3,
      standardTimeLimitMs: 45000,
      expectedTimeMs: 28000,
      curriculumWeight: 1.0,
      assessmentEligible: true,
      qualityState: 'approved',
      smeApproved: true,
      approvedAt: '2025-08-10T09:00:00Z',
      approverReference: 'SME-DOC-TIU-04',
      active: true,
      lastUsedAt: '2026-08-31T14:20:00Z',
      metrics: {
        totalAttempts: 1420,
        unseenAttempts: 890,
        overallAccuracy: 68.4,
        unseenAccuracy: 62.1,
        seenUnseenGap: 6.3,
        medianResponseTimeMs: 24500,
        timeoutRate: 3.2,
        hintRate: 7.8,
        discriminationIndex: 0.44,
        distractors: [
          { optionIndex: 0, text: 'Sekolah', count: 180, percentage: 12.7, isCorrect: false },
          { optionIndex: 1, text: 'Ruang Belajar', count: 195, percentage: 13.7, isCorrect: false },
          { optionIndex: 2, text: 'Tingkatan', count: 971, percentage: 68.4, isCorrect: true },
          { optionIndex: 3, text: 'Siswa', count: 54, percentage: 3.8, isCorrect: false },
          { optionIndex: 4, text: 'Pelajaran', count: 20, percentage: 1.4, isCorrect: false }
        ],
        signals: []
      }
    },
    {
      id: 'q-tiu-silogisme-02',
      sourceKey: 'TIU-SIL-2024-042',
      revision: 1,
      target: 'cpns',
      category: 'TIU',
      subcategory: 'Logika',
      primarySkillId: 'silogisme_kategoris',
      prerequisiteSkillIds: ['premis_dasar'],
      prompt: 'Semua ilmuwan berpikir kritis. Sebagian ilmuwan gemar menulis artikel ilmiah. Kesimpulan yang benar adalah...',
      options: [
        'Semua yang gemar menulis artikel ilmiah berpikir kritis',
        'Sebagian yang berpikir kritis gemar menulis artikel ilmiah',
        'Semua yang berpikir kritis adalah ilmuwan',
        'Ilmuwan yang tidak berpikir kritis tidak gemar menulis artikel',
        'Tidak ada ilmuwan yang tidak gemar menulis'
      ],
      correctOptionIndex: 1,
      explanation: 'Premis 1: Semua A adalah B. Premis 2: Sebagian A adalah C. Kesimpulan: Sebagian B adalah C.',
      difficulty: 4,
      standardTimeLimitMs: 60000,
      expectedTimeMs: 38000,
      curriculumWeight: 1.2,
      assessmentEligible: true,
      qualityState: 'under_review',
      smeApproved: false,
      approvedAt: null,
      approverReference: null,
      active: true,
      lastUsedAt: '2026-08-31T18:45:00Z',
      metrics: {
        totalAttempts: 980,
        unseenAttempts: 640,
        overallAccuracy: 24.5,
        unseenAccuracy: 18.2,
        seenUnseenGap: 6.3,
        medianResponseTimeMs: 54200,
        timeoutRate: 18.6,
        hintRate: 26.4,
        discriminationIndex: 0.12,
        distractors: [
          { optionIndex: 0, text: 'Semua yang gemar menulis artikel ilmiah berpikir kritis', count: 480, percentage: 49.0, isCorrect: false },
          { optionIndex: 1, text: 'Sebagian yang berpikir kritis gemar menulis artikel ilmiah', count: 240, percentage: 24.5, isCorrect: true },
          { optionIndex: 2, text: 'Semua yang berpikir kritis adalah ilmuwan', count: 120, percentage: 12.2, isCorrect: false },
          { optionIndex: 3, text: 'Ilmuwan yang tidak berpikir kritis tidak gemar menulis artikel', count: 110, percentage: 11.2, isCorrect: false },
          { optionIndex: 4, text: 'Tidak ada ilmuwan yang tidak gemar menulis', count: 30, percentage: 3.1, isCorrect: false }
        ],
        signals: ['low_accuracy', 'suspicious_distractor_0', 'high_timeout_rate']
      }
    }
  ];

  private reviewCases: AdminReviewCase[] = [
    {
      id: 'CASE-2026-089',
      questionId: 'q-tiu-silogisme-02',
      questionRevision: 1,
      target: 'cpns',
      category: 'TIU',
      skillId: 'silogisme_kategoris',
      promptSnippet: 'Semua ilmuwan berpikir kritis. Sebagian ilmuwan gemar menulis...',
      status: 'in_review',
      priority: 'high',
      signals: ['low_accuracy', 'suspicious_distractor_0', 'high_timeout_rate'],
      manualReason: 'Akurasi 24.5% jauh di bawah benchmark kesulitan 4. 49% responden memilih Opsi A.',
      evidenceSnapshot: {
        overallAccuracy: 24.5,
        unseenAccuracy: 18.2,
        timeoutRate: 18.6,
        hintRate: 26.4,
        medianResponseTimeMs: 54200,
        totalAttempts: 980,
        flaggedDistractors: [0]
      },
      assignedTo: 'admin@yudha.app',
      notes: [
        {
          id: 'note-1',
          author: 'admin@yudha.app',
          authorRole: 'Admin QA',
          timestamp: '2026-08-30T10:15:00Z',
          content: 'Distractor opsi A menjadi jebakan yang tidak fair.'
        }
      ],
      disposition: null,
      createdAt: '2026-08-29T14:00:00Z',
      updatedAt: '2026-08-31T09:30:00Z',
      resolvedAt: null,
      resolvedBy: null
    }
  ];

  async getQuestions(filters?: {
    target?: string;
    category?: string;
    qualityState?: string;
  }): Promise<AdminQuestionItem[]> {
    let result = [...this.questions];
    if (filters?.target && filters.target !== 'all') {
      result = result.filter((q) => q.target === filters.target);
    }
    if (filters?.category && filters.category !== 'all') {
      result = result.filter((q) => q.category === filters.category);
    }
    if (filters?.qualityState && filters.qualityState !== 'all') {
      result = result.filter((q) => q.qualityState === filters.qualityState);
    }
    return result;
  }

  async getQuestionById(questionId: string): Promise<AdminQuestionItem> {
    const q = this.questions.find((item) => item.id === questionId);
    if (!q) {
      throw new NotFoundException(`Question with ID ${questionId} not found`);
    }
    return q;
  }

  async deactivateQuestion(
    questionId: string,
    reason: string,
    adminEmail: string,
    invalidateRevision = false
  ): Promise<{ success: boolean; question: AdminQuestionItem }> {
    if (!reason || reason.trim().length === 0) {
      throw new BadRequestException('Reason is required for controlled deactivation');
    }

    const qIndex = this.questions.findIndex((item) => item.id === questionId);
    if (qIndex === -1) {
      throw new NotFoundException(`Question with ID ${questionId} not found`);
    }

    this.questions[qIndex] = {
      ...this.questions[qIndex],
      active: false,
      qualityState: invalidateRevision ? 'invalidated' : 'disabled',
      deactivatedAt: new Date().toISOString(),
      deactivationReason: reason,
      deactivatedBy: adminEmail,
    };

    return {
      success: true,
      question: this.questions[qIndex],
    };
  }

  async reactivateQuestion(
    questionId: string,
    reason: string,
  ): Promise<{ success: boolean; question: AdminQuestionItem }> {
    if (!reason || reason.trim().length === 0) {
      throw new BadRequestException('Reason is required for question reactivation');
    }

    const qIndex = this.questions.findIndex((item) => item.id === questionId);
    if (qIndex === -1) {
      throw new NotFoundException(`Question with ID ${questionId} not found`);
    }

    this.questions[qIndex] = {
      ...this.questions[qIndex],
      active: true,
      qualityState: 'approved',
      deactivatedAt: null,
      deactivationReason: null,
      deactivatedBy: null,
    };

    return {
      success: true,
      question: this.questions[qIndex],
    };
  }

  async getReviewCases(filters?: { status?: string }): Promise<AdminReviewCase[]> {
    let result = [...this.reviewCases];
    if (filters?.status && filters.status !== 'all') {
      result = result.filter((c) => c.status === filters.status);
    }
    return result;
  }

  async createReviewCase(
    payload: {
      questionId: string;
      priority: 'low' | 'medium' | 'high' | 'critical';
      reason: string;
      signals?: string[];
    },
    adminEmail: string
  ): Promise<AdminReviewCase> {
    const q = this.questions.find((item) => item.id === payload.questionId);
    if (!q) {
      throw new NotFoundException(`Question with ID ${payload.questionId} not found`);
    }

    const newCase: AdminReviewCase = {
      id: `CASE-${new Date().getFullYear()}-${Math.floor(100 + Math.random() * 900)}`,
      questionId: q.id,
      questionRevision: q.revision,
      target: q.target,
      category: q.category,
      skillId: q.primarySkillId,
      promptSnippet: q.prompt.substring(0, 80) + '...',
      status: 'open',
      priority: payload.priority,
      signals: payload.signals || q.metrics.signals,
      manualReason: payload.reason,
      evidenceSnapshot: {
        overallAccuracy: q.metrics.overallAccuracy,
        unseenAccuracy: q.metrics.unseenAccuracy,
        timeoutRate: q.metrics.timeoutRate,
        hintRate: q.metrics.hintRate,
        medianResponseTimeMs: q.metrics.medianResponseTimeMs,
        totalAttempts: q.metrics.totalAttempts,
      },
      assignedTo: adminEmail,
      notes: [],
      disposition: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      resolvedAt: null,
      resolvedBy: null,
    };

    this.reviewCases.unshift(newCase);
    return newCase;
  }

  async updateReviewCase(
    caseId: string,
    payload: {
      status?: 'open' | 'in_review' | 'resolved' | 'dismissed';
      disposition?: string;
      note?: string;
    },
    adminEmail: string
  ): Promise<AdminReviewCase> {
    const index = this.reviewCases.findIndex((c) => c.id === caseId);
    if (index === -1) {
      throw new NotFoundException(`Review case with ID ${caseId} not found`);
    }

    const current = this.reviewCases[index];
    const status = payload.status || current.status;

    const updated: AdminReviewCase = {
      ...current,
      status,
      disposition: payload.disposition || current.disposition,
      updatedAt: new Date().toISOString(),
      resolvedAt:
        status === 'resolved' || status === 'dismissed'
          ? new Date().toISOString()
          : current.resolvedAt,
      resolvedBy:
        status === 'resolved' || status === 'dismissed'
          ? adminEmail
          : current.resolvedBy,
    };

    if (payload.note && payload.note.trim().length > 0) {
      updated.notes.push({
        id: `note-${Date.now()}`,
        author: adminEmail,
        authorRole: 'Admin QA',
        timestamp: new Date().toISOString(),
        content: payload.note,
      });
    }

    this.reviewCases[index] = updated;
    return updated;
  }
}
