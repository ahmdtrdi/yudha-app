/** Action types that can be logged during a match */
export type MatchLogAction = 'open_card' | 'play_card' | 'surrender' | 'timeout';

/** Shape of a buffered log entry before persistence */
export type MatchLogEntry = {
  userId: string;
  action: MatchLogAction;
  payload: Record<string, unknown>;
  createdAt: Date;
};

/** Shape sent to the RPC for bulk insertion */
export type MatchLogRpcEntry = {
  user_id: string;
  action: string;
  payload: Record<string, unknown>;
  created_at: string;
};
