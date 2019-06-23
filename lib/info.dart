import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'utils.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:parallax_image/parallax_image.dart';
import 'firebase_storage_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoListSection extends StatelessWidget {
  InfoListSection({this.title, this.imagePath, this.child});

  final String title;
  final String imagePath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new Card(
      margin: EdgeInsets.all(12.0),
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            new DefaultTextStyle(
              style: Theme.of(context).textTheme.subhead,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                child: new Text(
                  title,
                  textAlign: TextAlign.start,
                  style: new TextStyle(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: child,
            )
          ],
        ),
      ),
    );
  }
}

class InfoPage extends StatefulWidget {
  @override
  _InfoPageState createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final TextEditingController _nameDialogTextController = new TextEditingController();

  @override
  void dispose() {
    _nameDialogTextController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: new BoxDecoration(
          gradient: new LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.yellow, Colors.pink],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: new CustomScrollView(
            slivers: <Widget>[
              new SliverAppBar(
                backgroundColor: Colors.transparent,
                title: new Text('Info'),
              ),
              new SliverList(
                delegate: new SliverChildListDelegate(
                  <Widget>[
                    new InfoListSection(
                      title: 'Helpful Resources',
                      imagePath: 'assets/info_backgrounds/bg_1.png',
                      child: new StreamBuilder<QuerySnapshot>(
                        stream: Firestore.instance.collection('resources').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return Center(child: new CircularProgressIndicator());

                          List<List<Widget>> rows = [];

                          for (var i = 0; i < (snapshot.data.documents.length / 3).ceil() * 3; i++) {
                            if (i % 3 == 0) {
                              rows.add([]);
                            }

                            if (i < snapshot.data.documents.length) {
                              rows[(i / 3).floor()].add(
                                Expanded(
                                  child: Column(
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: RawMaterialButton(
                                          shape: const CircleBorder(),
                                          elevation: 4.0,
                                          fillColor: Colors.white,
                                          onPressed: () {
                                            print('tap');
                                            launch(snapshot.data.documents[i]['url']);
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(28),
                                            child: Container(
                                              width: 56.0,
                                              height: 56.0,
                                              child: new FirebaseStorageImage(
                                                reference: FirebaseStorage.instance
                                                    .ref()
                                                    .child('resources')
                                                    .child(snapshot.data.documents[i]['image']),
                                                errorWidget: new Icon(
                                                  Icons.link,
                                                  color: Colors.blue,
                                                ),
                                                fallbackWidget: new Icon(
                                                  Icons.link,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      new Text(
                                        snapshot.data.documents[i]['title'],
                                        style: Theme.of(context).textTheme.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              rows[(i / 3).floor()].add(
                                Expanded(
                                  child: Container(),
                                ),
                              );
                            }
                          }

                          List<Widget> rowWidgets = rows.map((row) {
                            return new Row(
                              children: row,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                            );
                          }).toList();

                          return new Column(
                            children: rowWidgets,
                          );
                        },
                      ),
                    ),
                    new InfoListSection(
                      title: 'Questions',
                      imagePath: 'assets/info_backgrounds/bg_2.png',
                      child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          new StreamBuilder<QuerySnapshot>(
                            stream: Firestore.instance
                                .collection('questions')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return new Center(child: new CircularProgressIndicator());

                              return new Column(
                                mainAxisSize: MainAxisSize.min,
                                children: snapshot.data.documents
                                    .sublist(0, min(snapshot.data.documents.length, 2))
                                    .map((document) {
                                  return Column(
                                    children: <Widget>[
                                      new QuestionListTile(document),
                                      new Divider(
                                        height: 2.0,
                                      )
                                    ],
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          new Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              new FlatButton(
                                  onPressed: () {
                                    addQuestion(context, _nameDialogTextController);
                                  },
                                  child:
                                      Text('Ask a Question', style: TextStyle(color: Theme.of(context).primaryColor))),
                              new FlatButton(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .push(new MaterialPageRoute(builder: (context) => new ChatPage()));
                                  },
                                  child: Text('See All', style: TextStyle(color: Theme.of(context).primaryColor))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    new InfoListSection(
                      title: 'Contacts',
                      imagePath: 'assets/info_backgrounds/bg_3.png',
                      child: new StreamBuilder<QuerySnapshot>(
                        stream: Firestore.instance.collection('contacts').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return new Center(child: new CircularProgressIndicator());

                          List<Widget> children = snapshot.data.documents.map((document) {
                            return Column(
                              children: <Widget>[
                                new ListTile(
                                  title: new Text(document['name']),
                                  subtitle: new Text(document['title']),
                                  onTap: () {
                                    showDialog(
                                        context: context,
                                        builder: (context) {
                                          List<Widget> children = [
                                            new ListTile(title: new Text(document['info'])),
                                            new Divider(
                                              height: 1.0,
                                            )
                                          ];

                                          if (document['email'] != null) {
                                            children.add(
                                              new ListTile(
                                                title: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: new Text(
                                                      document['email'],
                                                    )),
                                                leading: new Icon(Icons.email),
                                                onTap: () {
                                                  launch('mailto:${document['email']}');
                                                },
                                              ),
                                            );
                                            children.add(new Divider(height: 1.0));
                                          }

                                          if (document['phone'] != null) {
                                            children.add(
                                              new ListTile(
                                                title: new Text(document['phone']),
                                                leading: new Icon(Icons.phone),
                                                onTap: () {
                                                  launch('tel:${document['phone']}');
                                                },
                                              ),
                                            );
                                            children.add(new Divider(height: 1.0));
                                          }

                                          return new AlertDialog(
                                            title: new Text(document['name']),
                                            content: new Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: children,
                                            ),
                                            actions: <Widget>[
                                              new FlatButton(
                                                  child: new Text('Close'),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  })
                                            ],
                                          );
                                        });
                                  },
                                ),
                                new Divider(
                                  height: 2.0,
                                ),
                              ],
                            );
                          }).toList();

                          return new Column(
                            children: children,
                          );
                        },
                      ),
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
}

class QuestionListTile extends StatelessWidget {
  QuestionListTile(this.document);

  final DocumentSnapshot document;

  @override
  Widget build(BuildContext context) {
    return new ListTile(
      onTap: () {
        Navigator.of(context)
            .push(new MaterialPageRoute(builder: (context) => new QuestionAnswersPage(document.reference)));
      },
      title: new Text(document['question']),
      subtitle: new StreamBuilder<QuerySnapshot>(
        stream: Firestore.instance.collection('questions/${document.documentID}/answers').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return new Text('');

          String text = 'No answers';

          if (snapshot.data.documents.length > 0) {
            text = '${snapshot.data.documents.length} answer${snapshot.data.documents.length > 1 ? 's' : ''}';
          }

          return new Text(text);
        },
      ),
      trailing: new Text(computeHowLongAgoTextShort((document['timestamp'] as Timestamp).toDate())),
    );
  }
}

final GlobalKey<FormState> _addQuestionDialogFormKey = new GlobalKey<FormState>();

Future<bool> isUserRegistered(BuildContext context, TextEditingController nameController, bool prompt) async {
  FirebaseUser user = await FirebaseAuth.instance.currentUser();
  if (user == null) {
    user = await FirebaseAuth.instance.signInAnonymously();

    if (user == null) {
      return false;
    }
  }

  QuerySnapshot snapshot =
      await Firestore.instance.collection('users').where('uid', isEqualTo: user.uid).getDocuments();
  if (snapshot.documents.length >= 1) {
    return true;
  } else {
    if (!prompt) return false;

    bool didRegister = await showDialog<bool>(
      context: context,
      builder: (context) {
        return new AlertDialog(
          title: new Text('What\s your name?'),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          content: new Form(
            key: _addQuestionDialogFormKey,
            child: new TextFormField(
              maxLength: 20,
              validator: (text) {
                if (text.length < 2) {
                  return "Name not long enough";
                }
              },
              controller: nameController,
            ),
          ),
          actions: <Widget>[
            new FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: new Text('Cancel')),
            new FlatButton(
                onPressed: () {
                  print('saving...');
                  if (_addQuestionDialogFormKey.currentState.validate()) {
                    print('okay');
                    Firestore.instance.collection("users").add({"uid": user.uid, "name": nameController.text}).then(
                        (doc) {
                      print(doc);
                      Navigator.of(context).pop(true);
                    }, onError: (error) {
                      print(error);
                    });
                  } else {
                    print('someting wrong with validating');
                  }
                },
                child: new Text('Save')),
          ],
        );
      },
    );

    return didRegister != null && didRegister;
  }
}

void addQuestion(BuildContext context, TextEditingController nameController) {
  isUserRegistered(context, nameController, true).then((didRegister) {
    if (didRegister) {
      Navigator.of(context).push(new MaterialPageRoute(builder: (context) {
        return new AddQuestionPage();
      }));
    }
  });
}

class AddQuestionPage extends StatefulWidget {
  @override
  _AddQuestionPageState createState() => _AddQuestionPageState();
}

class _AddQuestionPageState extends State<AddQuestionPage> {
  static final GlobalKey<FormState> formKey = new GlobalKey<FormState>();

  final TextEditingController textController = new TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    textController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextFormField questionField = new TextFormField(
      autofocus: true,
      maxLength: 150,
      controller: textController,
      validator: (value) {
        if (value.length < 10) {
          return 'question not long enough';
        }

        return null;
      },
    );

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('New Question'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            new Text(
              'How can we help?',
              style: new TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 18.0,
              ),
            ),
            new Form(
              key: formKey,
              child: questionField,
            ),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {
          if (!loading && formKey.currentState.validate()) {
            setState(() {
              loading = true;
            });
            FirebaseAuth.instance.currentUser().then((user) {
              if (user != null) {
                Firestore.instance.collection('questions').add({
                  'question': '${textController.text}',
                  'timestamp': DateTime.now(),
                  'uid': user.uid,
                }).whenComplete(() {
                  Navigator.of(context).pop();
                });
              } else {
                setState(() {
                  loading = false;
                });
              }
            }).catchError(() {
              setState(() {
                loading = false;
              });
            });
          }
        },
        child: !loading
            ? new Icon(
                Icons.send,
                color: Colors.white,
              )
            : new CircularProgressIndicator(
                valueColor: new AlwaysStoppedAnimation<Color>(Colors.white),
              ),
      ),
    );
  }
}

class QuestionProfilePage extends StatefulWidget {
  @override
  _QuestionProfilePageState createState() => _QuestionProfilePageState();
}

class _QuestionProfilePageState extends State<QuestionProfilePage> {
  static final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  static final GlobalKey<FormState> _adminFormKey = new GlobalKey<FormState>();

  final TextEditingController _textController = new TextEditingController();
  final TextEditingController _adminUsernameTextController = new TextEditingController();
  final TextEditingController _adminPasswordTextController = new TextEditingController();

  bool _savingName = false;

  StreamSubscription sub;

  @override
  void initState() {
    super.initState();

    sub = FirebaseAuth.instance.onAuthStateChanged.listen((user) {
      if (user != null) {
        Firestore.instance.collection('users').where('uid', isEqualTo: user.uid).snapshots().listen((data) {
          if (data.documents.length > 0) {
            _textController.text = data.documents.first['name'];
          }
        });
      } else {
        _textController.text = null;
        FirebaseAuth.instance.signInAnonymously();
      }
    });
  }

  @override
  void dispose() {
    sub.cancel();

    _textController.dispose();
    _adminUsernameTextController.dispose();
    _adminPasswordTextController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Profile'),
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: new Text(
                    'What\'s your name?',
                    style: Theme.of(context).textTheme.title,
                  ),
                ),
                new FutureBuilder<FirebaseUser>(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, user) {
                    if (!user.hasData) return new Center(child: new CircularProgressIndicator());
                    print(user.data.uid);

                    return Container(
                      constraints: new BoxConstraints(maxWidth: 200.0),
                      child: Form(
                        key: _formKey,
                        child: new TextFormField(
                          controller: _textController,
                          validator: (text) {
                            if (text.isEmpty || text.length < 3) {
                              return 'Invalid Name';
                            }
                            return null;
                          },
                          maxLength: 20,
                        ),
                      ),
                    );
                  },
                ),
                _savingName
                    ? Center(child: CircularProgressIndicator())
                    : new FlatButton(
                        onPressed: () {
                          setState(() {
                            _savingName = true;
                          });

                          FirebaseAuth.instance.currentUser().then((user) {
                            Firestore.instance
                                .collection('users')
                                .where('uid', isEqualTo: user.uid)
                                .getDocuments()
                                .then(
                              (snapshot) {
                                if (snapshot.documents.length > 0) {
                                  Firestore.instance.runTransaction((transaction) async {
                                    await transaction
                                        .update(snapshot.documents.first.reference, {'name': _textController.text});
                                    print('done!');
                                    setState(() => _savingName = false);
                                  }).catchError((error) {
                                    print(error);
                                  });
                                } else {
                                  Firestore.instance.collection('users').add({
                                    'uid': user.uid,
                                    'name': _textController.text,
                                  }).then((documentReference) {
                                    setState(() {
                                      _savingName = false;
                                    });
                                  });
                                }
                              },
                            );
                          });
                        },
                        child: new Text('Save', style: TextStyle(color: Theme.of(context).primaryColor)),
                      ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Opacity(
                  opacity: 0.5,
                  child: new Text(
                    'Your Questions',
                    textAlign: TextAlign.start,
                    style: new TextStyle(fontSize: 18.0),
                  ),
                ),
                new StreamBuilder<FirebaseUser>(
                    stream: FirebaseAuth.instance.onAuthStateChanged,
                    builder: (context, user) {
                      if (!user.hasData) return new Center(child: CircularProgressIndicator());

                      return new StreamBuilder<QuerySnapshot>(
                        stream: Firestore.instance
                            .collection('questions')
                            .where('uid', isEqualTo: user.data.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return new Center(child: CircularProgressIndicator());

                          if (snapshot.data.documents.length > 0) {
                            return new Column(
                              children: snapshot.data.documents.map((document) {
                                return Column(
                                  children: <Widget>[
                                    new QuestionListTile(document),
                                    new Divider(
                                      height: 2.0,
                                    )
                                  ],
                                );
                                ;
                              }).toList(),
                            );
                          } else {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: new DefaultTextStyle(
                                    style: Theme.of(context).textTheme.caption,
                                    child: new Text('You Haven\'t Asked Any Questions Yet')),
                              ),
                            );
                          }
                        },
                      );
                    }),
              ],
            ),
          ),
          new StreamBuilder<FirebaseUser>(
            stream: FirebaseAuth.instance.currentUser().asStream(),
            builder: (context, user) {
              if (!user.hasData) return new Center(child: CircularProgressIndicator());

              if (user.data.isAnonymous) {
                return new FlatButton(
                  child: new Text(
                    'Sign in as Administrator',
                    style: new TextStyle(color: Theme.of(context).primaryColor),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return new AlertDialog(
                          title: new Text('Administrator Access'),
                          content: new Form(
                            key: _adminFormKey,
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                new TextFormField(
                                  controller: _adminUsernameTextController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: new InputDecoration(hintText: 'Username'),
                                  validator: (text) {
                                    if (!text.contains('@')) {
                                      return 'Not a valid username';
                                    }
                                  },
                                  obscureText: false,
                                ),
                                new TextFormField(
                                  controller: _adminPasswordTextController,
                                  decoration: new InputDecoration(hintText: 'Password'),
                                  keyboardType: TextInputType.text,
                                  obscureText: true,
                                ),
                              ],
                            ),
                          ),
                          actions: <Widget>[
                            new FlatButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: new Text('Cancel')),
                            new FlatButton(
                              onPressed: () {
                                if (_adminFormKey.currentState.validate()) {
                                  FirebaseAuth.instance
                                      .signInWithEmailAndPassword(
                                          email: _adminUsernameTextController.text,
                                          password: _adminPasswordTextController.text)
                                      .then((user) {
                                    Navigator.pop(context, true);
                                  }).catchError((error) {
                                    if (error is PlatformException) {
                                      Navigator.pop(context, false);
                                    }
                                  });
                                }
                              },
                              child: new Text('Log In'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              } else {
                return Column(
                  children: <Widget>[
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.caption,
                      child: new Text(
                        'Welcome, Administrator',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    new FlatButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut().then((_) {
                          FirebaseAuth.instance.signInAnonymously();
                          Navigator.pop(context);
                        });
                      },
                      child: new Text('Sign Out', style: TextStyle(color: Theme.of(context).primaryColor)),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = new TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Questions'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.of(context)
                  .push(new MaterialPageRoute(builder: (context) => new QuestionProfilePage(), fullscreenDialog: true));
            },
          ),
        ],
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {
          addQuestion(context, _textController);
        },
        child: new Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: new Container(
              alignment: Alignment.center,
              child: new StreamBuilder(
                stream: Firestore.instance.collection('questions').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  final int messageCount = snapshot.data.documents.length;

                  if (messageCount > 0) {
                    return new ListView.builder(
                      itemCount: messageCount,
                      itemBuilder: (context, index) {
                        final DocumentSnapshot document = snapshot.data.documents[index];

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            new ListTile(
                              title: new Text('${document['question']}'),
                              subtitle: new StreamBuilder(
                                stream: Firestore.instance
                                    .collection('questions/${document.documentID}/answers')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data.documents.length > 0) {
                                    return new Text(
                                        '${snapshot.data.documents.length} answer${snapshot.data.documents.length > 1 ? 's' : ''}');
                                  } else {
                                    return new Text('No answers yet');
                                  }
                                },
                              ),
                              onTap: () {
                                Navigator.of(context).push(new MaterialPageRoute(builder: (context) {
                                  return new QuestionAnswersPage(document.reference);
                                }));
                              },
                            ),
                            new Divider(
                              height: 1.0,
                            ),
                          ],
                        );
                      },
                    );
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: new Icon(
                          Icons.question_answer,
                          color: Colors.grey.shade300,
                          size: 128.0,
                        ),
                      ),
                      Opacity(
                        opacity: 0.5,
                        child: new Text(
                          'No Questions Yet!',
                          style: new TextStyle(fontWeight: FontWeight.w500, fontSize: 20.0),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          new Divider(
            height: 1.0,
          ),
        ],
      ),
    );
  }
}

class QuestionAnswersPage extends StatefulWidget {
  QuestionAnswersPage(this.documentReference);

  final DocumentReference documentReference;

  @override
  _QuestionAnswersPageState createState() => _QuestionAnswersPageState();
}

class _QuestionAnswersPageState extends State<QuestionAnswersPage> with TickerProviderStateMixin {
  final TextEditingController _textController = new TextEditingController();
  final TextEditingController _nameTextController = new TextEditingController();

  bool _isComposing = false;

  String questionId;
  String uid;

  Widget _buildQuestionHeader(BuildContext context, DocumentSnapshot snapshot) {
    return new Padding(
      padding: const EdgeInsets.only(left: 36.0, right: 36.0, bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Text(
            snapshot.data['question'],
            style: new TextStyle(fontWeight: FontWeight.w500, fontSize: 24.0, color: Colors.white),
          ),
          new Divider(
            color: Colors.white.withOpacity(0.0),
            height: 1.0,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: Firestore.instance.collection("users").where('uid', isEqualTo: snapshot.data['uid']).snapshots(),
              builder: (context, user) {
                String userText = 'unknown';

                if (user.hasData) {
                  if (user.data.documents.length > 0) {
                    userText = user.data.documents.first['name'];
                  }
                }

                return new Text('Asked by $userText', style: new TextStyle(color: Colors.white));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: new Text(
              computeHowLongAgoText((snapshot.data['timestamp'] as Timestamp).toDate()),
              style: new TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameTextController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new FutureBuilder<DocumentSnapshot>(
        future: widget.documentReference.get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: new CircularProgressIndicator());

          this.questionId = snapshot.data.documentID;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              new Container(
                decoration: new BoxDecoration(
                  gradient: new LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.pink, Colors.pinkAccent.shade100],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    new AppBar(
                      elevation: 0.0,
                      backgroundColor: Colors.transparent,
                      actions: <Widget>[
                        new FutureBuilder<FirebaseUser>(
                            future: FirebaseAuth.instance.currentUser(),
                            builder: (context, user) {
                              if (user != null &&
                                  user.hasData &&
                                  (user.data.uid == snapshot.data['uid'] || !user.data.isAnonymous)) {
                                return new IconButton(
                                  icon: new Icon(Icons.delete),
                                  tooltip: 'Delete Question',
                                  onPressed: () async {
                                    var result = await showDialog(
                                      context: context,
                                      builder: (context) => new AlertDialog(
                                            title: new Text('Delete Question?'),
                                            actions: <Widget>[
                                              new FlatButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop(false);
                                                  },
                                                  child: new Text('Cancel')),
                                              new FlatButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop(true);
                                                },
                                                child: new Text(
                                                  'Delete',
                                                  style: new TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );

                                    if ((result != null && result)) {
                                      Firestore.instance.runTransaction(
                                        (transaction) async {
                                          await transaction.delete(widget.documentReference);

                                          Navigator.pop(context);
                                        },
                                      );
                                    }
                                  },
                                );
                              }

                              return Container();
                            }),
                      ],
                    ),
                    _buildQuestionHeader(context, snapshot.data),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: new Divider(
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<FirebaseUser>(
                        future: FirebaseAuth.instance.currentUser(),
                        builder: (context, user) {
                          if (user.hasData) {
                            this.uid = user.data.uid;
                          }

                          return new StreamBuilder<QuerySnapshot>(
                            stream: Firestore.instance
                                .collection('questions/${snapshot.data.documentID}/answers')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                            builder: (context, answersSnapshot) {
                              if (!answersSnapshot.hasData)
                                return Center(
                                  child: new CircularProgressIndicator(
                                    valueColor: new AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );

                              List<DocumentSnapshot> answers = answersSnapshot.data.documents;

                              return new ListView.builder(
                                itemCount: answers.length,
                                reverse: true,
                                itemBuilder: (context, index) {
                                  final DocumentSnapshot document = answers[index];

                                  return new Row(
                                    mainAxisAlignment: user.data.uid == document['uid']
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: <Widget>[
                                      user.data.uid != document['uid']
                                          ? new StreamBuilder<QuerySnapshot>(
                                              stream: Firestore.instance
                                                  .collection('users/')
                                                  .where('uid', isEqualTo: document['uid'])
                                                  .snapshots(),
                                              builder: (context, snapshot) {
                                                Color backgroundColor = Theme.of(context).primaryColor;
                                                Widget child = new Container();

                                                if (snapshot.hasData && snapshot.data.documents.length >= 1) {
                                                  DocumentSnapshot userDoc = snapshot.data.documents.first;
                                                  String name = userDoc['name'];
                                                  List<String> nameComponents = name.split('\ ').where((string) => string.length > 0).toList();
                                                  backgroundColor = colorForAlphabetLetter(name.substring(0, 1));
                                                  print(nameComponents);
                                                  child = new Text(
                                                    '${name.substring(0, 1)}${nameComponents.length > 1 ? (nameComponents[1].length > 0) : ''}',
                                                    style:
                                                        new TextStyle(fontSize: nameComponents.length > 1 ? 12.0 : 14.0),
                                                  );
                                                }

                                                return Padding(
                                                  padding: const EdgeInsets.only(left: 4.0),
                                                  child: new CircleAvatar(
                                                    backgroundColor: backgroundColor,
                                                    maxRadius: 14.0,
                                                    child: child,
                                                  ),
                                                );
                                              })
                                          : new Container(),
                                      Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Container(
                                          constraints: new BoxConstraints(maxWidth: 200.0),
                                          child: new Card(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: new Text(document['answer']),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _buildTextComposer(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextComposer() {
    return new IconTheme(
      data: new IconThemeData(color: Theme.of(context).accentColor),
      child: FutureBuilder<bool>(
        future: isUserRegistered(context, _nameTextController, false),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: new Center(child: new CircularProgressIndicator()),
            );

          return new Container(
            margin: const EdgeInsets.all(8.0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!snapshot.data) {
                  setState(() {
                    isUserRegistered(context, _nameTextController, true);
                  });
                }
              },
              child: new Row(
                children: <Widget>[
                  new Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: new TextField(
                        enabled: snapshot.data,
                        controller: _textController,
                        onChanged: (String text) {
                          setState(() {
                            _isComposing = text.length > 0;
                          });
                        },
                        onSubmitted: _handleSubmitted,
                        decoration: new InputDecoration.collapsed(hintText: "Send a message"),
                      ),
                    ),
                  ),
                  new Container(
                      margin: new EdgeInsets.symmetric(horizontal: 4.0),
                      child: new IconButton(
                        icon: new Icon(Icons.send),
                        onPressed: _isComposing ? () => _handleSubmitted(_textController.text) : null,
                      )),
                ],
              ),
            ),
            decoration: new BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
          );
        },
      ),
    );
  }

  Future<Null> _handleSubmitted(String text) async {
    _textController.clear();
    _textController.clearComposing();
    setState(() {
      _isComposing = false;
    });
    await _ensureLoggedIn();

    _sendMessage(text: text);
  }

  void _sendMessage({String text}) {
    if (text.isEmpty) return;

    Firestore.instance.collection('questions/${questionId}/answers').add({
      'answer': text,
      'uid': this.uid,
      'timestamp': DateTime.now(),
    });
  }

  Future<Null> _ensureLoggedIn() async {
    if (await FirebaseAuth.instance.currentUser() == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  MaterialColor colorForAlphabetLetter(String letter) {
    letter = letter.toLowerCase();
    letter = letter.substring(0, 1);
    return letterColors[letter.codeUnitAt(0) % letterColors.length];
  }
}

final List<MaterialColor> letterColors = [
  Colors.cyan,
  Colors.deepOrange,
  Colors.pink,
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.lightBlue,
  Colors.purple,
  Colors.teal,
  Colors.orange,
  Colors.yellow,
  Colors.indigo,
  Colors.amber,
  Colors.lime
];
