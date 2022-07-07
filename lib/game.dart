import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:bishop/bishop.dart' as bh;
import 'package:chessground/chessground.dart' as cg;
import 'auth.dart';
import 'constants.dart';
import 'widgets.dart';
import 'sound.dart' as sound;

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

const startingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const httpRetries = [
  Duration(milliseconds: 200),
  Duration(milliseconds: 300),
  Duration(milliseconds: 500),
];

enum BottomMenu { abort, resign, play }

class Game extends StatefulWidget {
  final Me me;
  final String bot;

  const Game({required this.me, required this.bot, super.key});

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> {
  final http.Client _client = AuthClient(http.Client());

  Map<String, dynamic>? _gameInfo;
  GameState? _gameState;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final pov = _gameInfo?['black']['id'] == widget.me.id ? 'black' : 'white';
    final orientation = pov == 'white' ? cg.Color.white : cg.Color.black;
    final Widget board = cg.Board(
      settings: cg.Settings(
        interactable: _gameState != null && _gameState!.playing,
        interactableColor: pov == 'white'
            ? cg.InteractableColor.white
            : cg.InteractableColor.black,
      ),
      theme: cg.BoardTheme.green,
      size: screenWidth,
      orientation: orientation,
      validMoves: _gameState?.validMoves,
      fen: _gameState?.fen ?? '8/8/8/8/8/8/8/8 w - - 0 1',
      lastMove: _gameState?.lastMove,
      turnColor: _gameState?.turn ?? orientation,
      onMove: _onMove,
    );
    final topPlayerColor = pov == 'white' ? 'black' : 'white';
    final Widget topPlayer = _gameInfo != null
        ? Player(
            name: _gameInfo![topPlayerColor]['name'],
            rating: _gameInfo![topPlayerColor]['rating'],
            title: _gameInfo![topPlayerColor]['title'],
            active: _gameState?.status == 'started' &&
                _gameState?.turn != orientation,
            clock: Duration(
                milliseconds:
                    (pov == 'white' ? _gameState?.btime : _gameState?.wtime) ??
                        0),
          )
        : const SizedBox.shrink();
    final Widget bottomPlayer = _gameInfo != null
        ? Player(
            name: _gameInfo![pov]['name'],
            rating: _gameInfo![pov]['rating'],
            title: _gameInfo![pov]['title'],
            active: _gameState?.status == 'started' &&
                _gameState?.turn == orientation &&
                (_gameState!.fullmoves > 1 || pov == 'black'),
            clock: Duration(
                milliseconds:
                    (pov == 'white' ? _gameState?.wtime : _gameState?.btime) ??
                        0),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Casual 5 | 5 against maia1'), actions: [
        IconButton(
            icon: sound.isMuted()
                ? const Icon(Icons.volume_off)
                : const Icon(Icons.volume_up),
            onPressed: () {
              setState(() {
                sound.toggle();
              });
            }),
      ]),
      body: Center(
        child: _gameInfo != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  topPlayer,
                  board,
                  bottomPlayer,
                ],
              )
            : board,
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PopupMenuButton<BottomMenu>(
              icon: const Icon(Icons.menu, size: 32.0),
              onSelected: (BottomMenu item) {
                switch (item) {
                  case BottomMenu.abort:
                  case BottomMenu.resign:
                    _resign();
                    break;
                  case BottomMenu.play:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              Game(me: widget.me, bot: widget.bot)),
                    );
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<BottomMenu>>[
                if (_gameState == null || _gameState!.abortable)
                  const PopupMenuItem<BottomMenu>(
                    value: BottomMenu.abort,
                    child: Text('Abort'),
                  ),
                if (_gameState?.resignable == true)
                  const PopupMenuItem<BottomMenu>(
                    value: BottomMenu.resign,
                    child: Text('Resign'),
                  ),
                if (_gameState?.playing == false)
                  const PopupMenuItem<BottomMenu>(
                    value: BottomMenu.play,
                    child: Text('Play another one'),
                  ),
              ],
            ),
            Text(_gameState?.status.capitalize() ?? ''),
            const SizedBox(width: 32.0),
          ],
        ),
      ),
    );
  }

  void _onMove(cg.Move move) async {
    final c = RetryClient.withDelays(
      AuthClient(http.Client()),
      httpRetries,
      whenError: (o, s) => true,
    );

    final ok = _gameState!.playMove(move);
    if (ok) {
      setState(() {});
      if (_gameState!.lastMoveCapture) {
        sound.playCapture();
      } else {
        sound.playMove();
      }
      try {
        await c.post(
          Uri.parse(
              '$kLichessHost/api/board/game/${_gameInfo!['id']}/move/${move.uci}'),
        );
      } finally {
        c.close();
      }
    }
  }

  Future<void> _resign() async {
    final c = RetryClient.withDelays(
      AuthClient(http.Client()),
      httpRetries,
      whenError: (o, s) => true,
    );
    try {
      await _client.post(
        Uri.parse('$kLichessHost/api/board/game/${_gameInfo!['id']}/resign'),
      );
    } finally {
      c.close();
    }
  }

  Future<void> _listenToSiteEvents() async {
    final resp = await _client
        .send(http.Request('GET', Uri.parse('$kLichessHost/api/stream/event')));
    resp.stream
        .toStringStream()
        .where((event) => event.isNotEmpty && event != '\n')
        .map((event) {
      return jsonDecode(event);
    }).forEach((event) {
      switch (event['type']) {
        case 'gameStart':
          final game = event['game'];
          if (game['compat']['board']) {
            final id = game['gameId'];
            // if there is already a game, ignore
            if (_gameInfo == null) {
              _listenToGameEvents(id);
            }
          }
          break;
      }
    });
  }

  void _listenToGameEvents(String id) async {
    final resp = await _client.send(http.Request(
        'GET', Uri.parse('$kLichessHost/api/board/game/stream/$id')));
    resp.stream
        .toStringStream()
        .where((event) => event.isNotEmpty && event != '\n')
        .map((event) => jsonDecode(event))
        .forEach((json) {
      Map<String, dynamic>? state;
      switch (json['type']) {
        case 'gameFull':
          setState(() {
            _gameInfo = json;
          });
          state = json['state'];
          break;

        case 'gameState':
          state = json;
          break;
      }
      if (state != null) {
        developer.log('[GAME STREAM] ' + jsonEncode(state));
        final gs = GameState(
            moves: state['moves'],
            wtime: state['wtime'],
            btime: state['btime'],
            winc: state['winc'],
            binc: state['binc'],
            status: state['status']);
        if (gs.fen != startingFen && _gameState?.fen != gs.fen) {
          if (gs.lastMoveCapture) {
            sound.playCapture();
          } else {
            sound.playMove();
          }
        }
        setState(() {
          _gameState = gs;
        });
      }
    });
  }

  _createGame() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await _listenToSiteEvents();
    _client.post(
      Uri.parse('$kLichessHost/api/challenge/${widget.bot}'),
      body: {
        'rated': 'false',
        // 'level': '1',
        'clock.limit': (5 * 60).toString(),
        'clock.increment': '5',
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    super.dispose();
    _client.close();
  }
}

