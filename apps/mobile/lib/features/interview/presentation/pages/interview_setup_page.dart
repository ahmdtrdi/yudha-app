import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/interview/application/interview_providers.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_company_option.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class InterviewSetupPage extends ConsumerStatefulWidget {
  const InterviewSetupPage({super.key});

  @override
  ConsumerState<InterviewSetupPage> createState() => _InterviewSetupPageState();
}

class _InterviewSetupPageState extends ConsumerState<InterviewSetupPage> {
  InterviewCompanyOption? _selectedCompany;
  late TextEditingController _roleController;
  String? _pendingCompanyId;
  String? _roleError;
  String _mode = 'coaching';
  String _responseStyle = 'text';

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController();
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  void _onCompanyChanged(InterviewCompanyOption newCompany) {
    setState(() {
      _selectedCompany = newCompany;
      _roleController.text = newCompany.defaultRole ?? '';
      _roleError = null;
    });
  }

  void _startInterview() {
    final InterviewCompanyOption? company = _selectedCompany;
    final String role = _roleController.text.trim();
    if (company == null) {
      return;
    }
    if (role.isEmpty) {
      setState(() => _roleError = 'Masukkan posisi yang dilamar.');
      return;
    }

    final InterviewLaunchConfig config = InterviewLaunchConfig(
      companyId: company.id,
      companyName: company.name,
      targetRole: role,
      mode: _mode,
      language: 'id',
      responseStyle: _responseStyle,
    );

    context.push(AppRoutes.interviewSession, extra: config);
  }

