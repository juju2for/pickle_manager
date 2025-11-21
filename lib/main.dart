import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

// 게임의 특정 시점 상태를 저장하는 클래스
class _GameState {
  final int scoreA;
  final int scoreB;
  final int serverSequence;
  final String servingTeam;

  _GameState({
    required this.scoreA,
    required this.scoreB,
    required this.serverSequence,
    required this.servingTeam,
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // 전체 화면 모드를 버튼으로 제어하기 위해 주석 처리
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const PickleballApp());
  });
}

class PickleballApp extends StatelessWidget {
  const PickleballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pickleball Scoreboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const ScoreBoardPage(),
    );
  }
}

class ScoreBoardPage extends StatefulWidget {
  const ScoreBoardPage({super.key});

  @override
  State<ScoreBoardPage> createState() => _ScoreBoardPageState();
}

class _ScoreBoardPageState extends State<ScoreBoardPage> {
  // === [TTS] TTS 관련 변수 및 메서드 ===
  final FlutterTts flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initTts();
    // 앱 시작 시 초기 점수 안내
    Future.delayed(const Duration(milliseconds: 500), _speakScore);
  }

  @override
  void dispose() {
    flutterTts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    await flutterTts.awaitSpeakCompletion(true);
  }

  void _playSoundEffect() {
    if (!_isAutoChangeSoundEnabled) return;
    _audioPlayer.play(AssetSource('sounds/sideout.mp3'));
  }

  bool _isVoiceEnabled = true; // 음성 안내 기능 활성화 여부
  bool _isAutoChangeSoundEnabled = true; // 사이드아웃 효과음 활성화 여부
  String textToSpeak = '';

  void _speakScore({bool force = false}) async {
    if (!_isVoiceEnabled && !force) return;

    String textToSpeak;
    final String servingScore = (servingTeam == 'A') ? scoreA.toString() : scoreB.toString();
    final String receivingScore = (servingTeam == 'A') ? scoreB.toString() : scoreA.toString();
    final String serverSequenceNumber = serverSequence.toString();

    const numberWords = {
      '0': 'Zero', '1': 'One', '2': 'Two', '3': 'Three', '4': 'Four',
      '5': 'Five', '6': 'Six', '7': 'Seven', '8': 'Eight', '9': 'Nine',
      '10': 'Ten', '11': 'Eleven', '12': 'Twelve', '13': 'Thirteen', '14': 'Fourteen',
      '15': 'Fifteen', '16': 'Sixteen', '17': 'Seventeen', '18': 'Eighteen', '19': 'Nineteen', '20': 'Twenty', '21': 'Twenty-one'
    };

    if (force) {
      // 강제 호출 시에는 숫자로 변환하여 말함 (e.g., "Zero Zero One")
      final String servingScoreWord = numberWords[servingScore] ?? servingScore;
      final String receivingScoreWord = numberWords[receivingScore] ?? receivingScore;
      final String serverSequenceWord = numberWords[serverSequenceNumber] ?? serverSequenceNumber;
      textToSpeak = '$servingScoreWord $receivingScoreWord $serverSequenceWord';
    } else {
      // 일반 호출 시에는 단어로 변환하여 말함
      final String servingScoreWord = numberWords[servingScore] ?? servingScore;
      final String receivingScoreWord = numberWords[receivingScore] ?? receivingScore;
      final String serverSequenceWord = serverSequence == 1 ? 'One' : 'Two';
      textToSpeak = '$servingScoreWord $receivingScoreWord $serverSequenceWord';
    }

    await flutterTts.speak(textToSpeak);
  }

  // === [Settings] 설정 변수들 (변경 가능) ===
  String teamAName = 'Team A';
  String teamBName = 'Team B';
  int targetScore = 11; // 기본 11점
  double fontScale = 1.5; // 글자 크기 배율 (기본값 상향)
  int totalSets = 1; // 총 세트 수

  // === [State] 게임 상태 변수들 ===
  int scoreA = 0;
  int scoreB = 0;
  int serverSequence = 2;
  String servingTeam = 'A';
  List<List<_GameState>> _history = [[]]; // 세트별 게임 상태 기록

  // === [State] 세트 상태 변수들 ===
  int currentSet = 1;
  int winsA = 0;
  int winsB = 0;
  List<String> setScores = []; // 각 세트별 점수 기록

  // === [Logic] 득점 처리 ===
  void _pointWinner(String winnerTeam) {
    // 상태 변경 전, 현재 상태를 히스토리에 저장
    _history[currentSet - 1].add(_GameState(
      scoreA: scoreA,
      scoreB: scoreB,
      serverSequence: serverSequence,
      servingTeam: servingTeam,
    ));

    // 리시브 팀이 이겼을 때 -> 사이드 아웃 처리 후 함수 종료
    if (winnerTeam != servingTeam) {
      _handleSideOut();
      return;
    }

    // === 아래는 서브권 팀이 이겼을 경우 (득점) ===
    _playSoundEffect();

    bool isSetOver = false;
    setState(() {
      if (servingTeam == 'A') {
        scoreA++;
      } else {
        scoreB++;
      }

      // 승리 조건 체크
      int diff = (scoreA - scoreB).abs();
      if ((scoreA >= targetScore || scoreB >= targetScore) && diff >= 2) {
        isSetOver = true;
        String winner = scoreA > scoreB ? 'A' : 'B';
        if (winner == 'A') {
          winsA++;
        } else {
          winsB++;
        }
        setScores.add('$scoreA : $scoreB');
      }
    });

    // 후속 처리: UI가 업데이트된 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isSetOver) {
        String winner = scoreA > scoreB ? 'A' : 'B';
        bool isMatchOver = winsA > totalSets / 2 || winsB > totalSets / 2;
        _showSetEndDialog(winner, isMatchOver);
      } else {
        Future.delayed(const Duration(milliseconds: 500), _speakScore);
      }
    });
  }

  // === [Logic] 세트 종료 팝업 ===
  void _showSetEndDialog(String winner, bool isMatchOver) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥을 탭해도 닫히지 않음
      builder: (context) => AlertDialog(
        title: Text(isMatchOver ? '🎉 최종 승리! 🎉' : '세트 종료!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${winner == 'A' ? teamAName : teamBName} 승리!',
              style: TextStyle(fontSize: 24 * fontScale, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '세트 스코어 $scoreA : $scoreB',
              style: TextStyle(fontSize: 20 * fontScale),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: () {
              Navigator.pop(context);
              if (isMatchOver) {
                _resetGame(); // 새 게임 시작
              } else {
                _startNextSet(); // 다음 세트 시작
              }
            },
            child: Text(isMatchOver ? '새 게임 시작' : '다음 세트', style: TextStyle(fontSize: 18 * fontScale)),
          )
        ],
      ),
    );
  }

  // === [Logic] 다음 세트 시작 ===
  void _startNextSet() {
    setState(() {
      currentSet++;
      scoreA = 0;
      scoreB = 0;
      serverSequence = 2;
      servingTeam = 'A'; // 다음 세트 첫 서브는 A팀부터 (규칙에 따라 변경 가능)
      _history.add([]); // 새 세트를 위한 히스토리 리스트 추가
    });
    _speakScore();
  }


  // === [Logic] 사이드 아웃 ===
  // 서브권이 상대팀으로 넘어가거나, 같은 팀의 두 번째 서버로 변경됩니다.
  // 이 로직 후에는 _speakScore()가 호출되어 점수를 안내해야 합니다.
  void _handleSideOut() {
    setState(() {
      if (serverSequence == 1) {
        serverSequence = 2;
      } else {
        serverSequence = 1;
        servingTeam = (servingTeam == 'A') ? 'B' : 'A';
        // Plays sideout.mp3 only when servingTeam changes
        _playSoundEffect(); // Always play sound when servingTeam changes
        if (_isAutoChangeSoundEnabled) {
          flutterTts.speak('Sideout');
        }
      }
    });
    // 사이드아웃 음성 안내 후 점수 안내를 위해 딜레이 추가
    if (_isVoiceEnabled) {
      Future.delayed(const Duration(seconds: 1), _speakScore);
    }
  }

  // === [Logic] 마지막 행동 되돌리기 ===
  void _undoLastAction() {
    if (_history.isNotEmpty && _history[currentSet - 1].isNotEmpty) {
      setState(() {
        final lastState = _history[currentSet - 1].removeLast();
        scoreA = lastState.scoreA;
        scoreB = lastState.scoreB;
        serverSequence = lastState.serverSequence;
        servingTeam = lastState.servingTeam;
      });
      _speakScore();
    }
  }

  // === [Logic] 게임 리셋 ===
  void _resetGame() {
    setState(() {
      scoreA = 0;
      scoreB = 0;
      serverSequence = 2;
      servingTeam = 'A';
      _history = [[]]; // 히스토리 초기화

      currentSet = 1;
      winsA = 0;
      winsB = 0;
      setScores.clear();
    });
    _speakScore();
  }

  // === [Logic] 점수 직접 정정 ===
  void _undoScore(String team) {
    setState(() {
      if (team == 'A' && scoreA > 0) {
        scoreA--;
      } else if (team == 'B' && scoreB > 0) {
        scoreB--;
      }
    });
    _speakScore();
  }

  // === [UI] 현재 세트 기록 팝업 (개선된 버전) ===
  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('경기 기록', style: TextStyle(fontSize: 22 * fontScale)),
        content: _buildScoreHistoryTable(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기', style: TextStyle(fontSize: 16 * fontScale)),
          )
        ],
      ),
    );
  }

  // === [UI] 경기 기록 테이블 위젯 ===
  Widget _buildScoreHistoryTable() {
    final currentSetHistory = _history[currentSet - 1];
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.8, // 팝업 너비 확장
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('지난 세트 결과', style: TextStyle(fontSize: 18 * fontScale, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey.shade400),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: [
                    _buildTableCell('세트', isHeader: true),
                    _buildTableCell(teamAName, isHeader: true),
                    _buildTableCell(teamBName, isHeader: true),
                  ],
                ),
                ...List.generate(setScores.length, (index) {
                  final scores = setScores[index].split(':');
                  return TableRow(
                    children: [
                      _buildTableCell('${index + 1}'),
                      _buildTableCell(scores[0].trim()),
                      _buildTableCell(scores[1].trim()),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),
            Text('$currentSet세트 진행 기록', style: TextStyle(fontSize: 18 * fontScale, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey.shade400),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: [
                    _buildTableCell(teamAName, isHeader: true),
                    _buildTableCell(teamBName, isHeader: true),
                    _buildTableCell('서브', isHeader: true),
                  ],
                ),
                ...List.generate(currentSetHistory.length, (index) {
                  final state = currentSetHistory[index];
                  return TableRow(
                    children: [
                      _buildTableCell('${state.scoreA}'),
                      _buildTableCell('${state.scoreB}'),
                      _buildTableCell('${state.servingTeam}(${state.serverSequence})'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15 * fontScale,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }


// === [UI] 새로운 설정 팝업 (수정됨) ===
  void _openSettingsDialog() {
    // 임시 변수: 사용자가 '새 게임'을 누르기 전까지의 설정값
    String tempTeamAName = teamAName;
    String tempTeamBName = teamBName;
    double tempFontScale = fontScale;
    int tempTotalSets = totalSets;
    int tempTargetScore = targetScore;
    final mediaQuery = MediaQuery.of(context);
    
    // 전체화면 여부 체크 로직 (웹에서는 브라우저 정책상 완벽하지 않을 수 있음)
    bool isFullScreen = false; 
    try {
         // 안전장치 추가
         isFullScreen = (mediaQuery.size.width == mediaQuery.size.width * mediaQuery.devicePixelRatio);
    } catch (e) {
        isFullScreen = false;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // --- 왼쪽/오른쪽 패널 내용은 그대로 유지 ---
            final Widget leftSide = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('전체화면'),
                  onTap: () {
                    setStateDialog(() {
                      isFullScreen = !isFullScreen;
                    });
                    if (isFullScreen) {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(_isVoiceEnabled ? Icons.volume_up : Icons.volume_off),
                  title: const Text('자동 카운터'),
                  onTap: () {
                    setStateDialog(() { // Use setStateDialog to update the dialog's UI
                      _isVoiceEnabled = !_isVoiceEnabled;
                    });
                  },
                ),
                ListTile(
                  leading: Icon(_isAutoChangeSoundEnabled ? Icons.volume_up : Icons.volume_off),
                  title: const Text('사이드아웃'),
                  onTap: () {
                    setStateDialog(() {
                      _isAutoChangeSoundEnabled = !_isAutoChangeSoundEnabled;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('경기기록'),
                  onTap: () {
                    Navigator.pop(context);
                    _showHistoryDialog();
                  },
                ),
              ],
            );

            final Widget rightSide = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    initialValue: tempTeamAName,
                    decoration: const InputDecoration(labelText: '팀 A 이름'),
                    onChanged: (value) => tempTeamAName = value,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    initialValue: tempTeamBName,
                    decoration: const InputDecoration(labelText: '팀 B 이름'),
                    onChanged: (value) => tempTeamBName = value,
                  ),
                ),
                const SizedBox(height: 20),
                // 글자 크기 슬라이더
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text('글자 크기:', style: TextStyle(fontSize: 16 * fontScale)),
                      Expanded(
                        child: Slider(
                          value: tempFontScale,
                          min: 0.5,
                          max: 2.5,
                          divisions: 20,
                          label: tempFontScale.toStringAsFixed(1),
                          onChanged: (value) {
                            setStateDialog(() {
                              tempFontScale = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 세트 설정 및 점수 설정
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text('세트 설정:', style: TextStyle(fontSize: 16 * fontScale)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: tempTotalSets,
                          items: [1, 3, 5, 7, 9].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value 세트', style: TextStyle(fontSize: 16 * fontScale)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setStateDialog(() {
                              tempTotalSets = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text('세트 점수:', style: TextStyle(fontSize: 16 * fontScale)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: tempTargetScore,
                          items: [7, 11, 21].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value 점', style: TextStyle(fontSize: 16 * fontScale)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setStateDialog(() {
                              tempTargetScore = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            return AlertDialog(
              title: Text('설정', style: TextStyle(fontSize: 22 * fontScale)),
              content: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    children: [
                      leftSide,
                      const Divider(height: 20),
                      rightSide,
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('닫기', style: TextStyle(fontSize: 16 * fontScale)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            teamAName = tempTeamAName;
                            teamBName = tempTeamBName;
                            fontScale = tempFontScale;
                            totalSets = tempTotalSets;
                            targetScore = tempTargetScore;
                          });
                          Navigator.pop(context);
                          _resetGame();
                        },
                        child: Text('새 게임', style: TextStyle(fontSize: 16 * fontScale)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 너비에 따라 중앙 패널 너비 동적 조절
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Row(
        children: [
          // --- [왼쪽: Team A] ---
          Expanded(
            child: _buildTeamArea(
              teamName: teamAName,
              score: scoreA,
              isServing: servingTeam == 'A',
              baseColor: Colors.blue,
              onTap: () => _pointWinner('A'),
              onUndo: () => _undoScore('A'),
            ),
          ),

          // --- [중앙: 정보 표시줄] ---
          Container(
            width: (screenWidth * 0.4).clamp(180.0, 300.0), // 너비 대폭 확장
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 간격 균등 배분
              children: [
                // [세트 스코어] - 한 줄로 변경
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$winsA', style: TextStyle(color: Colors.amber, fontSize: 32 * fontScale, fontWeight: FontWeight.bold)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('SET $currentSet', style: TextStyle(color: Colors.white, fontSize: 18 * fontScale, fontWeight: FontWeight.bold)),
                      ),
                      Text('$winsB', style: TextStyle(color: Colors.amber, fontSize: 32 * fontScale, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // [서버 순서] - 크게
                GestureDetector(
                  onTap: () => _speakScore(force: true),
                  onLongPress: () => flutterTts.speak('Sideout'),
                  child: Text(
                    '$serverSequence',
                    style: TextStyle(fontSize: 120 * fontScale, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0),
                  ),
                ),

                // [아이콘 버튼들]
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // [되돌리기 버튼]
                    IconButton(
                      icon: Icon(Icons.undo, color: Colors.white, size: 10 * fontScale),
                      onPressed: _undoLastAction,
                      tooltip: '실행취소',
                    ),

                    // [설정 버튼]
                    IconButton(
                      icon: Icon(Icons.settings, color: Colors.white, size: 25 * fontScale),
                      onPressed: _openSettingsDialog, // 새로운 설정 팝업 호출
                      tooltip: '설정',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- [오른쪽: Team B] ---
          Expanded(
            child: _buildTeamArea(
              teamName: teamBName,
              score: scoreB,
              isServing: servingTeam == 'B',
              baseColor: Colors.red,
              onTap: () => _pointWinner('B'),
              onUndo: () => _undoScore('B'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamArea({
    required String teamName,
    required int score,
    required bool isServing,
    required MaterialColor baseColor,
    required VoidCallback onTap,
    required VoidCallback onUndo,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onUndo, // 길게 눌러서 점수 정정
      child: Container(
        color: isServing ? baseColor.shade100 : baseColor.shade50.withAlpha(128),
        padding: const EdgeInsets.all(16.0), // 글자가 잘리지 않도록 패딩 추가
        child: FittedBox( // FittedBox를 사용하여 내용이 영역에 맞게 자동 스케일링되도록 함
          fit: BoxFit.contain, // 내용의 비율을 유지하면서 영역 안에 맞춤
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                teamName,
                style: TextStyle(
                  fontSize: 40 * fontScale, // 기본 폰트 크기를 크게 설정
                  fontWeight: FontWeight.bold,
                  color: isServing ? Colors.black87 : Colors.grey,
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 250 * fontScale, // 기본 폰트 크기를 매우 크게 설정
                  fontWeight: FontWeight.w900,
                  color: isServing ? baseColor.shade900 : Colors.grey.shade400,
                  height: 1.1,
                ),
              ),
              // 서브 표시 (개선)
              if (isServing)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'SERVE',
                    style: TextStyle(
                      fontSize: 45 * fontScale, // 기본 폰트 크기를 크게 설정
                      fontWeight: FontWeight.bold,
                      color: baseColor.shade700,
                      letterSpacing: 4,
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