class GameState {
  final String moves;
  final int wtime;
  final int btime;
  final int winc;
  final int binc;
  final String status;

  final List<String> _moveList;
  final bh.Game _game = bh.Game(variant: bh.Variant.standard());

  late final cg.ValidMoves _validMoves;

  GameState(
      {required this.moves,
      required this.wtime,
      required this.btime,
      required this.winc,
      required this.binc,
      required this.status})
      : _moveList = moves.split(' ').where((m) => m.isNotEmpty).toList() {
    for (final m in _moveList) {
      final bh.Move? _m = _game.getMove(m);
      if (_m != null) {
        _game.makeMove(_m);
      }
    }

    _validMoves = _makeValidMoves();
  }

  bool playMove(cg.Move move) {
    bh.Move? m = _game.getMove(move.uci);
    return m != null ? _game.makeMove(m) : false;
  }

  String get fen => _game.fen;
  cg.Color get turn => _game.turn == bh.WHITE ? cg.Color.white : cg.Color.black;
  cg.Move? get lastMove => _game.state.move != null
      ? cg.Move(
          from: bh.squareName(_game.state.move!.from),
          to: bh.squareName(_game.state.move!.to))
      : null;
  cg.ValidMoves? get validMoves => _validMoves;
  bool get abortable => status == 'started' && _game.state.fullMoves < 1;
  bool get resignable => status == 'started' && _game.state.fullMoves > 1;
  bool get playing => status == 'started';
  int get fullmoves => _game.state.fullMoves;
  bool get lastMoveCapture => _game.state.move?.capturedPiece != null;

  cg.ValidMoves _makeValidMoves() {
    final cg.ValidMoves result = {};
    final legalMoves = _game.generateLegalMoves();
    for (bh.Move m in legalMoves) {
      final fromSquare = bh.squareName(m.from);
      final toSquare = bh.squareName(m.to);
      if (!result.containsKey(fromSquare)) {
        result[fromSquare] = {toSquare};
      } else {
        result[fromSquare]!.add(toSquare);
      }
    }
    return result;
  }
}
