import type { User } from '@supabase/supabase-js';
import type { Request } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: User;
}
