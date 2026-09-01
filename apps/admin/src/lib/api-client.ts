import {
  QuestionItem,
  ReviewCase,
  SkillCoverage,
  AuditLogEntry,
  CaseStatus,
  CaseDisposition,
  AdminUser
} from '@/types/admin';
import {
  MOCK_QUESTIONS,
  MOCK_REVIEW_CASES,
  MOCK_COVERAGE,
  MOCK_AUDIT_LOGS
} from './mock-data';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

const STORAGE_KEYS = {
  QUESTIONS: 'yudha_admin_questions',
  CASES: 'yudha_admin_cases',
  AUDIT_LOGS: 'yudha_admin_audit_logs',
  AUTH_USER: 'yudha_admin_user'
};

function getStored<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;
  try {
    const data = localStorage.getItem(key);
    return data ? JSON.parse(data) : fallback;
  } catch {
    return fallback;
  }
}

function setStored<T>(key: string, value: T): void {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.error('Storage error', e);
  }
}

export const adminAuth = {
  getUser: (): AdminUser | null => {
    return getStored<AdminUser | null>(STORAGE_KEYS.AUTH_USER, {
      id: 'usr-admin-01',
      email: 'admin@yudha.app',
      name: 'Yudha Admin QA',
      role: 'admin',
      token: 'jwt-yudha-server-managed-admin-token'
    });
  },
  login: (email: string): AdminUser => {
    const user: AdminUser = {
      id: 'usr-admin-' + Date.now().toString(36),
      email,
      name: email.split('@')[0].toUpperCase(),
      role: 'admin',
      token: 'jwt-token-' + Math.random().toString(36).substring(2)
    };
    setStored(STORAGE_KEYS.AUTH_USER, user);
    return user;
  },
  logout: (): void => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(STORAGE_KEYS.AUTH_USER);
    }
  }
};

