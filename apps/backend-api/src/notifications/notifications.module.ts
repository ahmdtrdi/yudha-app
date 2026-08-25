import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { FirebasePushService } from './firebase-push.service';
import { NotificationSchedulerService } from './notification-scheduler.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Module({
  imports: [SupabaseModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    FirebasePushService,
    NotificationSchedulerService,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
