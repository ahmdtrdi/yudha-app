import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_providers.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_page_payload.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';
import 'package:yudha_mobile/features/leaderboard/presentation/pages/leaderboard_page.dart';

class _SuccessLeaderboardRepository extends LeaderboardRepository {
  const _SuccessLeaderboardRepository();

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) async {
    return const LeaderboardPagePayload(
      entries: <LeaderboardEntry>[
        LeaderboardEntry(
          playerId: 'alpha',
          playerName: 'Alpha',
          points: 1000,
          winRate: 0.8,
          streak: 4,
          isCurrentUser: false,
        ),
      ],
      hasMore: false,
    );
  }
}

class _EmptyLeaderboardRepository extends LeaderboardRepository {
  const _EmptyLeaderboardRepository();

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) async {
    return const LeaderboardPagePayload(
      entries: <LeaderboardEntry>[],
      hasMore: false,
    );
  }
}

class _ErrorLeaderboardRepository extends LeaderboardRepository {
  const _ErrorLeaderboardRepository();

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) async {
    throw Exception('network');
  }
}

class _PendingLeaderboardRepository extends LeaderboardRepository {
  const _PendingLeaderboardRepository();

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) {
    return Completer<LeaderboardPagePayload>().future;
  }
}

void main() {
  testWidgets('renders loading state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          leaderboardRepositoryProvider.overrideWithValue(
            const _PendingLeaderboardRepository(),
          ),
        ],
        child: const MaterialApp(home: LeaderboardPage()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders success state with ranking items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          leaderboardRepositoryProvider.overrideWithValue(
            const _SuccessLeaderboardRepository(),
          ),
        ],
        child: const MaterialApp(home: LeaderboardPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Kamu'), findsOneWidget);
  });

  testWidgets('renders empty state for weekly leaderboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          leaderboardRepositoryProvider.overrideWithValue(
            const _EmptyLeaderboardRepository(),
          ),
        ],
        child: const MaterialApp(home: LeaderboardPage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    expect(
      find.text('No weekly records yet. Play a match first.'),
      findsOneWidget,
    );
  });

  testWidgets('renders error state with retry action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          leaderboardRepositoryProvider.overrideWithValue(
            const _ErrorLeaderboardRepository(),
          ),
        ],
        child: const MaterialApp(home: LeaderboardPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Failed to load leaderboard'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
