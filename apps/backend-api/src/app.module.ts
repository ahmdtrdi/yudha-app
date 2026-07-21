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

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['apps/backend-api/.env', '.env'],
    }),
    SupabaseModule,
    AuthModule,
    ProfileModule,
    LeaderboardModule,
    PracticeModule,
    InterviewModule,
    MatchesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
