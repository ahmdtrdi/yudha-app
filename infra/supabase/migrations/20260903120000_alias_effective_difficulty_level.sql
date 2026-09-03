-- Migration: 20260903120000_alias_effective_difficulty_level.sql
-- Description: Add effective_difficulty_level column to learning_attempts for backward/forward compatibility.

BEGIN;

ALTER TABLE public.learning_attempts
  ADD COLUMN IF NOT EXISTS effective_difficulty_level text;

-- Backfill existing rows
UPDATE public.learning_attempts
  SET effective_difficulty_level = difficulty
  WHERE effective_difficulty_level IS NULL AND difficulty IS NOT NULL;

COMMIT;
