import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

enum InterviewState {
  ready,
  recording,
  processing,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String time;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class InterviewPage extends StatefulWidget {
  const InterviewPage({super.key});

  @override
  State<InterviewPage> createState() => _InterviewPageState();
}

class _InterviewPageState extends State<InterviewPage> {
  InterviewState _currentState = InterviewState.ready;
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      text:
          'Selamat datang! Pertama, ceritakan sedikit tentang dirimu dan motivasi melamar BUMN.',
      isUser: false,
      time: '07:42',
    ),
    const ChatMessage(
      text:
          'Saya Yudha, lulusan Teknik Informatika. Tertarik BUMN karena ingin berkontribusi pada pelayanan publik secara nyata.',
      isUser: true,
      time: '07:43',
    ),
  ];

  final String _currentQuestion =
      'Ceritakan pengalaman kamu saat menghadapi konflik dengan rekan kerja. Bagaimana kamu menyelesaikannya?';

  final String _currentAnswerPreview =
      'Waktu itu saya pernah berbeda pendapat dengan rekan soal prioritas proyek... █';
  final String _currentAnswerFull =
      'Waktu itu saya pernah berbeda pendapat dengan rekan soal prioritas proyek. Saya memilih mengajak diskusi langsung, mendengarkan perspektifnya, lalu mencari solusi bersama yang adil untuk semua pihak.';

  void _startRecording() {
    setState(() {
      _currentState = InterviewState.recording;
    });
    _scrollToBottom();
  }

  void _stopAndSend() {
    setState(() {
      _currentState = InterviewState.processing;
    });
    _scrollToBottom();

    // Auto-reply mock
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: _currentAnswerFull,
            isUser: true,
            time: '07:48',
          ),
        );
        _messages.add(
          const ChatMessage(
            text:
                'Menarik. Lalu bagaimana kamu memastikan solusi tersebut bisa diterima oleh seluruh anggota tim proyek?',
            isUser: false,
            time: '07:49',
          ),
        );
        _currentState = InterviewState.ready;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.warriorNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: <Widget>[
            Text(
              'WAWANCARA',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'BUMN • Sesi 1',
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withAlpha(150)),
                  color: Colors.redAccent.withAlpha(20),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeroBox(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: 20, 
                ),
                itemCount: _messages.length +
                    (_currentState == InterviewState.recording ? 1 : 0) +
                    (_currentState == InterviewState.processing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final msg = _messages[index];
                    return _ChatBubble(
                        text: msg.text, isUser: msg.isUser, time: msg.time);
                  } else if (index == _messages.length &&
                      _currentState == InterviewState.recording) {
                    return _ChatBubble(
                      text: _currentAnswerPreview,
                      isUser: true,
                      time: '',
                    );
                  } else if (_currentState == InterviewState.processing) {
                    return const _ChatBubble(
                      text: '...',
                      isUser: false,
                      time: '',
                      isTyping: true,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            _buildBottomRecorderBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBox() {
    final bool isAnswered = _currentState == InterviewState.processing;
    // We visually transition the Hero Box based on the mock state for exactly what the UX prototype shows
    final String heroTitle = isAnswered ? 'JAWABAN KAMU' : 'PERTANYAAN SAAT INI';
    final String heroContent = isAnswered ? _currentAnswerFull : _currentQuestion;
    final Color innerBoxColor = isAnswered
        ? const Color(0xFF1E3A8A) // deep blue
        : const Color(0xFF2563EB); // royal blue (slightly lighter)

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warriorNavy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.levelUpTeal, width: 2),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppColors.levelUpTeal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Pewawancara AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentState == InterviewState.processing
                          ? 'Menilai jawaban...'
                          : 'HR Simulator - BUMN',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Pertanyaan 2 / 5',
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '01:24',
                    style: GoogleFonts.orbitron(
                      color: AppColors.fireGold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // Inner Box
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: innerBoxColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  heroTitle,
                  style: GoogleFonts.orbitron(
                    color: Colors.white.withAlpha(150),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  heroContent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRecorderBar() {
    Color indicatorColor;
    String indicatorLabel;
    Widget centerButton;
    Widget leftButton;
    Widget rightButton;
    String subtitle;

    switch (_currentState) {
      case InterviewState.ready:
        indicatorColor = AppColors.levelUpTeal;
        indicatorLabel = 'Siap merekam';
        subtitle = 'Tekan dan tahan untuk berbicara • Ketik jawaban';
        leftButton = _ActionBtn(icon: Icons.notes_rounded, onTap: () {});
        rightButton = _ActionBtn(icon: Icons.access_time_rounded, onTap: () {});
        centerButton = GestureDetector(
          onTap: _startRecording,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.fireGold.withAlpha(100), width: 3),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.fireGold.withAlpha(30),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.mic, color: AppColors.fireGold, size: 36),
          ),
        );
        break;
      case InterviewState.recording:
        indicatorColor = Colors.redAccent;
        indicatorLabel = 'Merekam...';
        subtitle = 'Ketuk untuk berhenti - jawaban akan dikirim otomatis';
        leftButton = _ActionBtn(icon: Icons.notes_rounded, onTap: () {});
        rightButton = _ActionBtn(
          icon: Icons.chevron_right_rounded,
          onTap: _stopAndSend,
          color: AppColors.warriorNavy,
        );
        centerButton = GestureDetector(
          onTap: _stopAndSend,
          child: Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withAlpha(10),
              border: Border.all(color: Colors.redAccent.withAlpha(100), width: 2),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent, width: 3),
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 32),
            ),
          ),
        );
        break;
      case InterviewState.processing:
        indicatorColor = AppColors.warriorNavy.withAlpha(150);
        indicatorLabel = 'Pewawancara sedang merespons';
        subtitle = 'Tunggu pewawancara selesai berbicara';
        leftButton =
            _ActionBtn(icon: Icons.notes_rounded, onTap: null, opacity: 0.3);
        rightButton = _ActionBtn(
            icon: Icons.chevron_right_rounded, onTap: null, opacity: 0.3);
        centerButton = Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.withAlpha(100), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.warriorNavy.withAlpha(150),
                  ),
                )
            ],
          ),
        );
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(20),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Indicator string
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_currentState == InterviewState.processing)
                ...List<Widget>.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: CircleAvatar(radius: 3, backgroundColor: indicatorColor),
                  ),
                )
              else
                CircleAvatar(radius: 4, backgroundColor: indicatorColor),
              const SizedBox(width: 8),
              Text(
                indicatorLabel,
                style: TextStyle(
                  color: indicatorColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          
          if (_currentState == InterviewState.recording) ...<Widget>[
             const SizedBox(height: 12),
             // Mock Waveform
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: List<Widget>.generate(12, (index) {
                  final double height = [12.0, 20.0, 14.0, 28.0, 18.0, 32.0, 16.0, 24.0, 12.0, 20.0, 10.0, 15.0][index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 4,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
               }),
             )
          ],

          const SizedBox(height: 16),

          // Main Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              leftButton,
              centerButton,
              rightButton,
            ],
          ),

          const SizedBox(height: 20),

          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textMuted.withAlpha(150),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    this.onTap,
    this.color = AppColors.textMuted,
    this.opacity = 1.0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withAlpha(50)),
            color: Colors.grey.withAlpha(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.time,
    this.isTyping = false,
  });

  final String text;
  final bool isUser;
  final String time;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            _AvatarIcon(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? AppColors.warriorNavy : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 20),
                ),
                boxShadow: <BoxShadow>[
                  if (!isUser)
                    BoxShadow(
                      color: AppColors.warriorNavy.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: <Widget>[
                  if (isTyping)
                     Text(
                      text,
                      style: const TextStyle(
                         color: AppColors.textMuted,
                         fontSize: 24,
                         letterSpacing: 2,
                         height: 0.5,
                      ),
                    )
                  else
                    Text(
                      text,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  if (time.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white.withAlpha(150)
                            : AppColors.textMuted.withAlpha(150),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          if (isUser) ...<Widget>[
            const SizedBox(width: 8),
            _AvatarIcon(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  const _AvatarIcon({required this.isUser});
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? AppColors.levelUpTeal.withAlpha(20) : Colors.grey.withAlpha(20),
        border: Border.all(
            color: isUser
                ? AppColors.levelUpTeal.withAlpha(100)
                : Colors.grey.withAlpha(100)),
      ),
      child: Icon(
        Icons.person_outline,
        size: 14,
        color: isUser ? AppColors.levelUpTeal : Colors.grey,
      ),
    );
  }
}
