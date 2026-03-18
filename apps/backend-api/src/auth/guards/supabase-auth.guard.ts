import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(private readonly supabaseService: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    // 1. Check if the Flutter app sent the token
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid Authorization header');
    }

    // 2. Extract just the token part (remove "Bearer ")
    const token = authHeader.split(' ')[1];
    const supabase = this.supabaseService.getClient();

    // 3. Ask Supabase to verify the token
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    // 4. Token is valid! Attach the user info to the request for the @GetUser decorator
    request.user = user;
    
    return true; 
  }
}