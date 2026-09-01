export class RecommendationEventDto {
  idempotencyKey: string;
  eventType: 'shown' | 'accepted' | 'dismissed';
  dismissalReason?:
    | 'prefer_another_skill'
    | 'too_difficult'
    | 'too_easy'
    | 'not_enough_time'
    | 'do_not_like_timed_mode'
    | 'other';
}
