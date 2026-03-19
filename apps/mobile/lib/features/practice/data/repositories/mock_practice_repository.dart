import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

class MockPracticeRepository implements PracticeRepository {
  const MockPracticeRepository();

  static const List<PracticeTopic> _topics = <PracticeTopic>[
    PracticeTopic(
      id: 'math',
      name: 'Math',
      description: 'Numerical reasoning and quick calculations.',
    ),
    PracticeTopic(
      id: 'science',
      name: 'Science',
      description: 'Core concepts from physics, chemistry, and biology.',
    ),
    PracticeTopic(
      id: 'logic',
      name: 'Logic',
      description: 'Pattern recognition and analytical reasoning.',
    ),
    PracticeTopic(
      id: 'general',
      name: 'General',
      description: 'Mixed aptitude for interview prep.',
    ),
  ];

  static const List<PracticeQuestion> _questions = <PracticeQuestion>[
    PracticeQuestion(
      id: 'q_math_1',
      topicId: 'math',
      topicName: 'Math',
      prompt: 'If x + 5 = 17, what is x?',
      hint: 'Isolate the variable by moving 5 to the other side.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '10', isCorrect: false),
        PracticeOption(id: 'b', label: '11', isCorrect: false),
        PracticeOption(id: 'c', label: '12', isCorrect: true),
        PracticeOption(id: 'd', label: '13', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_math_2',
      topicId: 'math',
      topicName: 'Math',
      prompt: 'What is 15% of 200?',
      hint: '10% of 200 is 20, and 5% is half of that.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '25', isCorrect: false),
        PracticeOption(id: 'b', label: '30', isCorrect: true),
        PracticeOption(id: 'c', label: '35', isCorrect: false),
        PracticeOption(id: 'd', label: '40', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_math_3',
      topicId: 'math',
      topicName: 'Math',
      prompt: 'A train travels 120 km in 2 hours. Its average speed is?',
      hint: 'Average speed is distance divided by time.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '50 km/h', isCorrect: false),
        PracticeOption(id: 'b', label: '60 km/h', isCorrect: true),
        PracticeOption(id: 'c', label: '70 km/h', isCorrect: false),
        PracticeOption(id: 'd', label: '80 km/h', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_science_1',
      topicId: 'science',
      topicName: 'Science',
      prompt: 'Which part of the cell contains genetic material?',
      hint: 'Think about where DNA is stored in eukaryotic cells.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'Nucleus', isCorrect: true),
        PracticeOption(id: 'b', label: 'Ribosome', isCorrect: false),
        PracticeOption(id: 'c', label: 'Membrane', isCorrect: false),
        PracticeOption(id: 'd', label: 'Cytoplasm', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_science_2',
      topicId: 'science',
      topicName: 'Science',
      prompt: 'What force keeps planets in orbit around the sun?',
      hint: 'It is one of the four fundamental interactions.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'Magnetism', isCorrect: false),
        PracticeOption(id: 'b', label: 'Gravity', isCorrect: true),
        PracticeOption(id: 'c', label: 'Friction', isCorrect: false),
        PracticeOption(id: 'd', label: 'Tension', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_science_3',
      topicId: 'science',
      topicName: 'Science',
      prompt: 'Water boils at what temperature at sea level?',
      hint: 'Use Celsius as the reference.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '90 C', isCorrect: false),
        PracticeOption(id: 'b', label: '95 C', isCorrect: false),
        PracticeOption(id: 'c', label: '100 C', isCorrect: true),
        PracticeOption(id: 'd', label: '110 C', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_logic_1',
      topicId: 'logic',
      topicName: 'Logic',
      prompt: 'Which number should come next: 2, 4, 8, 16, ...?',
      hint: 'Each number is multiplied by the same value.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '18', isCorrect: false),
        PracticeOption(id: 'b', label: '24', isCorrect: false),
        PracticeOption(id: 'c', label: '32', isCorrect: true),
        PracticeOption(id: 'd', label: '36', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_logic_2',
      topicId: 'logic',
      topicName: 'Logic',
      prompt: 'All A are B. Some B are C. Which statement is always true?',
      hint: 'Be careful: "some" does not imply "all."',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'All A are C', isCorrect: false),
        PracticeOption(id: 'b', label: 'Some A may be C', isCorrect: true),
        PracticeOption(id: 'c', label: 'No C are A', isCorrect: false),
        PracticeOption(id: 'd', label: 'All C are A', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_logic_3',
      topicId: 'logic',
      topicName: 'Logic',
      prompt: 'If today is Tuesday, what day is it 10 days later?',
      hint: 'Use modulo 7 for day cycles.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'Thursday', isCorrect: false),
        PracticeOption(id: 'b', label: 'Friday', isCorrect: true),
        PracticeOption(id: 'c', label: 'Saturday', isCorrect: false),
        PracticeOption(id: 'd', label: 'Sunday', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_general_1',
      topicId: 'general',
      topicName: 'General',
      prompt: 'Which communication style is best in structured interviews?',
      hint: 'Interviewers value clear structure and relevance.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'Vague but confident', isCorrect: false),
        PracticeOption(
          id: 'b',
          label: 'Concise and evidence-based',
          isCorrect: true,
        ),
        PracticeOption(id: 'c', label: 'Long and unfiltered', isCorrect: false),
        PracticeOption(id: 'd', label: 'Highly technical only', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_general_2',
      topicId: 'general',
      topicName: 'General',
      prompt: 'STAR method is commonly used to answer which type of question?',
      hint: 'It organizes responses to behavior-based prompts.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'Behavioral questions', isCorrect: true),
        PracticeOption(id: 'b', label: 'Salary negotiation only', isCorrect: false),
        PracticeOption(id: 'c', label: 'Company history only', isCorrect: false),
        PracticeOption(id: 'd', label: 'Coding syntax only', isCorrect: false),
      ],
    ),
    PracticeQuestion(
      id: 'q_general_3',
      topicId: 'general',
      topicName: 'General',
      prompt: 'What is a strong closing move at interview end?',
      hint: 'Summarize fit and ask a thoughtful next-step question.',
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: 'Leave without questions', isCorrect: false),
        PracticeOption(id: 'b', label: 'Ask about office snacks only', isCorrect: false),
        PracticeOption(
          id: 'c',
          label: 'Reinforce fit and ask about next steps',
          isCorrect: true,
        ),
        PracticeOption(id: 'd', label: 'Negotiate salary immediately', isCorrect: false),
      ],
    ),
  ];

  @override
  Future<List<PracticeTopic>> fetchTopics() async {
    return _topics;
  }

  @override
  Future<List<PracticeQuestion>> fetchQuestions({required String topicId}) async {
    return _questions
        .where((PracticeQuestion question) => question.topicId == topicId)
        .toList(growable: false);
  }

  @override
  Future<PracticeQuestion> fetchQuestionOfDay() async {
    return const PracticeQuestion(
      id: 'q_qod_1',
      topicId: 'logic',
      topicName: 'Logic',
      prompt: 'Question of the Day: Which comes next in 3, 6, 12, 24, ...?',
      hint: 'Look for a multiplicative sequence.',
      isQuestionOfDay: true,
      options: <PracticeOption>[
        PracticeOption(id: 'a', label: '30', isCorrect: false),
        PracticeOption(id: 'b', label: '36', isCorrect: false),
        PracticeOption(id: 'c', label: '48', isCorrect: true),
        PracticeOption(id: 'd', label: '54', isCorrect: false),
      ],
    );
  }
}