  void _resumeInterview(
    InterviewSessionSummaryRecord session,
    List<InterviewCompanyOption> companies,
  ) {
    InterviewCompanyOption? company;
    for (final InterviewCompanyOption item in companies) {
      if (item.id == session.companyId) {
        company = item;
        break;
      }
    }
    context.push(
      AppRoutes.interviewSession,
      extra: InterviewLaunchConfig(
        companyId: session.companyId,
        companyName: company?.name ?? _humanizeCompanyId(session.companyId),
        targetRole: session.targetRole,
        mode: session.mode,
        language: session.language,
        responseStyle: session.responseStyle,
        resumeSessionId: session.sessionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProfileTarget userTarget =
        ref.watch(profileSettingsProvider).target ?? ProfileTarget.bumn;
    final AsyncValue<List<InterviewCompanyOption>> companiesState = ref.watch(
      interviewCompaniesProvider,
    );
    final List<InterviewCompanyOption> availableCompanies =
        companiesState.asData?.value ?? const <InterviewCompanyOption>[];
    final InterviewCompanyOption? selectedCompany = _selectedCompanyFor(
      availableCompanies,
    );
    if (selectedCompany != null &&
        selectedCompany != _selectedCompany &&
        _pendingCompanyId != selectedCompany.id) {
      _pendingCompanyId = selectedCompany.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingCompanyId = null;
        if (mounted && selectedCompany != _selectedCompany) {
          _onCompanyChanged(selectedCompany);
        }
      });
    }
    final bool companyCatalogReady =
        companiesState.hasValue && availableCompanies.isNotEmpty;
    final List<InterviewSessionSummaryRecord> activeSessions =
        ref
            .watch(interviewSessionsProvider)
            .asData
            ?.value
            .where(
              (InterviewSessionSummaryRecord session) =>
                  session.status == 'active',
            )
            .take(3)
            .toList(growable: false) ??
        const <InterviewSessionSummaryRecord>[];

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: AppColors.warriorNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          key: const Key('interview-setup-back'),
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.lobby);
          },
        ),
        title: Text(
          'SETUP INTERVIEW AI',
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('interview-setup-scroll'),
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InterviewSetupHero(target: userTarget),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (activeSessions.isNotEmpty) ...<Widget>[
                      _ActiveSessionsPanel(
                        sessions: activeSessions,
                        companyNameFor: (String companyId) =>
                            _companyNameFor(companyId, availableCompanies),
                        onResume: (InterviewSessionSummaryRecord session) =>
                            _resumeInterview(session, availableCompanies),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _SetupPanel(
                      step: '01',
                      title: 'Target interview',
                      subtitle: 'Tentukan instansi dan posisi yang dituju.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _FieldLabel(label: 'Instansi / perusahaan'),
                          const SizedBox(height: 7),
                          _CompanyCatalogField(
                            state: companiesState,
                            companies: availableCompanies,
                            selectedCompany: selectedCompany,
                            onChanged: _onCompanyChanged,
                            onRetry: () =>
                                ref.invalidate(interviewCompaniesProvider),
                          ),
                          const SizedBox(height: 13),
                          const _FieldLabel(label: 'Posisi yang dilamar'),
                          const SizedBox(height: 7),
                          TextField(
                            key: const Key('interview-role-field'),
                            controller: _roleController,
                            enabled: companyCatalogReady,
                            onChanged: (_) {
                              if (_roleError != null) {
                                setState(() => _roleError = null);
                              }
                            },
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            decoration: _setupFieldDecoration(
                              icon: Icons.work_outline_rounded,
                              hint: 'Masukkan posisi target...',
                            ).copyWith(errorText: _roleError),
                            style: const TextStyle(
                              color: AppColors.textStrong,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SetupPanel(
                      step: '02',
                      title: 'Pilih mode',
                      subtitle: 'Atur kapan evaluasi diberikan.',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _SelectCard(
                              cardKey: const Key('interview-mode-coaching'),
                              title: 'Coaching',
                              subtitle: 'Evaluasi instan setiap jawaban.',
                              icon: Icons.school_outlined,
                              accent: AppColors.levelUpTeal,
                              selectedFill: const Color(0xFFE2F7F6),
                              selectedShadow: const Color(0xFF8CCFCB),
                              isSelected: _mode == 'coaching',
                              badgeText: 'REKOMENDASI',
                              onTap: () => setState(() => _mode = 'coaching'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SelectCard(
                              cardKey: const Key('interview-mode-realistic'),
                              title: 'Realistik',
                              subtitle: 'Evaluasi lengkap di akhir sesi.',
                              icon: Icons.timer_outlined,
                              accent: const Color(0xFF7559D4),
                              selectedFill: const Color(0xFFF0EBFF),
                              selectedShadow: const Color(0xFFB9A9E8),
                              isSelected: _mode == 'realistic',
                              onTap: () => setState(() => _mode = 'realistic'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SetupPanel(
                      step: '03',
                      title: 'Cara menjawab',
                      subtitle: 'Pilih cara yang paling nyaman untukmu.',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _SelectCard(
                              cardKey: const Key('interview-response-text'),
                              title: 'Teks',
                              subtitle: 'Ketik jawaban tanpa menggunakan mic.',
                              icon: Icons.keyboard_outlined,
                              accent: const Color(0xFF2878F0),
                              selectedFill: const Color(0xFFE7F0FF),
                              selectedShadow: const Color(0xFF9ABBEF),
                              isSelected: _responseStyle == 'text',
                              onTap: () =>
                                  setState(() => _responseStyle = 'text'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SelectCard(
                              cardKey: const Key('interview-response-voice'),
                              title: 'Suara',
                              subtitle:
                                  'Pertanyaan otomatis, tahan mic saat menjawab.',
                              icon: Icons.mic_none_outlined,
                              accent: const Color(0xFFE0922F),
                              selectedFill: const Color(0xFFFFEEDB),
                              selectedShadow: const Color(0xFFE9B578),
                              isSelected: _responseStyle == 'voice',
                              badgeText: 'LIVE',
                              onTap: () =>
                                  setState(() => _responseStyle = 'voice'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _InterviewStartButton(
                      onPressed: companyCatalogReady ? _startInterview : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InterviewCompanyOption? _selectedCompanyFor(
    List<InterviewCompanyOption> companies,
  ) {
    if (companies.isEmpty) {
      return null;
    }
    final String? selectedId = _selectedCompany?.id;
    for (final InterviewCompanyOption company in companies) {
      if (company.id == selectedId) {
        return company;
      }
    }
    return companies.first;
  }
}

String _companyNameFor(
  String companyId,
  List<InterviewCompanyOption> companies,
) {
  for (final InterviewCompanyOption company in companies) {
    if (company.id == companyId) {
      return company.name;
    }
  }
  return _humanizeCompanyId(companyId);
}

String _humanizeCompanyId(String companyId) {
  return companyId
      .trim()
      .split(RegExp(r'[-_]'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _humanizeMode(String mode) {
  return mode.toLowerCase() == 'realistic' ? 'Realistik' : 'Coaching';
}

InputDecoration _setupFieldDecoration({required IconData icon, String? hint}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.warriorNavy, size: 19),
    filled: true,
    fillColor: const Color(0xFFF7F8FA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFE1E4E9)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.warriorNavy, width: 1.5),
    ),
  );
}

class _InterviewSetupHero extends StatelessWidget {
  const _InterviewSetupHero({required this.target});

  final ProfileTarget target;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('interview-setup-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.warriorNavy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xFF00266F),
            blurRadius: 0,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF0B55C8),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF5D98F4), width: 2),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(48)),
                  ),
                  child: Text(
                    'PERSIAPAN ${target.label}',
                    style: const TextStyle(
                      color: Color(0xFFFFC477),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Bangun sesi interviewmu',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Atur target, gaya sesi, dan cara menjawab.',
                  style: TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionsPanel extends StatelessWidget {
  const _ActiveSessionsPanel({
    required this.sessions,
    required this.companyNameFor,
    required this.onResume,
  });

  final List<InterviewSessionSummaryRecord> sessions;
  final String Function(String companyId) companyNameFor;
  final ValueChanged<InterviewSessionSummaryRecord> onResume;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.history_rounded, color: AppColors.warriorNavy, size: 17),
            SizedBox(width: 7),
            Text(
              'LANJUTKAN SESI',
              style: TextStyle(
                color: AppColors.warriorNavy,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD9E7FA)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0xFFB8C9DD),
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              for (int index = 0; index < sessions.length; index++) ...<Widget>[
                InkWell(
                  key: Key('resume-interview-${sessions[index].sessionId}'),
                  onTap: () => onResume(sessions[index]),
                  borderRadius: BorderRadius.circular(19),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2F7F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.levelUpTeal,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                companyNameFor(sessions[index].companyId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textStrong,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${sessions[index].targetRole} • ${_humanizeMode(sessions[index].mode)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.warriorNavy,
                          size: 21,
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < sessions.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, color: Color(0xFFE8EAEF)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(14)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFFD7DAE0),
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4EEFF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: AppColors.warriorNavy,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CompanyCatalogField extends StatelessWidget {
  const _CompanyCatalogField({
    required this.state,
    required this.companies,
    required this.selectedCompany,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<List<InterviewCompanyOption>> state;
  final List<InterviewCompanyOption> companies;
  final InterviewCompanyOption? selectedCompany;
  final ValueChanged<InterviewCompanyOption> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (_) {
        if (companies.isEmpty) {
          return _CompanyCatalogStatus(
            statusKey: const Key('interview-company-empty'),
            icon: Icons.apartment_rounded,
            message: 'Belum ada perusahaan interview tersedia.',
            onRetry: onRetry,
          );
        }
        return DropdownButtonFormField<InterviewCompanyOption>(
          key: const Key('interview-company-field'),
          initialValue: selectedCompany,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          decoration: _setupFieldDecoration(icon: Icons.apartment_rounded),
          items: companies
              .map(
                (InterviewCompanyOption company) =>
                    DropdownMenuItem<InterviewCompanyOption>(
                      value: company,
                      child: Text(
                        company.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textStrong,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
              )
              .toList(growable: false),
          onChanged: (InterviewCompanyOption? company) {
            if (company != null) {
              onChanged(company);
            }
          },
        );
      },
      loading: () => const _CompanyCatalogStatus(
        statusKey: Key('interview-company-loading'),
        message: 'Memuat daftar perusahaan...',
        showProgress: true,
      ),
      error: (_, _) => _CompanyCatalogStatus(
        statusKey: const Key('interview-company-error'),
        icon: Icons.error_outline_rounded,
        message: 'Daftar perusahaan gagal dimuat.',
        onRetry: onRetry,
      ),
    );
  }
}

class _CompanyCatalogStatus extends StatelessWidget {
  const _CompanyCatalogStatus({
    required this.statusKey,
    required this.message,
    this.icon,
    this.showProgress = false,
    this.onRetry,
  });

  final Key statusKey;
  final String message;
  final IconData? icon;
  final bool showProgress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: statusKey,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE1E4E9)),
      ),
      child: Row(
        children: <Widget>[
          if (showProgress)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: AppColors.warriorNavy, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: const Key('interview-company-retry'),
              onPressed: onRetry,
              child: const Text('Coba lagi'),
            ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.cardKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selectedFill,
    required this.selectedShadow,
    required this.isSelected,
    required this.onTap,
    this.badgeText,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color selectedFill;
  final Color selectedShadow;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? selectedShadow : const Color(0xFFD7DAE0),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 6,
            child: Material(
              color: isSelected ? selectedFill : Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: cardKey,
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? accent : const Color(0xFFE1E4E9),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accent.withAlpha(isSelected ? 34 : 18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: accent, size: 18),
                          ),
                          const Spacer(),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(24),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterviewStartButton extends StatelessWidget {
  const _InterviewStartButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFF0A35F)
                    : const Color(0xFFC5C8CE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 8,
            child: Material(
              color: enabled
                  ? const Color(0xFFFFD7A3)
                  : const Color(0xFFE2E4E8),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('start-interview-button'),
                onTap: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: enabled
                          ? const Color(0xFFC66B24)
                          : const Color(0xFF8D929B),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'MULAI INTERVIEW AI',
                      style: GoogleFonts.dmSans(
                        color: enabled
                            ? const Color(0xFFC66B24)
                            : const Color(0xFF8D929B),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
