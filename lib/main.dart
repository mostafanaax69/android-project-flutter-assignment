import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:hello_me/test.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => AuthApp.instance(),
        child: MaterialApp(
          title: 'Startup Name Generator',
          initialRoute: '/',
          routes: {
            '/': (context) => RandomWords(),
            '/login': (context) => LoginScreen(),
          },
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              color: Colors.deepPurple,
            ),
          ),
        ));
  }
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  var user;
  final _suggestions = <WordPair>[];
  final _saved = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  var drag = true;
  SnappingSheetController sheetController = SnappingSheetController();

  // final wordPair = WordPair.random();
  //return Text(wordPair.asPascalCase);

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    final alreadySavedData =
        (user.status == Status.Authenticated && user.getData().contains(pair));
    final isSaved = (alreadySaved || alreadySavedData);
    if (alreadySaved && !alreadySavedData) {
      user.addpair(pair.toString(), pair.first, pair.second);
    }

    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        isSaved ? Icons.star : Icons.star_border,
        color: isSaved ? Colors.deepPurple : null,
        semanticLabel: isSaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () {
        setState(() {
          if (isSaved) {
            _saved.remove(pair);
            user.removepair(pair.toString());
          } else {
            _saved.add(pair);
            user.addpair(pair.toString(), pair.first, pair.second);
          }
        });
      },
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return Divider();
          }
          final int index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });
  }

  void _pushSaved() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            const TextStyle _biggerFont = const TextStyle(fontSize: 18);
            final user = Provider.of<AuthApp>(context);
            var favorites = _saved;
            var text;
            final GlobalKey<ScaffoldState> _scaffoldKey =
                new GlobalKey<ScaffoldState>();
            if (user.status == Status.Authenticated) {
              favorites = _saved.union(user.getData());
            } else {
              favorites = _saved;
            }

            final tiles = favorites.map(
              (WordPair pair) {
                return Dismissible(
                    key: ObjectKey(pair),
                    onDismissed: (dir) {
                      showDialog(
                          context: context,
                          builder: (_) {
                            return AlertDialog(
                              title: Text(
                                  'Are You sure you want to delete $pair from your saved'
                                  ' suggestions?'),
                              actions: [
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  // passing false
                                  child: const Text('No'),
                                  style: ElevatedButton.styleFrom(
                                    primary: Colors.deepPurple,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  // passing true
                                  child: const Text('Yes'),
                                  style: ElevatedButton.styleFrom(
                                    primary: Colors.deepPurple,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          }).then((exit) {
                        if (exit == null) return;

                        if (exit) {
                          // user pressed Yes button
                          setState(() {
                            user.removepair(pair.toString());
                            setState(() => _saved.remove(pair));
                          });
                        } else {
                          // user press No button
                          Navigator.pop(context, 'current_user_location');
                        }
                      });
                    },
                    background: Container(
                      child: Row(
                        children: const [
                          Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                          Text(
                            'Delete Suggestion',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          )
                        ],
                      ),
                      color: Colors.deepPurple,
                    ),
                    child: ListTile(
                      title: Text(
                        pair.asPascalCase,
                        style: _biggerFont,
                      ),
                    ));
              },
            );

            final divided = tiles.isNotEmpty
                ? ListTile.divideTiles(
                    context: context,
                    tiles: tiles,
                  ).toList()
                : <Widget>[];

            return Scaffold(
              appBar: AppBar(
                title: const Text('Saved Suggestions'),
              ),
              body: ListView(children: divided),
            );
          },
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    user = Provider.of<AuthApp>(context);
    var logVar = _loginScreen;
    var logIcon = Icons.login;

    //  if (user.status == Status.Unauthenticated) {
    //  const snackBar =
    //       SnackBar(content: Text('There was an error logging into the app'));
    //  ScaffoldMessenger.of(context).showSnackBar(snackBar);
    //  }

    if (user.status == Status.Authenticated) {
      logVar = _logoutScreen;
      logIcon = Icons.exit_to_app;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(icon: Icon(logIcon), onPressed: logVar),
        ],
      ),
      body: GestureDetector(
          child: SnappingSheet(
            controller: sheetController,
            snappingPositions: const [
              SnappingPosition.pixels(
                  positionPixels: 200,
                  snappingCurve: Curves.bounceOut,
                  snappingDuration: Duration(milliseconds: 200)),
              SnappingPosition.factor(
                  positionFactor: 1.1,
                  snappingCurve: Curves.easeInBack,
                  snappingDuration: Duration(milliseconds: 1)),
            ],
            lockOverflowDrag: true,
            child: _buildSuggestions(),
            sheetBelow: user.status == Status.Authenticated
                ? SnappingSheetContent(
                    draggable: drag,
                    child: Container(
                      color: Colors.white,
                      height: 80,
                      child: ListView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            Column(children: [
                              Row(children: <Widget>[
                                Expanded(
                                  child: Container(
                                    color: Colors.grey,
                                    height: 40,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Flexible(
                                            flex: 3,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                  "  Welcome back, " +
                                                      user.getMail(),
                                                  textAlign: TextAlign.left,
                                                  style: const TextStyle(
                                                      fontSize: 16.0)),
                                            )),
                                        const IconButton(
                                          icon: Icon(Icons.keyboard_arrow_up),
                                          onPressed: null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                              Row(children: <Widget>[
                                FutureBuilder(
                                  future: user.getImageUrl(),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<String> snapshot) {
                                    return CircleAvatar(
                                      radius: 40.0,
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.purple,
                                      backgroundImage: snapshot.data != null
                                          ? NetworkImage(
                                              snapshot.data.toString())
                                          : null,
                                    );
                                  },
                                ),
                                Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(user.getMail(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15))),
                              ]),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: <Widget>[
                                    MaterialButton(
                                      onPressed: () async {
                                        FilePickerResult? result =
                                            await FilePicker.platform.pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: [
                                            'png',
                                            'jpg',
                                            'gif',
                                            'bmp',
                                            'jpeg',
                                            'webp'
                                          ],
                                        );
                                        File file;
                                        if (result != null) {
                                          file = File(result.files.single.path
                                              .toString());
                                          user.uploadNewImage(file);
                                        } else {}
                                      },
                                      textColor: Colors.white,
                                      padding: const EdgeInsets.only(
                                          left: 1.0,
                                          top: 1.0,
                                          bottom: 100.0,
                                          right: 100.0),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: <Color>[
                                              Color(0xFF42A5F5),
                                              Color(0xFF42A5F5),
                                            ],
                                          ),
                                        ),
                                        padding: const EdgeInsets.only(
                                            left: 10.0,
                                            top: 8.0,
                                            bottom: 8.0,
                                            right: 10.0),
                                        child: const Text('Change Avatar',
                                            style: TextStyle(fontSize: 15)),
                                      ),
                                    ),
                                  ]),
                            ]),
                          ]),
                    ),
                    //heightBehavior: SnappingSheetHeight.fit(),
                  )
                : null,
          ),
          onTap: () => {
                setState(() {
                  if (drag == false) {
                    drag = true;
                    sheetController
                        .snapToPosition(const SnappingPosition.factor(
                      positionFactor: 0,
                    ));
                  } else {
                    drag = false;
                    sheetController.snapToPosition(
                        const SnappingPosition.factor(
                            positionFactor: 0.2,
                            snappingCurve: Curves.decelerate,
                            snappingDuration: Duration(milliseconds: 200)));
                  }
                })
              }),
    );
  }

  void _logoutScreen() async {
    sheetController
        .snapToPosition(SnappingPosition.factor(positionFactor: 0.2));
    drag = false;
    await user.signOut();
    _saved.clear();
  }

  void _loginScreen() {
    Navigator.pushNamed(context, '/login');
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  var scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthApp>(context);
    TextEditingController _email = TextEditingController(text: "");
    TextEditingController _password = TextEditingController(text: "");
    TextEditingController _confirm = TextEditingController(text: "");

    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: const Text('Login'),
          centerTitle: true,
        ),
        body: Column(
          children: <Widget>[
            const Padding(
                padding: EdgeInsets.all(25.0),
                child: (Text(
                  'Welcome to Startup Names Generator, please log in below',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ))),
            const SizedBox(height: 35),
            TextField(
              controller: _email,
              obscureText: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 35),
            user.status == Status.Authenticating
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!await user.signIn(_email.text, _password.text)) {
                          const snackBar = SnackBar(
                              content: Text(
                                  'There was an error logging into the app'));
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Login'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(300, 48),
                        shape: const StadiumBorder(),
                        primary: Colors.deepPurple,
                        onPrimary: Colors.white,
                      ),
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: ElevatedButton(
                onPressed: () async {
                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (BuildContext context) {
                        return Container(
                          color: Color(0xFF737373),
                          height: 200,
                          child: Container(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const Text(
                                  "Please confirm your password below:",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                ),
                                const SizedBox(height: 25),
                                TextField(
                                  controller: _confirm,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Password'
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    print(_confirm);
                                    if (_password.text == _confirm.text) {
                                      user.signUp(_email.text, _password.text);
                                      Navigator.pushNamed(
                                          context, '/login');
                                      Navigator.pushNamed(context, '/');
                                    } else {
                                       var snackBar = const SnackBar(
                                        content:
                                            Text("Passwords must match"),
                                        duration: Duration(seconds: 5),
                                        backgroundColor: Colors.red,
                                      );
                                      setState(() {
                                        FocusScope.of(context).requestFocus(FocusNode());
                                      });
                                    }
                                  },
                                  child: const Text('Confirm',
                                      style: TextStyle(fontSize: 20)),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(300, 48),
                                    shape: const StadiumBorder(),
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                  ),
                                )
                              ],
                            ),
                            decoration: BoxDecoration(
                                color: Theme.of(context).canvasColor,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20),
                                  topLeft: Radius.circular(20),
                                )),
                          ),
                        );
                      });
                },

                child: const Text('New user? Click to sign up'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(300, 48),
                  shape: const StadiumBorder(),
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                ),
              ),
            )
          ],
        ));
  }
}
