import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// TODO: After running `flutterfire configure`, uncomment this import
// and pass DefaultFirebaseOptions into Firebase.initializeApp.
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        // options: DefaultFirebaseOptions.currentPlatform,
        );
  } catch (e, st) {
    runApp(_FirebaseInitErrorApp(message: e.toString(), stackTrace: st.toString()));
    return;
  }
  runApp(const MyApp());
}

/// Shown when Firebase fails to initialize (e.g. missing GoogleService-Info.plist in bundle).
class _FirebaseInitErrorApp extends StatelessWidget {
  const _FirebaseInitErrorApp({required this.message, required this.stackTrace});

  final String message;
  final String stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Firebase could not start', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(color: Colors.red)),
                if (stackTrace.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(stackTrace, style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'College & Career Checklist',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthGate(),
    );
  }
}

/// Shows either the sign-in screen or the checklist depending on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const EmailPasswordSignInScreen();
        }

        return const ChecklistScreen();
      },
    );
  }
}

/// Simple email/password sign-in + sign-up combined.
class EmailPasswordSignInScreen extends StatefulWidget {
  const EmailPasswordSignInScreen({super.key});

  @override
  State<EmailPasswordSignInScreen> createState() =>
      _EmailPasswordSignInScreenState();
}

class _EmailPasswordSignInScreenState
    extends State<EmailPasswordSignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _signInOrRegister() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        // Try sign-in first.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // If user does not exist, create them. Firebase often returns
        // invalid-credential instead of user-not-found for new users.
        final isMaybeNewUser = e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'invalid-login-credentials';
        if (isMaybeNewUser) {
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } on FirebaseAuthException catch (createE) {
            // Email already in use = user exists, wrong password.
            if (createE.code == 'email-already-in-use') {
              throw e; // Show original "invalid credential" message.
            }
            throw createE; // e.g. weak-password
          }
        } else {
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _signInOrRegister,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in / Register'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tracks which users we've already initialized (one record per item) so we don't overwrite.
final Set<String> _initializedUserChecklists = {};

/// Shows the shared checklist with per-user completion and optional URLs.
class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final itemsQuery = FirebaseFirestore.instance
        .collection('checklists')
        .doc('global')
        .collection('items')
        .snapshots();

    // Associative table: (user, checklist, checklist_item) -> completion
    const checklistId = 'global';
    final userChecklistQuery = FirebaseFirestore.instance
        .collection('user_checklist')
        .where('userId', isEqualTo: uid)
        .where('checklistId', isEqualTo: checklistId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: itemsQuery,
        builder: (context, itemsSnapshot) {
          if (itemsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (itemsSnapshot.hasError) {
            return Center(child: Text('Error: ${itemsSnapshot.error}'));
          }

          final itemsDocs = itemsSnapshot.data?.docs ?? [];
          if (itemsDocs.isEmpty) {
            final projectId = Firebase.app().options.projectId ?? '?';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No checklist items.'),
                    const SizedBox(height: 16),
                    Text(
                      'App project: $projectId',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Path: checklists → global → items',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          // Sort by order (no index required). Handle both num and string from Firestore.
          num orderValue(dynamic v) {
            if (v == null) return 0;
            if (v is num) return v;
            if (v is String) return num.tryParse(v) ?? 0;
            return 0;
          }
          itemsDocs.sort((a, b) {
            final orderA = orderValue((a.data() as Map<String, dynamic>)['order']);
            final orderB = orderValue((b.data() as Map<String, dynamic>)['order']);
            return orderA.compareTo(orderB);
          });

          return StreamBuilder<QuerySnapshot>(
            stream: userChecklistQuery.snapshots(),
            builder: (context, userChecklistSnapshot) {
              if (userChecklistSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (userChecklistSnapshot.hasError) {
                return Center(
                    child: Text('Error: ${userChecklistSnapshot.error}'));
              }

              final completionMap = <String, bool>{};
              for (final doc in userChecklistSnapshot.data?.docs ?? []) {
                final data = doc.data() as Map<String, dynamic>;
                final itemId = data['itemId'] as String?;
                if (itemId != null) {
                  completionMap[itemId] = data['isComplete'] == true;
                }
              }

              // First time this user sees the checklist: create one user_checklist doc per item (unchecked).
              final userDocs = userChecklistSnapshot.data?.docs ?? [];
              if (userDocs.isEmpty &&
                  itemsDocs.isNotEmpty &&
                  !_initializedUserChecklists.contains(uid)) {
                _initializedUserChecklists.add(uid);
                _createUserChecklistRecords(
                  uid: uid,
                  checklistId: checklistId,
                  itemIds: itemsDocs.map((d) => d.id).toList(),
                );
              }

              return ListView.builder(
                itemCount: itemsDocs.length,
                itemBuilder: (context, index) {
                  final doc = itemsDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? '';
                  final url = data['url'] as String? ?? '';
                  final isComplete = completionMap[doc.id] ?? false;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: Checkbox(
                        value: isComplete,
                        onChanged: (value) {
                          if (value == null) return;
                          _updateCompletion(
                            uid: uid,
                            checklistId: checklistId,
                            itemId: doc.id,
                            isComplete: value,
                          );
                        },
                      ),
                      title: url.isNotEmpty
                          ? InkWell(
                              onTap: () => _openUrl(url),
                              child: Text(
                                title,
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.blue,
                                ),
                              ),
                            )
                          : Text(title),
                      subtitle: null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Creates one user_checklist doc per item (isComplete: false) for a new user.
  static Future<void> _createUserChecklistRecords({
    required String uid,
    required String checklistId,
    required List<String> itemIds,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    for (final itemId in itemIds) {
      final docId = '${uid}_${checklistId}_$itemId';
      final docRef = firestore.collection('user_checklist').doc(docId);
      batch.set(docRef, {
        'userId': uid,
        'checklistId': checklistId,
        'itemId': itemId,
        'isComplete': false,
        'completedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<void> _updateCompletion({
    required String uid,
    required String checklistId,
    required String itemId,
    required bool isComplete,
  }) async {
    // Associative doc: one row per (user, checklist, checklist_item)
    final docId = '${uid}_${checklistId}_$itemId';
    final docRef = FirebaseFirestore.instance
        .collection('user_checklist')
        .doc(docId);

    await docRef.set(
      {
        'userId': uid,
        'checklistId': checklistId,
        'itemId': itemId,
        'isComplete': isComplete,
        'completedAt':
            isComplete ? FieldValue.serverTimestamp() : null,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    // Android requires a scheme (https/http) to open in browser.
    final urlWithScheme = trimmed.contains(RegExp(r'^https?://', caseSensitive: false))
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(urlWithScheme);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Emulator may have no browser; ignore so app doesn't crash.
    }
  }
}

