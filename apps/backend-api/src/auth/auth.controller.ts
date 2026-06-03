import { Body, Controller, Post } from '@nestjs/common';
import { AuthService, type LoginPayload, type RegisterPayload } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() payload: RegisterPayload) {
    return this.authService.register(payload);
  }

  @Post('login')
  login(@Body() payload: LoginPayload) {
    return this.authService.login(payload);
  }
}
