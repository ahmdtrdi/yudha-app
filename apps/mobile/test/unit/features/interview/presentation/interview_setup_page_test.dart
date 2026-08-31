import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_company_option.dart';

void main() {
  test('company catalog options support nullable backend role suggestions', () {
    const InterviewCompanyOption withoutRole = InterviewCompanyOption(
      id: 'injourney',
      name: 'PT Aviasi Pariwisata Indonesia (Persero)',
    );
    const InterviewCompanyOption withRole = InterviewCompanyOption(
      id: 'bank-mandiri',
      name: 'PT Bank Mandiri (Persero) Tbk',
      defaultRole: 'Officer Development Program',
    );

    expect(withoutRole.defaultRole, isNull);
    expect(withRole.defaultRole, 'Officer Development Program');
  });
}
