import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class InterviewCompanyOption {
  const InterviewCompanyOption({
    required this.id,
    required this.name,
    required this.defaultRole,
    required this.targetGroup,
  });

  final String id;
  final String name;
  final String defaultRole;
  final ProfileTarget targetGroup;
}

const List<InterviewCompanyOption> kInterviewCompanies =
    <InterviewCompanyOption>[
      InterviewCompanyOption(
        id: 'adhi-karya',
        name: 'PT Adhi Karya (Persero) Tbk',
        defaultRole: 'Management Trainee',
        targetGroup: ProfileTarget.bumn,
      ),
      InterviewCompanyOption(
        id: 'bank-indonesia',
        name: 'Bank Indonesia',
        defaultRole: 'Asisten Manajer',
        targetGroup: ProfileTarget.bumn,
      ),
      InterviewCompanyOption(
        id: 'bank-mandiri',
        name: 'PT Bank Mandiri (Persero) Tbk',
        defaultRole: 'Officer Development Program',
        targetGroup: ProfileTarget.bumn,
      ),
      InterviewCompanyOption(
        id: 'garuda-indonesia',
        name: 'PT Garuda Indonesia (Persero) Tbk',
        defaultRole: 'Management Trainee',
        targetGroup: ProfileTarget.bumn,
      ),
      InterviewCompanyOption(
        id: 'pertamina',
        name: 'PT Pertamina (Persero)',
        defaultRole: 'Bimbingan Profesi Sarjana',
        targetGroup: ProfileTarget.bumn,
      ),
      InterviewCompanyOption(
        id: 'kementerian-keuangan',
        name: 'Kementerian Keuangan Republik Indonesia',
        defaultRole: 'Staf Pengelola Keuangan Negara',
        targetGroup: ProfileTarget.cpns,
      ),
    ];

class InterviewSetupPage extends ConsumerStatefulWidget {
  const InterviewSetupPage({super.key});

  @override
  ConsumerState<InterviewSetupPage> createState() => _InterviewSetupPageState();
}

class _InterviewSetupPageState extends ConsumerState<InterviewSetupPage> {
  late InterviewCompanyOption _selectedCompany;
  late TextEditingController _roleController;
  String _mode = 'coaching';
  String _responseStyle = 'text';

  @override
  void initState() {
    super.initState();
    final ProfileTarget userTarget =
        ref.read(profileSettingsProvider).target ?? ProfileTarget.bumn;
    final List<InterviewCompanyOption> matching = kInterviewCompanies
        .where((c) => c.targetGroup == userTarget)
        .toList();

    _selectedCompany = matching.isNotEmpty
        ? matching.first
        : kInterviewCompanies.first;
    _roleController = TextEditingController(text: _selectedCompany.defaultRole);
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  void _onCompanyChanged(InterviewCompanyOption newCompany) {
    setState(() {
      _selectedCompany = newCompany;
      _roleController.text = newCompany.defaultRole;
    });
  }

  void _startInterview() {
    final String role = _roleController.text.trim().isEmpty
        ? _selectedCompany.defaultRole
        : _roleController.text.trim();

    final InterviewLaunchConfig config = InterviewLaunchConfig(
      companyId: _selectedCompany.id,
      companyName: _selectedCompany.name,
      targetRole: role,
      mode: _mode,
      language: 'id',
      responseStyle: _responseStyle,
    );

    context.push(AppRoutes.interview, extra: config);
  }

  @override
  Widget build(BuildContext context) {
    final ProfileTarget userTarget =
        ref.watch(profileSettingsProvider).target ?? ProfileTarget.bumn;
    final List<InterviewCompanyOption> availableCompanies = kInterviewCompanies
        .where((c) => c.targetGroup == userTarget)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: AppColors.warriorNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SETUP INTERVIEW AI',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Section 1: Company & Role
              const _SectionTitle(title: 'TARGET INSTANSI & POSISI'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.warriorNavy.withAlpha(12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Pilih Instansi / Perusahaan',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<InterviewCompanyOption>(
                      initialValue:
                          availableCompanies.contains(_selectedCompany)
                          ? _selectedCompany
                          : availableCompanies.first,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.scholarCream,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: availableCompanies
                          .map(
                            (c) => DropdownMenuItem<InterviewCompanyOption>(
                              value: c,
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  color: AppColors.textStrong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _onCompanyChanged(val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Posisi / Role yang Dilamar',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roleController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.scholarCream,
                        hintText: 'Masukkan posisi target...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(
                        color: AppColors.textStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 2: Mode (Coaching vs Realistic)
              const _SectionTitle(title: 'MODE INTERVIEW'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SelectCard(
                      title: 'Coaching',
                      subtitle: 'Evaluasi instan tiap jawaban',
                      icon: Icons.school_outlined,
                      isSelected: _mode == 'coaching',
                      badgeText: 'REKOMENDASI',
                      onTap: () => setState(() => _mode = 'coaching'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SelectCard(
                      title: 'Realistik',
                      subtitle: 'Hasil & evaluasi di akhir sesi',
                      icon: Icons.timer_outlined,
                      isSelected: _mode == 'realistic',
                      onTap: () => setState(() => _mode = 'realistic'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section 3: Response Style (Text vs Voice)
              const _SectionTitle(title: 'CARA MENJAWAB'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SelectCard(
                      title: 'Teks',
                      subtitle: 'Ketik jawaban santai tanpa suara',
                      icon: Icons.keyboard_outlined,
                      isSelected: _responseStyle == 'text',
                      onTap: () => setState(() => _responseStyle = 'text'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SelectCard(
                      title: 'Suara',
                      subtitle: 'Rekam jawaban dan dengarkan pertanyaan',
                      icon: Icons.mic_none_outlined,
                      isSelected: _responseStyle == 'voice',
                      badgeText: 'BETA',
                      onTap: () => setState(() => _responseStyle = 'voice'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Start CTA
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startInterview,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warriorNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'MULAI INTERVIEW AI',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.orbitron(
        color: AppColors.warriorNavy,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.levelUpTeal
                  : AppColors.warriorNavy.withAlpha(20),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isSelected
                    ? AppColors.levelUpTeal.withAlpha(25)
                    : AppColors.warriorNavy.withAlpha(10),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    icon,
                    color: isSelected
                        ? AppColors.levelUpTeal
                        : AppColors.warriorNavy,
                    size: 22,
                  ),
                  const Spacer(),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.levelUpTeal.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: AppColors.levelUpTeal,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
