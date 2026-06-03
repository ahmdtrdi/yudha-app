import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class MockPracticeRepository implements PracticeRepository {
  const MockPracticeRepository();

  static const Map<ProfileTarget, List<PracticeTopic>> _topicsByTarget =
      <ProfileTarget, List<PracticeTopic>>{
        ProfileTarget.cpns: <PracticeTopic>[
          PracticeTopic(
            id: 'twk_pancasila',
            name: 'Pancasila',
            description: 'Nilai dasar, sejarah, dan implementasi.',
            groupTitle: 'TWK - WAWASAN KEBANGSAAN',
            badgeLabel: 'TWK',
            questionCount: 30,
          ),
          PracticeTopic(
            id: 'twk_uud',
            name: 'UUD 1945',
            description: 'Pasal, amandemen, dan struktur konstitusi.',
            groupTitle: 'TWK - WAWASAN KEBANGSAAN',
            badgeLabel: 'TWK',
            questionCount: 25,
          ),
          PracticeTopic(
            id: 'tiu_verbal',
            name: 'Verbal',
            description: 'Analogi, sinonim, dan logika bahasa.',
            groupTitle: 'TIU - INTELEGENSIA UMUM',
            badgeLabel: 'TIU',
            questionCount: 40,
          ),
          PracticeTopic(
            id: 'tiu_numerik',
            name: 'Numerik',
            description: 'Aritmatika, deret, dan persentase.',
            groupTitle: 'TIU - INTELEGENSIA UMUM',
            badgeLabel: 'TIU',
            questionCount: 40,
          ),
          PracticeTopic(
            id: 'tkp_pelayanan',
            name: 'Pelayanan Publik',
            description: 'Etika, integritas, dan orientasi pelayanan.',
            groupTitle: 'TKP - KARAKTERISTIK PRIBADI',
            badgeLabel: 'TKP',
            questionCount: 35,
          ),
          PracticeTopic(
            id: 'tkp_profesionalisme',
            name: 'Profesionalisme',
            description: 'Disiplin, kolaborasi, dan tanggung jawab.',
            groupTitle: 'TKP - KARAKTERISTIK PRIBADI',
            badgeLabel: 'TKP',
            questionCount: 30,
          ),
        ],
        ProfileTarget.bumn: <PracticeTopic>[
          PracticeTopic(
            id: 'bumn_verbal',
            name: 'Verbal',
            description: 'Analogi, sinonim, dan pemahaman wacana.',
            groupTitle: 'SOAL KEMAMPUAN',
            badgeLabel: 'Verbal',
            questionCount: 30,
          ),
          PracticeTopic(
            id: 'bumn_numerik',
            name: 'Numerik',
            description: 'Dasar hitung, persentase, dan tabel.',
            groupTitle: 'SOAL KEMAMPUAN',
            badgeLabel: 'Numerik',
            questionCount: 25,
          ),
          PracticeTopic(
            id: 'bumn_logika',
            name: 'Logika',
            description: 'Pola pikir, penalaran, dan deduksi.',
            groupTitle: 'SOAL KEMAMPUAN',
            badgeLabel: 'Logika',
            questionCount: 30,
          ),
          PracticeTopic(
            id: 'bumn_kepribadian',
            name: 'Kepribadian',
            description: 'Nilai kerja, etika, dan budaya AKHLAK.',
            groupTitle: 'SOAL KEMAMPUAN',
            badgeLabel: 'Keprib.',
            questionCount: 20,
          ),
        ],
      };

  static const Map<String, List<PracticeQuestion>>
  _questionsByTopic = <String, List<PracticeQuestion>>{
    'twk_pancasila': <PracticeQuestion>[
      PracticeQuestion(
        id: 'twk_pancasila_1',
        topicId: 'twk_pancasila',
        topicName: 'Pancasila',
        prompt: 'Pancasila sebagai dasar negara tercantum dalam?',
        hint: 'Lihat bagian yang memuat nilai dasar negara secara eksplisit.',
        options: <PracticeOption>[
          PracticeOption(
            id: 'a',
            label: 'Batang Tubuh UUD 1945',
            isCorrect: false,
          ),
          PracticeOption(id: 'b', label: 'Pembukaan UUD 1945', isCorrect: true),
          PracticeOption(id: 'c', label: 'TAP MPR', isCorrect: false),
          PracticeOption(id: 'd', label: 'KUHP', isCorrect: false),
        ],
      ),
    ],
    'twk_uud': <PracticeQuestion>[
      PracticeQuestion(
        id: 'twk_uud_1',
        topicId: 'twk_uud',
        topicName: 'UUD 1945',
        prompt: 'Amandemen UUD 1945 dilakukan untuk?',
        hint: 'Fokus pada penyempurnaan sistem ketatanegaraan.',
        options: <PracticeOption>[
          PracticeOption(
            id: 'a',
            label: 'Menghapus lembaga negara',
            isCorrect: false,
          ),
          PracticeOption(
            id: 'b',
            label: 'Menyempurnakan konstitusi',
            isCorrect: true,
          ),
          PracticeOption(
            id: 'c',
            label: 'Mengganti dasar negara',
            isCorrect: false,
          ),
          PracticeOption(id: 'd', label: 'Membatasi pemilu', isCorrect: false),
        ],
      ),
    ],
    'tiu_verbal': <PracticeQuestion>[
      PracticeQuestion(
        id: 'tiu_verbal_1',
        topicId: 'tiu_verbal',
        topicName: 'Verbal',
        prompt: 'Sinonim kata "cermat" adalah?',
        hint: 'Cari makna yang paling dekat dengan teliti.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: 'Lalai', isCorrect: false),
          PracticeOption(id: 'b', label: 'Akurat', isCorrect: true),
          PracticeOption(id: 'c', label: 'Kasar', isCorrect: false),
          PracticeOption(id: 'd', label: 'Ragu', isCorrect: false),
        ],
      ),
    ],
    'tiu_numerik': <PracticeQuestion>[
      PracticeQuestion(
        id: 'tiu_numerik_1',
        topicId: 'tiu_numerik',
        topicName: 'Numerik',
        prompt: 'Jika 15% dari suatu nilai adalah 45, maka nilainya?',
        hint: 'Ubah 15% menjadi 0,15 lalu balik operasinya.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: '250', isCorrect: false),
          PracticeOption(id: 'b', label: '275', isCorrect: false),
          PracticeOption(id: 'c', label: '300', isCorrect: true),
          PracticeOption(id: 'd', label: '325', isCorrect: false),
        ],
      ),
    ],
    'tkp_pelayanan': <PracticeQuestion>[
      PracticeQuestion(
        id: 'tkp_pelayanan_1',
        topicId: 'tkp_pelayanan',
        topicName: 'Pelayanan Publik',
        prompt: 'Saat warga marah di loket, sikap paling tepat adalah?',
        hint: 'Utamakan empati dan solusi terukur.',
        options: <PracticeOption>[
          PracticeOption(
            id: 'a',
            label: 'Membalas dengan tegas',
            isCorrect: false,
          ),
          PracticeOption(
            id: 'b',
            label: 'Mendengarkan lalu memberi solusi',
            isCorrect: true,
          ),
          PracticeOption(
            id: 'c',
            label: 'Mengabaikan keluhan',
            isCorrect: false,
          ),
          PracticeOption(
            id: 'd',
            label: 'Meminta warga pergi',
            isCorrect: false,
          ),
        ],
      ),
    ],
    'tkp_profesionalisme': <PracticeQuestion>[
      PracticeQuestion(
        id: 'tkp_profesionalisme_1',
        topicId: 'tkp_profesionalisme',
        topicName: 'Profesionalisme',
        prompt: 'Rekan kerja terlambat menyerahkan tugas tim. Anda?',
        hint: 'Jaga hasil tim tanpa menjatuhkan rekan kerja.',
        options: <PracticeOption>[
          PracticeOption(
            id: 'a',
            label: 'Langsung lapor atasan',
            isCorrect: false,
          ),
          PracticeOption(
            id: 'b',
            label: 'Bantu klarifikasi dan selesaikan bersama',
            isCorrect: true,
          ),
          PracticeOption(id: 'c', label: 'Biarkan saja', isCorrect: false),
          PracticeOption(
            id: 'd',
            label: 'Kerjakan diam-diam tanpa kabar',
            isCorrect: false,
          ),
        ],
      ),
    ],
    'bumn_verbal': <PracticeQuestion>[
      PracticeQuestion(
        id: 'bumn_verbal_1',
        topicId: 'bumn_verbal',
        topicName: 'Verbal',
        prompt: 'Antonim kata "efisien" adalah?',
        hint: 'Cari lawan kata yang menunjukkan pemborosan.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: 'Produktif', isCorrect: false),
          PracticeOption(id: 'b', label: 'Efektif', isCorrect: false),
          PracticeOption(id: 'c', label: 'Boros', isCorrect: true),
          PracticeOption(id: 'd', label: 'Ringkas', isCorrect: false),
        ],
      ),
    ],
    'bumn_numerik': <PracticeQuestion>[
      PracticeQuestion(
        id: 'bumn_numerik_1',
        topicId: 'bumn_numerik',
        topicName: 'Numerik',
        prompt:
            'Sebuah target naik dari 120 menjadi 150. Persentase kenaikannya?',
        hint: 'Gunakan selisih dibanding nilai awal.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: '20%', isCorrect: false),
          PracticeOption(id: 'b', label: '25%', isCorrect: true),
          PracticeOption(id: 'c', label: '30%', isCorrect: false),
          PracticeOption(id: 'd', label: '35%', isCorrect: false),
        ],
      ),
    ],
    'bumn_logika': <PracticeQuestion>[
      PracticeQuestion(
        id: 'bumn_logika_1',
        topicId: 'bumn_logika',
        topicName: 'Logika',
        prompt: 'Deret berikut: 3, 6, 12, 24, ...',
        hint: 'Setiap angka memiliki faktor pengali yang sama.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: '30', isCorrect: false),
          PracticeOption(id: 'b', label: '36', isCorrect: false),
          PracticeOption(id: 'c', label: '42', isCorrect: false),
          PracticeOption(id: 'd', label: '48', isCorrect: true),
        ],
      ),
    ],
    'bumn_kepribadian': <PracticeQuestion>[
      PracticeQuestion(
        id: 'bumn_kepribadian_1',
        topicId: 'bumn_kepribadian',
        topicName: 'Kepribadian',
        prompt: 'Nilai AKHLAK yang paling terkait kolaborasi adalah?',
        hint: 'Pilih nilai yang menekankan kerja bersama.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: 'Amanah', isCorrect: false),
          PracticeOption(id: 'b', label: 'Kolaboratif', isCorrect: true),
          PracticeOption(id: 'c', label: 'Kompeten', isCorrect: false),
          PracticeOption(id: 'd', label: 'Loyal', isCorrect: false),
        ],
      ),
    ],
  };

  @override
  Future<PracticeDashboard> fetchDashboard({
    required ProfileTarget target,
  }) async {
    return PracticeDashboard(
      topics: _topicsByTarget[target] ?? const <PracticeTopic>[],
      questionOfDay: _questionOfDayFor(target),
      overallProgressPercent: target == ProfileTarget.cpns ? 28 : 52,
      recentActivities: _recentActivitiesFor(target),
    );
  }

  @override
  Future<List<PracticeQuestion>> fetchQuestions({
    required String topicId,
  }) async {
    return _questionsByTopic[topicId] ?? const <PracticeQuestion>[];
  }

  PracticeQuestion _questionOfDayFor(ProfileTarget target) {
    if (target == ProfileTarget.bumn) {
      return const PracticeQuestion(
        id: 'qod_bumn_1',
        topicId: 'bumn_logika',
        topicName: 'Logika',
        prompt: 'Tantangan harian: tentukan pola berikut 2, 4, 8, 16, ...',
        hint: 'Perhatikan pengali yang konsisten.',
        isQuestionOfDay: true,
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: '24', isCorrect: false),
          PracticeOption(id: 'b', label: '30', isCorrect: false),
          PracticeOption(id: 'c', label: '32', isCorrect: true),
          PracticeOption(id: 'd', label: '36', isCorrect: false),
        ],
      );
    }

    return const PracticeQuestion(
      id: 'qod_cpns_1',
      topicId: 'tiu_numerik',
      topicName: 'Numerik',
      prompt: 'Tantangan harian: 25% dari 360 adalah?',
      hint: 'Seperempat dari 360.',
      isQuestionOfDay: true,
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '80', isCorrect: false),
        PracticeOption(id: 'b', label: '90', isCorrect: true),
        PracticeOption(id: 'c', label: '95', isCorrect: false),
        PracticeOption(id: 'd', label: '100', isCorrect: false),
      ],
    );
  }

  List<PracticeRecentActivity> _recentActivitiesFor(ProfileTarget target) {
    if (target == ProfileTarget.bumn) {
      return const <PracticeRecentActivity>[
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'Verbal - Analogi',
          subtitle: '15 soal - 2 hari lalu',
          scoreLabel: '80%',
        ),
        PracticeRecentActivity(
          type: PracticeRecentActivityType.interview,
          title: 'Interview - Motivasi',
          subtitle: '5 pertanyaan - 2 hari lalu',
          scoreLabel: 'Selesai',
        ),
      ];
    }

    return const <PracticeRecentActivity>[
      PracticeRecentActivity(
        type: PracticeRecentActivityType.quiz,
        title: 'TWK - Pancasila',
        subtitle: '15 soal - 2 hari lalu',
        scoreLabel: '80%',
      ),
      PracticeRecentActivity(
        type: PracticeRecentActivityType.insight,
        title: 'TIU - Numerik',
        subtitle: '20 soal - 3 hari lalu',
        scoreLabel: '65%',
      ),
    ];
  }
}
