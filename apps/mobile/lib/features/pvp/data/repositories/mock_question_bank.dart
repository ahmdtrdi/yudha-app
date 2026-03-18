import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';

abstract final class MockQuestionBank {
  static List<BattleQuestion> sample() {
    return const <BattleQuestion>[
      BattleQuestion(
        id: 'twk-1',
        prompt: 'Dasar negara Indonesia adalah...',
        options: <String>[
          'UUD 1945',
          'Pancasila',
          'Bhinneka Tunggal Ika',
          'NKRI',
        ],
        correctOptionIndex: 1,
        weight: 1,
        effect: QuestionEffect.damage,
      ),
      BattleQuestion(
        id: 'tiu-1',
        prompt: 'Jika 6 x 7 = ?',
        options: <String>['40', '42', '48', '36'],
        correctOptionIndex: 1,
        weight: 2,
        effect: QuestionEffect.damage,
      ),
      BattleQuestion(
        id: 'tkp-1',
        prompt: 'Saat rekan kerja kesulitan, tindakan terbaik adalah...',
        options: <String>[
          'Membiarkan sendiri',
          'Menegur keras',
          'Membantu sesuai kapasitas',
          'Melaporkan tanpa diskusi',
        ],
        correctOptionIndex: 2,
        weight: 1,
        effect: QuestionEffect.heal,
      ),
      BattleQuestion(
        id: 'tiu-2',
        prompt: 'Deret 2, 4, 8, 16, ...',
        options: <String>['18', '20', '24', '32'],
        correctOptionIndex: 3,
        weight: 3,
        effect: QuestionEffect.damage,
      ),
      BattleQuestion(
        id: 'twk-2',
        prompt: 'Semboyan Bhinneka Tunggal Ika bermakna...',
        options: <String>[
          'Berbeda-beda tetap satu',
          'Satu bangsa satu budaya',
          'Persatuan dengan paksaan',
          'Kesamaan pendapat',
        ],
        correctOptionIndex: 0,
        weight: 2,
        effect: QuestionEffect.heal,
      ),
    ];
  }
}
