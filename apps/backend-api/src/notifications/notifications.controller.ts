import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { GetUser } from '../auth/decorators/get-user.decorator';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { NotificationsService } from './notifications.service';

interface AuthenticatedUser {
  id: string;
}

@Controller('notifications')
@UseGuards(SupabaseAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get('preferences')
  async getPreferences(@GetUser() user: AuthenticatedUser) {
    return { data: await this.notificationsService.getPreferences(user.id) };
  }

  @Patch('preferences')
  async updatePreferences(
    @GetUser() user: AuthenticatedUser,
    @Body() body: Record<string, unknown>,
  ) {
    return {
      data: await this.notificationsService.updatePreferences(user.id, body),
    };
  }

  @Put('installations/:installationId')
  async registerInstallation(
    @GetUser() user: AuthenticatedUser,
    @Param('installationId') installationId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return {
      data: await this.notificationsService.registerInstallation(
        user.id,
        installationId,
        body,
      ),
    };
  }

  @Delete('installations/:installationId')
  async removeInstallation(
    @GetUser() user: AuthenticatedUser,
    @Param('installationId') installationId: string,
  ) {
    return {
      data: await this.notificationsService.removeInstallation(
        user.id,
        installationId,
      ),
    };
  }

  @Post('deliveries/:deliveryId/open')
  async markOpened(
    @GetUser() user: AuthenticatedUser,
    @Param('deliveryId') deliveryId: string,
  ) {
    return {
      data: await this.notificationsService.markOpened(user.id, deliveryId),
    };
  }
}
