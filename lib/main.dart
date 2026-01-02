import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:torch_light/torch_light.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const InnovaApp());
}

class InnovaApp extends StatelessWidget {
  const InnovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Innova Ultimate',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.blueAccent,
        ),
      ),
      home: const InnovaScreen(),
    );
  }
}

class InnovaScreen extends StatefulWidget {
  const InnovaScreen({super.key});

  @override
  State<InnovaScreen> createState() => _InnovaScreenState();
}

class _InnovaScreenState extends State<InnovaScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  late AnimationController _orbController;
  final Battery _battery = Battery();

  bool _isListening = false;
  String _status = "Initializing Systems...";
  String _transcript = "";

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen awake

    // Orb Animation Setup
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    _initInnova();
  }

  @override
  void dispose() {
    _orbController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // --- INITIALIZATION ---
  Future<void> _initInnova() async {
    // Request ALL Permissions
    await [
      Permission.microphone,
      Permission.phone,
      Permission.contacts,
      Permission.camera,
      Permission.requestInstallPackages
    ].request();

    // VOICE SETTINGS: MALE / HUMAN-LIKE
    await _tts.setLanguage("en-IN");
    await _tts.setPitch(0.6); // 0.5 to 0.7 is a Male Voice range
    await _tts.setSpeechRate(0.5); // Natural speed

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) => setState(() => _status = "Tap mic to retry"),
    );

    if (available) {
      _speak("Innova Systems Online. Waiting for command.");
      _startListening();
    }
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _status = "Listening...";
      _transcript = "";
    });

    _speech.listen(
      onResult: (val) {
        setState(() => _transcript = val.recognizedWords);
        if (val.finalResult) {
          _processCommand(val.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_IN", // Indian English for Hinglish support
    );
  }

  // --- COMMAND PROCESSING ---
  Future<void> _processCommand(String cmd) async {
    String cleanCmd = cmd.toLowerCase();

    // WAKE WORD LOGIC ("Hey Innova")
    if (cleanCmd.contains("hey innova") || cleanCmd.contains("innova")) {
      String action =
          cleanCmd.replaceAll("hey innova", "").replaceAll("innova", "").trim();
      if (action.isEmpty) {
        _speak("Yes boss?");
        Future.delayed(const Duration(seconds: 1), _startListening);
      } else {
        await _execute(action);
      }
    } else {
      await _execute(cleanCmd);
    }
  }

  Future<void> _execute(String action) async {
    setState(() => _isListening = false);

    // 1. INFINITE MEMORY (Save)
    if (action.startsWith("remember") || action.startsWith("save")) {
      await _saveMemory(action);
    }
    // 2. INFINITE MEMORY (Retrieve)
    else if (action.startsWith("what is") ||
        action.startsWith("who is") ||
        action.startsWith("tell me")) {
      bool found = await _checkMemory(action);
      if (!found) {
        // If not found in memory, try standard commands
        await _executeStandardCommands(action);
      }
    } else {
      await _executeStandardCommands(action);
    }
  }

  // --- MEMORY FUNCTIONS ---
  Future<void> _saveMemory(String input) async {
    // Logic: "Remember [KEY] is [VALUE]"
    if (input.contains(" is ")) {
      List<String> parts = input.split(" is ");
      String key =
          parts[0].replaceFirst("remember", "").replaceFirst("save", "").trim();
      String value = parts[1].trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
        _speak("I have saved that $key is $value.");
      }
    } else {
      _speak("Please say it like: Remember X is Y.");
    }
  }

  Future<bool> _checkMemory(String input) async {
    // Logic: Checks if we have a saved answer for the question
    String searchKey = input
        .replaceFirst("what is", "")
        .replaceFirst("who is", "")
        .replaceFirst("tell me about", "")
        .replaceFirst("tell me", "")
        .trim();

    final prefs = await SharedPreferences.getInstance();

    // Fuzzy Search in Memory
    Set<String> keys = prefs.getKeys();
    for (String k in keys) {
      if (searchKey.contains(k) || k.contains(searchKey)) {
        String? value = prefs.getString(k);
        _speak(value ?? "Data error");
        return true;
      }
    }
    return false;
  }

  // --- GOD MODE FUNCTIONS ---
  Future<void> _executeStandardCommands(String action) async {
    // 1. FLASHLIGHT
    if (action.contains("torch") ||
        action.contains("light") ||
        action.contains("batti")) {
      try {
        if (action.contains("on") || action.contains("jalao")) {
          await TorchLight.enableTorch();
          _speak("Light On");
        } else {
          await TorchLight.disableTorch();
          _speak("Light Off");
        }
      } catch (e) {
        _speak("Torch not available.");
      }
    }
    // 2. BATTERY
    else if (action.contains("battery") || action.contains("charge")) {
      var level = await _battery.batteryLevel;
      _speak("Battery is at $level percent.");
    }
    // 3. SETTINGS
    else if (action.contains("setting") ||
        action.contains("wifi") ||
        action.contains("bluetooth")) {
      _speak("Opening Settings");
      if (action.contains("wifi"))
        await const AndroidIntent(action: 'android.settings.WIFI_SETTINGS')
            .launch();
      else if (action.contains("bluetooth"))
        await const AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS')
            .launch();
      else
        await const AndroidIntent(action: 'android.settings.SETTINGS').launch();
    }
    // 4. SOCIAL APPS
    else if (action.contains("instagram")) {
      await LaunchApp.openApp(androidPackageName: 'com.instagram.android');
    } else if (action.contains("snapchat")) {
      await LaunchApp.openApp(androidPackageName: 'com.snapchat.android');
    } else if (action.contains("telegram")) {
      await LaunchApp.openApp(androidPackageName: 'org.telegram.messenger');
    } else if (action.contains("youtube")) {
      await LaunchApp.openApp(androidPackageName: 'com.google.android.youtube');
    }
    // 5. WHATSAPP
    else if (action.contains("whatsapp") || action.contains("msg")) {
      await _handleWhatsApp(action);
    }
    // 6. CALLING
    else if (action.contains("call") || action.contains("phone")) {
      await _handleCall(action);
    }
    // 7. VISUAL SEARCH (Circle to Search)
    else if (action.contains("search this") || action.contains("lens")) {
      _openVisualSearch();
    }
    // 8. OPEN ANY APP
    else if (action.contains("open")) {
      String app = action.replaceFirst("open", "").trim();
      _speak("Opening $app");
      await launchUrl(Uri.parse("https://www.google.com/search?q=$app"));
    } else {
      _speak(
          "I don't know that yet. You can teach me by saying Remember X is Y.");
    }
  }

  // --- HELPER HANDLERS ---
  Future<void> _handleWhatsApp(String action) async {
    _speak("Searching contacts...");
    List<String> words = action.split(" ");
    String nameToFind = "";
    String message = "";

    int toIndex = words.indexOf("to");
    if (toIndex != -1 && toIndex + 1 < words.length) {
      nameToFind = words[toIndex + 1];
      if (toIndex + 2 < words.length) {
        message = words.sublist(toIndex + 2).join(" ");
      }
    }

    if (nameToFind.isNotEmpty) {
      String? number = await _findContact(nameToFind);
      if (number != null) {
        _speak("Messaging $nameToFind");
        String url =
            "https://wa.me/$number?text=${Uri.encodeComponent(message)}";
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _speak("Contact $nameToFind not found.");
      }
    } else {
      await LaunchApp.openApp(androidPackageName: 'com.whatsapp');
    }
  }

  Future<void> _handleCall(String action) async {
    String digits = action.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 3) {
      await launchUrl(Uri.parse("tel:$digits"));
      return;
    }
    List<String> words = action.split(" ");
    for (var word in words) {
      if (word.length < 3) continue;
      String? num = await _findContact(word);
      if (num != null) {
        _speak("Calling $word");
        await launchUrl(Uri.parse("tel:$num"));
        return;
      }
    }
    _speak("Contact not found.");
  }

  Future<String?> _findContact(String query) async {
    try {
      List<Contact> contacts =
          await FlutterContacts.getContacts(withProperties: true);
      for (var c in contacts) {
        if (c.displayName.toLowerCase().contains(query.toLowerCase())) {
          if (c.phones.isNotEmpty) return c.phones.first.number;
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _openVisualSearch() async {
    _speak("Opening Visual Lens");
    try {
      await launchUrl(Uri.parse("google.lens://"),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(Uri.parse("https://lens.google.com/"),
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _speak(String text) async {
    setState(() => _status = text);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF000000), Color(0xFF1a1a2e)],
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // ORB
                GestureDetector(
                  onTap: _startListening,
                  child: AnimatedBuilder(
                    animation: _orbController,
                    builder: (context, child) {
                      return Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(
                                color: _isListening
                                    ? Colors.cyanAccent
                                    : Colors.grey.shade800,
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                        ? Colors.cyanAccent
                                        : Colors.blue)
                                    .withOpacity(0.5),
                                blurRadius: 30 + (_orbController.value * 25),
                                spreadRadius: 5 + (_orbController.value * 5),
                              )
                            ]),
                        child: Icon(
                          _isListening ? Icons.graphic_eq : Icons.mic_none,
                          color: Colors.white,
                          size: 70,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 50),

                // TEXT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _transcript.isEmpty ? _status : _transcript,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent.withOpacity(0.9),
                    ),
                  ),
                ),

                const Spacer(),

                // VISUAL SEARCH BUTTON
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton.icon(
                    onPressed: _openVisualSearch,
                    icon: const Icon(Icons.image_search),
                    label: const Text("Visual Lens"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Text(
                    "Long Press Home to Wake Innova",
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
                "Long Press Home to Wake Innova",
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
