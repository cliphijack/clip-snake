import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const SnakeApp());

const int kCols = 20, kRows = 20;
const Color kBg = Color(0xFF0F0F1B), kGrid = Color(0xFF1B1B33),
    kSnake = Color(0xFF39FF14), kHead = Color(0xFFEFFFD6), kFood = Color(0xFFFF3131);
const Color kLeftC = Color(0xFF00E5FF), kRightC = Color(0xFFFF2D95);

class SnakeApp extends StatelessWidget {
  const SnakeApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Galmuri', scaffoldBackgroundColor: kBg),
        home: const GameScreen(),
      );
}

enum Phase { start, play, over }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const List<Point<int>> startSnake = [Point(8, 10), Point(7, 10), Point(6, 10)];
  List<Point<int>> snake = List.of(startSnake);
  Point<int> dir = const Point(1, 0);
  bool turnedThisTick = false;
  Point<int> food = const Point(13, 10);
  int score = 0, best = 0;
  Phase phase = Phase.start;
  Timer? timer;
  final rng = Random();
  final AudioPlayer _eatP = AudioPlayer();
  final AudioPlayer _overP = AudioPlayer();

  @override
  void initState() { super.initState(); _loadBest(); }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    setState(() => best = p.getInt('best') ?? 0);
  }
  Future<void> _saveBest() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('best', best);
  }

  void startGame() {
    snake = List.of(startSnake);
    dir = const Point(1, 0);
    score = 0;
    _spawnFood();
    phase = Phase.play;
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 170), (_) => _tick());
    setState(() {});
  }

  void _spawnFood() {
    while (true) {
      final f = Point(rng.nextInt(kCols), rng.nextInt(kRows));
      if (!snake.contains(f)) { food = f; break; }
    }
  }

  void turnLeft() {
    if (phase != Phase.play || turnedThisTick) return;
    dir = Point(dir.y, -dir.x); turnedThisTick = true; setState(() {});
  }
  void turnRight() {
    if (phase != Phase.play || turnedThisTick) return;
    dir = Point(-dir.y, dir.x); turnedThisTick = true; setState(() {});
  }
  void _setDirAbs(Point<int> d) {
    if (turnedThisTick) return;
    if (d.x == -dir.x && d.y == -dir.y) return;
    dir = d; turnedThisTick = true;
  }

  void _tick() {
    turnedThisTick = false;
    final head = snake.first;
    final nh = Point(head.x + dir.x, head.y + dir.y);
    if (nh.x < 0 || nh.y < 0 || nh.x >= kCols || nh.y >= kRows || snake.contains(nh)) {
      timer?.cancel();
      phase = Phase.over;
      _overP.play(AssetSource('sfx/over.wav'));
      if (score > best) { best = score; _saveBest(); }
      setState(() {});
      return;
    }
    snake.insert(0, nh);
    if (nh == food) {
      score += 10;
      _eatP.play(AssetSource('sfx/eat.wav'));
      _spawnFood();
    } else {
      snake.removeLast();
    }
    setState(() {});
  }

  void _onSwipe(Offset v) {
    if (phase != Phase.play) return;
    if (v.dx.abs() > v.dy.abs()) {
      _setDirAbs(Point(v.dx > 0 ? 1 : -1, 0));
    } else {
      _setDirAbs(Point(0, v.dy > 0 ? 1 : -1));
    }
  }

  @override
  void dispose() { timer?.cancel(); _eatP.dispose(); _overP.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: GestureDetector(
          onPanEnd: (d) => _onSwipe(d.velocity.pixelsPerSecond),
          onTap: () { if (phase == Phase.start || phase == Phase.over) startGame(); },
          child: phase == Phase.start ? _startScreen() : _gameScreen(),
        ),
      ),
    );
  }

  Widget _startScreen() {
    return Container(
      color: kBg, alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("클립 납치단", style: TextStyle(color: kSnake, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("SNAKE", style: TextStyle(color: kHead, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 6)),
        const SizedBox(height: 36),
        Text("최고점수  $best", style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 36),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(color: kSnake, boxShadow: const [BoxShadow(color: kSnake, blurRadius: 26, spreadRadius: 2)]),
          child: const Text("TAP TO START", style: TextStyle(color: kBg, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        const Text("회전 버튼으로 좌·우 꺾기", style: TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }

  Widget _gameScreen() {
    return Column(children: [
      const SizedBox(height: 12),
      const Text("클립 납치단 스네이크", style: TextStyle(color: kSnake, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text("SCORE $score   BEST $best", style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 10),
      Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: kSnake, width: 3)),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: BoardPainter(snake, food))),
          if (phase == Phase.over)
            Positioned.fill(child: Container(
              color: Colors.black.withOpacity(0.65), alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("GAME OVER", style: TextStyle(color: kFood, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("SCORE $score", style: const TextStyle(color: Colors.white, fontSize: 18)),
                Text("BEST $best", style: const TextStyle(color: kSnake, fontSize: 15)),
                const SizedBox(height: 14),
                const Text("탭하면 다시 시작", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            )),
        ]),
      )))),
      Padding(
        padding: const EdgeInsets.fromLTRB(36, 12, 36, 22),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          NeonTurnButton(icon: Icons.rotate_left, color: kLeftC, onPress: turnLeft),
          NeonTurnButton(icon: Icons.rotate_right, color: kRightC, onPress: turnRight),
        ]),
      ),
    ]);
  }
}

class NeonTurnButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPress;
  const NeonTurnButton({super.key, required this.icon, required this.color, required this.onPress});
  @override
  State<NeonTurnButton> createState() => _NeonTurnButtonState();
}

class _NeonTurnButtonState extends State<NeonTurnButton> {
  bool down = false;
  void _set(bool v) => setState(() => down = v);
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown: (_) { _set(true); widget.onPress(); },
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 92, height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            down ? c : c.withOpacity(0.18),
            down ? c.withOpacity(0.6) : kBg,
          ], radius: 0.95),
          border: Border.all(color: c, width: 3),
          boxShadow: [BoxShadow(color: c.withOpacity(down ? 0.95 : 0.55), blurRadius: down ? 28 : 16, spreadRadius: down ? 4 : 1)],
        ),
        child: Icon(widget.icon, size: 46, color: down ? kBg : c),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int> food;
  BoardPainter(this.snake, this.food);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / kCols;
    final grid = Paint()..color = kGrid..strokeWidth = 1;
    for (int i = 0; i <= kCols; i++) canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
    for (int j = 0; j <= kRows; j++) canvas.drawLine(Offset(0, j * cell), Offset(size.width, j * cell), grid);
    canvas.drawRect(Rect.fromLTWH(food.x * cell, food.y * cell, cell, cell), Paint()..color = kFood);
    final body = Paint()..color = kSnake;
    for (int i = 1; i < snake.length; i++) canvas.drawRect(Rect.fromLTWH(snake[i].x * cell + 1, snake[i].y * cell + 1, cell - 2, cell - 2), body);
    final h = snake.first;
    canvas.drawRect(Rect.fromLTWH(h.x * cell + 1, h.y * cell + 1, cell - 2, cell - 2), Paint()..color = kHead);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
