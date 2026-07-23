import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/interview/presentation/pages/interview_setup_page.dart';

void main() {
  test('company picker only exposes reviewed backend company profiles', () {
    final Set<String> ids = kInterviewCompanies
        .map((InterviewCompanyOption company) => company.id)
        .toSet();

    expect(ids, <String>{
      'adhi-karya',
      'bank-indonesia',
      'bank-mandiri',
      'garuda-indonesia',
      'kementerian-keuangan',
      'pertamina',
    });
    expect(
      kInterviewCompanies.every(
        (InterviewCompanyOption company) =>
            company.name.trim().isNotEmpty &&
            company.defaultRole.trim().isNotEmpty,
      ),
      isTrue,
    );
  });
}
