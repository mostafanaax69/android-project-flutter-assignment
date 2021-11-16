import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AuthApp with ChangeNotifier {
  FirebaseAuth _auth;
  User? _user;
  Status _status = Status.Uninitialized;

  AuthApp.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);

  }

  Status get status => _status;

  User? get user => _user;

  bool get isAuthenticated => status == Status.Authenticated;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;
  Set<WordPair> data = <WordPair>{};



  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      data = await getAllfavorites();
      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      print(e);
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }

  Future<void> uploadNewImage(File file)async {
    await _storage
        .ref('images')
        .child(_user!.uid)
        .putFile(file);
    notifyListeners();
  }

  Future<String>
  getImageUrl() async {
    return await _storage.ref('images').child(_user!.uid).getDownloadURL();
  }


  String? getMail() {
    return _user!.email;
  }


  Future<void> addpair(String pair, String fpair, String fpair2) async {
    if (_status == Status.Authenticated) {
      await _firestore
          .collection("users")
          .doc(_user!.uid)
          .collection("favorites")
          .doc(pair.toString())
          .set({'first': fpair, 'second': fpair2});
    }
    data = await getAllfavorites();
    notifyListeners();
  }

  Future<void> removepair(String pair) async {
    if (_status == Status.Authenticated) {
      await _firestore
          .collection("users")
          .doc(_user!.uid)
          .collection('favorites')
          .doc(pair.toString())
          .delete();
      data = await getAllfavorites();
      notifyListeners();
    }

    notifyListeners();
  }

  Future<Set<WordPair>> getAllfavorites() async {
    Set<WordPair> s = new Set<WordPair>();
    await _firestore
        .collection("users")
        .doc(_user!.uid)
        .collection('favorites')
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((result) {
        String first = result.data().entries.first.value.toString();
        String sec = result.data().entries.last.value.toString();
        s.add(WordPair(first, sec));
      });
    });
    return Future<Set<WordPair>>.value(s);
  }



  Set<WordPair> getData() {
    return data;
  }
}