export const adminApi = {
  // Questions Quality API
  getQuestions: async (filters?: {
    target?: string;
    category?: string;
    qualityState?: string;
    search?: string;
    hasSignals?: boolean;
  }): Promise<QuestionItem[]> => {
    try {
      const auth = adminAuth.getUser();
      const res = await fetch(`${API_BASE_URL}/admin/content-quality/questions`, {
        headers: {
          Authorization: `Bearer ${auth?.token || ''}`,
          'Content-Type': 'application/json'
        }
      });
      if (res.ok) {
        const json = await res.json();
        return json.data || json;
      }
    } catch {
      // Backend offline: fallback to client storage/mock
    }

    let questions = getStored<QuestionItem[]>(STORAGE_KEYS.QUESTIONS, MOCK_QUESTIONS);
    if (filters) {
      if (filters.target && filters.target !== 'all') {
        questions = questions.filter((q) => q.target === filters.target);
      }
      if (filters.category && filters.category !== 'all') {
        questions = questions.filter((q) => q.category === filters.category);
      }
      if (filters.qualityState && filters.qualityState !== 'all') {
        questions = questions.filter((q) => q.qualityState === filters.qualityState);
      }
      if (filters.search) {
        const query = filters.search.toLowerCase();
        questions = questions.filter(
          (q) =>
            q.prompt.toLowerCase().includes(query) ||
            q.sourceKey.toLowerCase().includes(query) ||
            q.primarySkillId.toLowerCase().includes(query)
        );
      }
      if (filters.hasSignals) {
        questions = questions.filter((q) => q.metrics.signals.length > 0);
      }
    }
    return questions;
  },

  getQuestionById: async (questionId: string): Promise<QuestionItem | null> => {
    try {
      const auth = adminAuth.getUser();
      const res = await fetch(`${API_BASE_URL}/admin/content-quality/questions/${questionId}`, {
        headers: {
          Authorization: `Bearer ${auth?.token || ''}`
        }
      });
      if (res.ok) {
        const json = await res.json();
        return json.data || json;
      }
    } catch {
      // Fallback
    }

    const questions = getStored<QuestionItem[]>(STORAGE_KEYS.QUESTIONS, MOCK_QUESTIONS);
    return questions.find((q) => q.id === questionId) || null;
  },

  deactivateQuestion: async (
    questionId: string,
    reason: string,
    invalidateRevision = false
  ): Promise<{ success: boolean; question: QuestionItem }> => {
    const idempotencyKey = `idemp-deact-${questionId}-${Date.now()}`;
    try {
      const auth = adminAuth.getUser();
      const res = await fetch(`${API_BASE_URL}/admin/content-quality/questions/${questionId}/deactivate`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${auth?.token || ''}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey
        },
        body: JSON.stringify({ reason, invalidateRevision })
      });
      if (res.ok) {
        const json = await res.json();
        return json;
      }
    } catch {
      // Fallback
    }

    const questions = getStored<QuestionItem[]>(STORAGE_KEYS.QUESTIONS, MOCK_QUESTIONS);
    const index = questions.findIndex((q) => q.id === questionId);
    if (index === -1) throw new Error('Question not found');

    const updated: QuestionItem = {
      ...questions[index],
      active: false,
      qualityState: invalidateRevision ? 'invalidated' : 'disabled',
      deactivatedAt: new Date().toISOString(),
      deactivationReason: reason,
      deactivatedBy: adminAuth.getUser()?.email || 'admin@yudha.app'
    };

    questions[index] = updated;
    setStored(STORAGE_KEYS.QUESTIONS, questions);

    // Record audit log
    const auditLogs = getStored<AuditLogEntry[]>(STORAGE_KEYS.AUDIT_LOGS, MOCK_AUDIT_LOGS);
    auditLogs.unshift({
      id: `audit-${Date.now()}`,
      timestamp: new Date().toISOString(),
      adminEmail: adminAuth.getUser()?.email || 'admin@yudha.app',
      action: 'deactivate_question',
      targetResource: 'question',
      resourceId: questionId,
      reason,
      metadata: { invalidateRevision },
      idempotencyKey
    });
    setStored(STORAGE_KEYS.AUDIT_LOGS, auditLogs);

    return { success: true, question: updated };
  },

  reactivateQuestion: async (
    questionId: string,
    reason: string
  ): Promise<{ success: boolean; question: QuestionItem }> => {
    const idempotencyKey = `idemp-react-${questionId}-${Date.now()}`;
    try {
      const auth = adminAuth.getUser();
      const res = await fetch(`${API_BASE_URL}/admin/content-quality/questions/${questionId}/reactivate`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${auth?.token || ''}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey
        },
        body: JSON.stringify({ reason })
      });
      if (res.ok) {
        const json = await res.json();
        return json;
      }
    } catch {
      // Fallback
    }

    const questions = getStored<QuestionItem[]>(STORAGE_KEYS.QUESTIONS, MOCK_QUESTIONS);
    const index = questions.findIndex((q) => q.id === questionId);
    if (index === -1) throw new Error('Question not found');

    const updated: QuestionItem = {
      ...questions[index],
      active: true,
      qualityState: 'approved',
      deactivatedAt: null,
      deactivationReason: null,
      deactivatedBy: null
    };

    questions[index] = updated;
    setStored(STORAGE_KEYS.QUESTIONS, questions);

    // Record audit log
    const auditLogs = getStored<AuditLogEntry[]>(STORAGE_KEYS.AUDIT_LOGS, MOCK_AUDIT_LOGS);
    auditLogs.unshift({
      id: `audit-${Date.now()}`,
      timestamp: new Date().toISOString(),
      adminEmail: adminAuth.getUser()?.email || 'admin@yudha.app',
      action: 'reactivate_question',
      targetResource: 'question',
      resourceId: questionId,
      reason,
      idempotencyKey
    });
    setStored(STORAGE_KEYS.AUDIT_LOGS, auditLogs);

    return { success: true, question: updated };
  },

  // Review Cases API
  getReviewCases: async (filters?: { status?: string; target?: string }): Promise<ReviewCase[]> => {
    try {
      const auth = adminAuth.getUser();
      const res = await fetch(`${API_BASE_URL}/admin/content-quality/review-cases`, {
        headers: {
          Authorization: `Bearer ${auth?.token || ''}`
        }
      });
      if (res.ok) {
        const json = await res.json();
        return json.data || json;
      }
    } catch {
      // Fallback
    }

    let cases = getStored<ReviewCase[]>(STORAGE_KEYS.CASES, MOCK_REVIEW_CASES);
    if (filters) {
      if (filters.status && filters.status !== 'all') {
        cases = cases.filter((c) => c.status === filters.status);
      }
      if (filters.target && filters.target !== 'all') {
        cases = cases.filter((c) => c.target === filters.target);
      }
    }
    return cases;
  },

  createReviewCase: async (payload: {
    questionId: string;
    priority: 'low' | 'medium' | 'high' | 'critical';
    reason: string;
    signals?: string[];
  }): Promise<ReviewCase> => {
    const questions = getStored<QuestionItem[]>(STORAGE_KEYS.QUESTIONS, MOCK_QUESTIONS);
    const q = questions.find((item) => item.id === payload.questionId);
    if (!q) throw new Error('Question not found');

    const newCase: ReviewCase = {
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
        totalAttempts: q.metrics.totalAttempts
      },
      assignedTo: adminAuth.getUser()?.email || 'admin@yudha.app',
      notes: [],
      disposition: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      resolvedAt: null,
      resolvedBy: null
    };

    const cases = getStored<ReviewCase[]>(STORAGE_KEYS.CASES, MOCK_REVIEW_CASES);
    cases.unshift(newCase);
    setStored(STORAGE_KEYS.CASES, cases);

    // Update question status to under_review
    const qIndex = questions.findIndex((item) => item.id === q.id);
    if (qIndex !== -1) {
      questions[qIndex].qualityState = 'under_review';
      setStored(STORAGE_KEYS.QUESTIONS, questions);
    }

    return newCase;
  },

  updateCaseStatus: async (
    caseId: string,
    status: CaseStatus,
    disposition?: CaseDisposition,
    noteText?: string
  ): Promise<ReviewCase> => {
    const cases = getStored<ReviewCase[]>(STORAGE_KEYS.CASES, MOCK_REVIEW_CASES);
    const index = cases.findIndex((c) => c.id === caseId);
    if (index === -1) throw new Error('Case not found');

    const current = cases[index];
    const updated: ReviewCase = {
      ...current,
      status,
      disposition: disposition || current.disposition,
      updatedAt: new Date().toISOString(),
      resolvedAt: status === 'resolved' || status === 'dismissed' ? new Date().toISOString() : current.resolvedAt,
      resolvedBy: status === 'resolved' || status === 'dismissed' ? (adminAuth.getUser()?.email || 'admin@yudha.app') : current.resolvedBy
    };

    if (noteText) {
      updated.notes.push({
        id: `note-${Date.now()}`,
        author: adminAuth.getUser()?.email || 'admin@yudha.app',
        authorRole: 'Admin QA',
        timestamp: new Date().toISOString(),
        content: noteText
      });
    }

    cases[index] = updated;
    setStored(STORAGE_KEYS.CASES, cases);
    return updated;
  },

  // Coverage and Inventory
  getCoverage: async (): Promise<SkillCoverage[]> => {
    return MOCK_COVERAGE;
  },

  // Audit Logs
  getAuditLogs: async (): Promise<AuditLogEntry[]> => {
    return getStored<AuditLogEntry[]>(STORAGE_KEYS.AUDIT_LOGS, MOCK_AUDIT_LOGS);
  }
};
