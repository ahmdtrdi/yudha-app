import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigModule } from '@nestjs/config';
import { InterviewModule } from './interview/interview.module';
import { SupabaseModule } from './supabase/supabase.module';
import { ProfileModule } from './profile/profile.module';
import { AuthModule } from './auth/auth.module';
import { LeaderboardModule } from './leaderboard/leaderboard.module';
import { PracticeModule } from './practice/practice.module';
import { MatchesModule } from './matches/matches.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { HiredPassModule } from './hired-pass/hired-pass.module';
import { StoreModule } from './store/store.module';
import { LobbyModule } from './lobby/lobby.module';
import { ScheduleModule } from '@nestjs/schedule';
import { NotificationsModule } from './notifications/notifications.module';
import { LearningModule } from './learning/learning.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['apps/backend-api/.env', '.env'],
    }),
    ScheduleModule.forRoot(),
    SupabaseModule,
    AuthModule,
    ProfileModule,
    LeaderboardModule,
    PracticeModule,
    InterviewModule,
    MatchesModule,
    AnalyticsModule,
    StoreModule,
    HiredPassModule,
    LobbyModule,
    NotificationsModule,
    LearningModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
