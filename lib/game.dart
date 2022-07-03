import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bishop/bishop.dart' as bh;
import 'package:chessground/chessground.dart' as cg;
import 'auth.dart';
import 'constants.dart';

class Game extends StatefulWidget {
  final Auth auth;

  const Game({required this.auth, super.key});

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
    final pov = _gameInfo?['black']['id'] == widget.auth.me?.id
        ? cg.Color.black
        : cg.Color.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casual 5 | 5 against maia1'),
      ),
      body: Center(
        child: cg.Board(
          settings: cg.Settings(
            interactable: _gameState != null,
            interactableColor: pov == cg.Color.white
                ? cg.InteractableColor.white
                : cg.InteractableColor.black,
          ),
          theme: cg.BoardTheme.green,
          size: screenWidth,
          orientation: pov,
          validMoves: _gameState?.validMoves,
          fen: _gameState?.fen ?? '8/8/8/8/8/8/8/8 w - - 0 1',
          lastMove: _gameState?.lastMove,
          turnColor: _gameState?.turn ?? pov,
          onMove: _onMove,
        ),
      ),
    );
  }

  void _onMove(cg.Move move) async {
    final ok = _gameState!.playMove(move);
    if (ok) {
      setState(() {});
      await _client.post(
        Uri.parse(
            '$kLichessHost/api/board/game/${_gameInfo!['id']}/move/${move.uci}'),
      );
    }
  }

  Future<void> _listenToSiteEvents() async {
    final resp = await _client
        .send(http.Request('GET', Uri.parse('$kLichessHost/api/stream/event')));
    resp.stream
        .toStringStream()
        .where((event) => event.isNotEmpty && event != '\n')
        .map((event) {
      debugPrint('site event: ' + event);
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
        debugPrint('game event ' + jsonEncode(state));
        final gs = GameState(
            moves: state['moves'],
            wtime: state['wtime'],
            btime: state['btime'],
            winc: state['winc'],
            binc: state['binc'],
            status: state['status']);
        setState(() {
          _gameState = gs;
        });
      }
    });
  }

  _createGame() async {
    await _listenToSiteEvents();
    _client.post(
      Uri.parse('$kLichessHost/api/challenge/maia1'),
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
