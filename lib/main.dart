import 'package:flutter/material.dart';
import 'auth.dart';
import 'tv.dart';
import 'game.dart';

final auth = Auth();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await auth.init();
  runApp(const MyApp());
}

final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
  textStyle: const TextStyle(fontSize: 20),
  fixedSize: const Size.fromWidth(200),
);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey,
      ),
      home: const MyHomePage(title: 'Lichess Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isBusy = false;
  String? username = auth.me?.username;

  Future<void> loginAction() async {
    setState(() {
      isBusy = true;
    });
    await auth.login();
    setState(() {
      isBusy = false;
      username = auth.me?.username;
    });
  }

  Future<void> logoutAction() async {
    setState(() {
      isBusy = true;
    });
    await auth.logout();
    setState(() {
      isBusy = false;
      username = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget _profileOrLogin = isBusy
        ? const CircularProgressIndicator()
        : username != null
            ? Profile(logoutAction, username!)
            : Login(loginAction);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _profileOrLogin,
            const SizedBox(height: 10),
            ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TV()),
                );
              },
              child: const Text('Watch TV'),
            ),
            username != null
                ? ElevatedButton(
                    style: buttonStyle,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Game(auth: auth)),
                      );
                    },
                    child: const Text('Play maia1 bot'),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class Login extends StatelessWidget {
  final Future<void> Function() loginAction;

  const Login(this.loginAction, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ElevatedButton(
          style: buttonStyle,
          onPressed: () async {
            await loginAction();
          },
          child: const Text('Login'),
        ),
      ],
    );
  }
}

class Profile extends StatelessWidget {
  final Future<void> Function() logoutAction;
  final String name;

  const Profile(this.logoutAction, this.name, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('Logged in as $name'),
        const SizedBox(height: 10.0),
        ElevatedButton(
          style: buttonStyle,
          onPressed: () async {
            await logoutAction();
          },
          child: const Text('Logout'),
        ),
      ],
    );
  }
}
