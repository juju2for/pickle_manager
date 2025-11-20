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
    if (!_isVoiceEnabled) return;
    final player = AudioPlayer();
    player.play(AssetSource('sounds/sideout.mp3'));
  }

  bool _isVoiceEnabled = true; // 음성 안내 기능 활성화 여부

  void _speakScore() async {
    if (!_isVoiceEnabled) return; // 음성 안내가 꺼져있으면 실행하지 않음

    final String servingScore = (servingTeam == 'A') ? scoreA.toString() : scoreB.toString();
    final String receivingScore = (servingTeam == 'A') ? scoreB.toString() : scoreA.toString();

    // 점수를 영어 단어로 변환 (e.g., 0 -> "Zero")
    const numberWords = {
      '0': 'Zero', '1': 'One', '2': 'Two', '3': 'Three', '4': 'Four',
      '5': 'Five', '6': 'Six', '7': 'Seven', '8': 'Eight', '9': 'Nine',
      '10': 'Ten', '11': 'Eleven', '12': 'Twelve', '13': 'Thirteen', '14': 'Fourteen',
      '15': 'Fifteen', '16': 'Sixteen', '17': 'Seventeen', '18': 'Eighteen', '19': 'Nineteen', '20': 'Twenty', '21': 'Twenty-one'
    };

    final String servingScoreWord = numberWords[servingScore] ?? servingScore;
    final String receivingScoreWord = numberWords[receivingScore] ?? receivingScore;
    // 서버 순서는 1 또는 2이므로 간단히 처리
    final String serverSequenceWord = serverSequence == 1 ? 'One' : 'Two';

    final textToSpeak = '$servingScoreWord $receivingScoreWord $serverSequenceWord'; // 쉼표 제거
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
      }
    });
    _playSoundEffect();
    Future.delayed(const Duration(milliseconds: 500), _speakScore);
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


  // === [UI] 설정 팝업창 띄우기 ===
  void _openSettingsDialog() {
    // 현재 값을 컨트롤러에 담아 팝업에 전달
    TextEditingController nameACtrl = TextEditingController(text: teamAName);
    TextEditingController nameBCtrl = TextEditingController(text: teamBName);
    int tempTargetScore = targetScore;
    int tempTotalSets = totalSets; // 임시 총 세트
    double tempFontScale = fontScale; // 임시 글자 크기 배율

    showDialog(
      context: context,
      builder: (context) {
        // 팝업 내부에서 상태 변경(Dropdown 등)을 위해 StatefulBuilder 사용
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('게임 시작'),
              content: SingleChildScrollView( // 내용이 길어질 수 있으므로 스크롤 추가
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Team A 이름 입력
                    TextField(
                      controller: nameACtrl,
                      decoration: const InputDecoration(labelText: '왼쪽 팀 이름'),
                    ),
                    const SizedBox(height: 10),
                    // Team B 이름 입력
                    TextField(
                      controller: nameBCtrl,
                      decoration: const InputDecoration(labelText: '오른쪽 팀 이름'),
                    ),
                    const SizedBox(height: 20),
                    // 목표 점수 선택 (Dropdown)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('목표 점수:'),
                        DropdownButton<int>(
                          value: tempTargetScore,
                          items: [7, 11, 15, 21].map((score) {
                            return DropdownMenuItem(
                              value: score,
                              child: Text('$score점'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              // 팝업 내부 UI 갱신
                              setStateDialog(() {
                                tempTargetScore = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    // 총 세트 수 선택 (Dropdown)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('총 세트:'),
                        DropdownButton<int>(
                          value: tempTotalSets,
                          items: [1, 3, 5].map((sets) {
                            return DropdownMenuItem(
                              value: sets,
                              child: Text('$sets세트'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              // 팝업 내부 UI 갱신
                              setStateDialog(() {
                                tempTotalSets = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 글자 크기 조절 슬라이더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('글자 크기:'),
                        Text('${(tempFontScale * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                    Slider(
                      value: tempFontScale,
                      min: 0.5, // 50%
                      max: 3.0, // 300% (상향)
                      divisions: 25, // (3.0-0.5)*10
                      onChanged: (value) {
                        setStateDialog(() {
                          tempFontScale = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 메인 화면 상태 업데이트
                    setState(() {
                      teamAName = nameACtrl.text;
                      teamBName = nameBCtrl.text;
                      targetScore = tempTargetScore;
                      totalSets = tempTotalSets; // 총 세트 수 저장
                      fontScale = tempFontScale; // 글자 크기 배율 저장
                    });
                    _resetGame(); // 설정이 바뀌면 게임을 리셋
                    Navigator.pop(context);
                  },
                  child: const Text('저장 및 새 게임'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isFullScreen = false;

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 너비에 따라 중앙 패널 너비 동적 조절
    final screenWidth = MediaQuery.of(context).size.width;
    final centerPanelWidth = (screenWidth * 0.18).clamp(90.0, 150.0);

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
            width: centerPanelWidth,
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 8.0), // Add some vertical padding
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // [설정 버튼]
                  _buildCentralPanelButton(
                    icon: Icons.play_arrow,
                    label: '시작',
                    onPressed: _openSettingsDialog,
                  ),
                  const SizedBox(height: 16),
                  // [기록 버튼]
                  _buildCentralPanelButton(
                    icon: Icons.history,
                    label: '기록',
                    onPressed: _showHistoryDialog,
                  ),
                  const SizedBox(height: 24),
                  // [세트 스코어]
                  Column(
                    children: [
                      Text('$winsA', style: TextStyle(color: Colors.blue, fontSize: 28 * fontScale, fontWeight: FontWeight.bold)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('SET ${currentSet}', style: TextStyle(color: Colors.white, fontSize: 14 * fontScale, fontWeight: FontWeight.bold)),
                      ),
                      Text('$winsB', style: TextStyle(color: Colors.red, fontSize: 28 * fontScale, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // [서버 순서]
                  Column(
                    children: [
                      Text('SERVER', style: TextStyle(color: Colors.grey, fontSize: 12 * fontScale)),
                      const SizedBox(height: 5),
                      CircleAvatar(
                        backgroundColor: Colors.amber,
                        radius: 24 * fontScale,
                        child: Text(
                          '$serverSequence',
                          style: TextStyle(fontSize: 28 * fontScale, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // [전체화면 토글 버튼]
                  _buildCentralPanelButton(
                    icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    label: '전체화면',
                    onPressed: _toggleFullScreen,
                  ),
                  const SizedBox(height: 16),
                  // [음성 토글 버튼]
                  _buildCentralPanelButton(
                    icon: _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                    label: '음성',
                    onPressed: () {
                      setState(() {
                        _isVoiceEnabled = !_isVoiceEnabled;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // [되돌리기 버튼]
                  _buildCentralPanelButton(
                    icon: Icons.undo,
                    label: '실행취소',
                    onPressed: _undoLastAction,
                  ),
                  const SizedBox(height: 16),
                  // [리셋 버튼]
                  _buildCentralPanelButton(
                    icon: Icons.refresh,
                    label: '리셋',
                    onPressed: _resetGame,
                  ),
                ],
              ),
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

  // 중앙 패널 버튼 위젯
  Widget _buildCentralPanelButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          iconSize: 30 * fontScale,
          onPressed: onPressed,
          tooltip: label,
        ),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 10 * fontScale)),
      ],
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
        color: isServing ? baseColor.shade100 : baseColor.shade50.withOpacity(0.5),
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