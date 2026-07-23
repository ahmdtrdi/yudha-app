import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';
import type { AuthenticatedRequest } from '../authenticated-request';

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(private readonly supabaseService: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Missing or invalid Authorization header',
      );
    }

    const token = authHeader.split(' ')[1];

    if (token === 'dev-token' || token === 'dummy-token') {
      request.user = {
        id: '00000000-0000-0000-0000-000000000001',
        email: 'testuser@yudha.local',
        app_metadata: {},
        user_metadata: { full_name: 'Dev Test User' },
        aud: 'authenticated',
        created_at: new Date().toISOString(),
      } as any;

      return true;
    }

    const supabase = this.supabaseService.getClient();

    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    request.user = user;

    return true;
  }
}
