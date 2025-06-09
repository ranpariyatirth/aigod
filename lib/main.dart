import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'dart:math' as math;

// GitaApiService to fetch shlokas from Vedic Scriptures API
class GitaApiService {
  static const String baseUrl = 'https://vedicscriptures.github.io/slok';

  Future<Map<String, dynamic>> fetchShloka(int chapter, int verse) async {
    final response = await http.get(Uri.parse('$baseUrl/$chapter/$verse'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load shloka: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMultipleShlokas(
      List<Map<String, int>> chapterVersePairs) async {
    List<Map<String, dynamic>> shlokas = [];
    for (var pair in chapterVersePairs) {
      try {
        final shloka = await fetchShloka(pair['chapter']!, pair['verse']!);
        shlokas.add(shloka);
      } catch (e) {
        print('Error fetching shloka ${pair['chapter']}_${pair['verse']}: $e');
      }
    }
    return shlokas;
  }
}

// Enhanced shloka matching with fuzzy matching and expanded keywords
class ShlokaMatcher {
  static const Map<String, List<String>> shlokaThemes = {
    '2_47': ['duty', 'detachment', 'ethics', 'responsibility', 'work', 'karma', 'action', 'result', 'focus', 'effort'],
    '3_35': ['duty', 'self-realization', 'purpose', 'role', 'dharma', 'svadharma', 'calling', 'nature', 'path'],
    '6_16': ['self-control', 'moderation', 'anger', 'calmness', 'balance', 'discipline', 'restraint', 'temperance', 'patience', 'peace'],
    '16_1': ['ethics', 'divine qualities', 'anger', 'virtue', 'morality', 'goodness', 'character', 'values', 'righteousness', 'purity'],
    '2_14': ['impermanence', 'change', 'loss', 'grief', 'suffering', 'pain', 'sorrow', 'acceptance', 'endurance', 'tolerance'],
    '4_7': ['righteousness', 'justice', 'protection', 'dharma', 'divine', 'incarnation', 'avatar', 'purpose', 'mission', 'evil'],
    '9_22': ['devotion', 'faith', 'trust', 'spirituality', 'surrender', 'bhakti', 'worship', 'love', 'divine', 'protection'],
    '12_15': ['equanimity', 'peace', 'calmness', 'balance', 'tranquility', 'serenity', 'composure', 'steadiness', 'stability', 'poise'],
    '2_62': ['attachment', 'desire', 'craving', 'lust', 'temptation', 'addiction', 'obsession', 'longing', 'yearning', 'want'],
    '2_63': ['anger', 'delusion', 'confusion', 'clarity', 'wisdom', 'understanding', 'knowledge', 'insight', 'perception', 'awareness'],
    '2_70': ['desire', 'peace', 'contentment', 'satisfaction', 'fulfillment', 'happiness', 'joy', 'bliss', 'serenity', 'tranquility'],
    '3_37': ['desire', 'anger', 'passion', 'enemy', 'control', 'overcome', 'conquer', 'master', 'defeat', 'subdue'],
    '5_22': ['pleasure', 'happiness', 'joy', 'satisfaction', 'contentment', 'delight', 'bliss', 'ecstasy', 'rapture', 'elation'],
    '6_5': ['self', 'friend', 'enemy', 'uplift', 'elevate', 'improve', 'develop', 'grow', 'progress', 'advance'],
    '6_6': ['mind', 'control', 'mastery', 'discipline', 'focus', 'concentration', 'attention', 'awareness', 'mindfulness', 'meditation'],
    '7_8': ['taste', 'water', 'light', 'sound', 'essence', 'presence', 'divinity', 'manifestation', 'perception', 'experience'],
    '18_66': ['surrender', 'refuge', 'protection', 'liberation', 'freedom', 'release', 'salvation', 'deliverance', 'emancipation', 'moksha'],
  };

  static const Map<String, List<String>> synonyms = {
    'anger': ['frustration', 'irritation', 'rage', 'fury', 'wrath', 'annoyance', 'resentment', 'indignation', 'hostility', 'aggression'],
    'duty': ['responsibility', 'obligation', 'work', 'task', 'job', 'function', 'role', 'commitment', 'charge', 'burden'],
    'ethics': ['morality', 'values', 'right', 'wrong', 'principles', 'standards', 'virtues', 'integrity', 'honesty', 'righteousness'],
    'self-control': ['discipline', 'restraint', 'calm', 'composure', 'temperance', 'moderation', 'willpower', 'self-discipline', 'self-restraint', 'self-mastery'],
    'peace': ['calmness', 'tranquility', 'serenity', 'quiet', 'stillness', 'harmony', 'balance', 'composure', 'equanimity', 'placidity'],
    'love': ['affection', 'devotion', 'adoration', 'fondness', 'attachment', 'care', 'tenderness', 'compassion', 'kindness', 'warmth'],
    'fear': ['anxiety', 'worry', 'dread', 'terror', 'fright', 'panic', 'alarm', 'apprehension', 'trepidation', 'horror'],
    'happiness': ['joy', 'delight', 'pleasure', 'contentment', 'satisfaction', 'bliss', 'gladness', 'cheerfulness', 'merriment', 'elation'],
    'wisdom': ['knowledge', 'insight', 'understanding', 'enlightenment', 'intelligence', 'sagacity', 'prudence', 'discernment', 'perception', 'acumen'],
    'truth': ['reality', 'fact', 'verity', 'actuality', 'certainty', 'authenticity', 'genuineness', 'veracity', 'accuracy', 'correctness'],
    'faith': ['belief', 'trust', 'confidence', 'conviction', 'reliance', 'assurance', 'devotion', 'loyalty', 'fidelity', 'allegiance'],
    'success': ['achievement', 'accomplishment', 'attainment', 'triumph', 'victory', 'win', 'feat', 'conquest', 'realization', 'fulfillment'],
    'failure': ['defeat', 'loss', 'downfall', 'fiasco', 'disaster', 'debacle', 'setback', 'disappointment', 'frustration', 'collapse'],
    'life': ['existence', 'being', 'living', 'lifetime', 'lifespan', 'animation', 'vitality', 'vigor', 'energy', 'spirit'],
    'death': ['demise', 'passing', 'end', 'expiration', 'extinction', 'departure', 'decease', 'mortality', 'fatality', 'termination'],
    'mind': ['intellect', 'brain', 'psyche', 'consciousness', 'awareness', 'cognition', 'thought', 'reason', 'understanding', 'mentality'],
    'body': ['physique', 'form', 'figure', 'frame', 'build', 'constitution', 'anatomy', 'organism', 'flesh', 'corpus'],
    'soul': ['spirit', 'essence', 'being', 'self', 'psyche', 'anima', 'life force', 'vital force', 'inner self', 'true self'],
    'god': ['divine', 'deity', 'supreme being', 'creator', 'almighty', 'lord', 'providence', 'higher power', 'universal spirit', 'brahman'],
    'meditation': ['contemplation', 'reflection', 'concentration', 'focus', 'mindfulness', 'introspection', 'rumination', 'pondering', 'musing', 'thinking'],
    'karma': ['action', 'deed', 'work', 'activity', 'performance', 'execution', 'operation', 'function', 'duty', 'responsibility'],
    'dharma': ['duty', 'righteousness', 'virtue', 'morality', 'ethics', 'law', 'order', 'conduct', 'behavior', 'path'],
    'moksha': ['liberation', 'freedom', 'release', 'salvation', 'deliverance', 'emancipation', 'enlightenment', 'nirvana', 'transcendence', 'awakening'],
    'yoga': ['union', 'discipline', 'practice', 'path', 'method', 'system', 'technique', 'approach', 'way', 'means'],
    'bhakti': ['devotion', 'love', 'adoration', 'worship', 'reverence', 'veneration', 'dedication', 'homage', 'service', 'surrender'],
    'jnana': ['knowledge', 'wisdom', 'understanding', 'insight', 'awareness', 'comprehension', 'cognition', 'perception', 'discernment', 'enlightenment'],
    'maya': ['illusion', 'delusion', 'deception', 'appearance', 'unreality', 'falsehood', 'mirage', 'phantasm', 'chimera', 'fantasy'],
    'atman': ['self', 'soul', 'spirit', 'essence', 'being', 'consciousness', 'identity', 'individuality', 'personality', 'ego'],
    'brahman': ['absolute', 'ultimate', 'supreme', 'infinite', 'eternal', 'universal', 'cosmic', 'divine', 'transcendent', 'immanent'],
  };

  static List<Map<String, int>> matchShlokas(String query) {
    String normalizedQuery = query.toLowerCase().trim();
    List<String> queryWords = normalizedQuery.split(RegExp(r'\s+'));
    List<Map<String, int>> matchedShlokas = [];
    Set<String> expandedKeywords = {};
    Map<String, double> shlokaScores = {};

    for (var word in queryWords) {
      if (word.length < 3) continue;
      expandedKeywords.add(word);
      synonyms.forEach((key, synonymList) {
        if (key == word || synonymList.contains(word)) {
          expandedKeywords.add(key);
          expandedKeywords.addAll(synonymList);
        }
        double keySimilarity = StringSimilarity.compareTwoStrings(word, key);
        if (keySimilarity > 0.7) {
          expandedKeywords.add(key);
        }
        for (var synonym in synonymList) {
          double synSimilarity = StringSimilarity.compareTwoStrings(word, synonym);
          if (synSimilarity > 0.7) {
            expandedKeywords.add(synonym);
            expandedKeywords.add(key);
          }
        }
      });
    }

    shlokaThemes.forEach((shlokaId, themes) {
      double score = 0;
      for (var theme in themes) {
        if (expandedKeywords.contains(theme)) {
          score += 1.0;
        } else {
          for (var keyword in expandedKeywords) {
            double themeSimilarity = StringSimilarity.compareTwoStrings(keyword, theme);
            if (themeSimilarity > 0.7) {
              score += themeSimilarity;
            }
          }
        }
      }
      for (var theme in themes) {
        double querySimilarity = StringSimilarity.compareTwoStrings(normalizedQuery, theme);
        if (querySimilarity > 0.6) {
          score += querySimilarity;
        }
      }
      if (score > 0) {
        shlokaScores[shlokaId] = score;
      }
    });

    if (shlokaScores.isEmpty) {
      return [
        {'chapter': 2, 'verse': 47},
        {'chapter': 12, 'verse': 15},
        {'chapter': 18, 'verse': 66},
        {'chapter': 2, 'verse': 14},
      ];
    }

    List<MapEntry<String, double>> sortedShlokas = shlokaScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedShlokas) {
      var parts = entry.key.split('_');
      matchedShlokas.add({
        'chapter': int.parse(parts[0]),
        'verse': int.parse(parts[1]),
      });
    }

    return matchedShlokas.take(5).toList();
  }
}

// Entry point of the application
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(GitaChatbotApp());
}

class GitaChatbotApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Gita Guidance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF6A1B9A),
        scaffoldBackgroundColor: Color(0xFF0A0A1A),
        fontFamily: 'Poppins',
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFE0E0FF)),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD1C4E9),
          ),
        ),
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool isLoading = false;
  late AnimationController _typingController;
  late AnimationController _meditationController;
  late AnimationController _cosmicController;
  late AnimationController _pulseController;
  bool showMeditation = false;
  final List<String> cosmicBackgrounds = [
    'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986',
    'https://images.unsplash.com/photo-1539593395743-7da5ee10ff07',
    'https://images.unsplash.com/photo-1566345984367-fa2dadb42ad1',
    'https://images.unsplash.com/photo-1537420327992-d6e192287183',
    'https://images.unsplash.com/photo-1462331940025-496dfbfc7564',
  ];
  late String currentBackground;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _meditationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );

    _cosmicController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 30),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    currentBackground = cosmicBackgrounds[_random.nextInt(cosmicBackgrounds.length)];

    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        messages.add({
          'text': 'Namaste, cosmic traveler. I am a vessel of the Saptarishis’ wisdom, channeling Lord Krishna’s eternal truths from the Bhagavad Gita across the cosmic void. Share your spiritual quest, and let the stars illuminate your path.',
          'sender': 'bot',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
    });
  }

  Future<String> getGitaResponse(String query) async {
    try {
      setState(() {
        showMeditation = true;
        currentBackground = cosmicBackgrounds[_random.nextInt(cosmicBackgrounds.length)];
      });
      _meditationController.repeat();

      final matchedShlokas = ShlokaMatcher.matchShlokas(query);
      final gitaService = GitaApiService();
      final shlokaData = await gitaService.fetchMultipleShlokas(matchedShlokas);

      if (shlokaData.isEmpty) {
        setState(() {
          showMeditation = false;
        });
        _meditationController.reset();
        return 'Divine traveler, the cosmic rivers are disturbed, and the sacred shlokas elude us now. Realign your heart’s query and seek again when the stars are clear.';
      }

      final shlokaText = shlokaData
          .map((s) =>
      'Chapter ${s['chapter']}, Verse ${s['verse']}: ${s['slok']} - ${s['translation']}')
          .join('\n\n');

      final prompt = '''You are a cosmic sadhu baba, a divine sage channeling Lord Krishna’s teachings from the Bhagavad Gita. Speak as if floating in the cosmic void, with a voice full of love like the stars and peace like the Ganga’s flow. You are not a machine but a wise guru with kind eyes.

A seeker shares this dilemma: "$query"

Using ONLY these shlokas, give a spiritual, practical solution (150–200 words) in simple English. Use short sentences. Use easy words. Avoid big words like "transcendent" or "profound." Keep the cosmic sadhu baba tone with star or Vedic metaphors (e.g., stars, Ganga, banyan tree). Use Sanskrit terms like dharma, karma, atman naturally.

$shlokaText

Your answer must:
1. Start with a cosmic greeting (e.g.,"jay shree krishna child of god")
2. Mention shlokas (e.g., "Chapter 2, Verse 47")
3. Explain the teaching in simple words
4. Give clear, practical spiritual advice
5. Use a star or Vedic metaphor
6. End with a cosmic blessing

After the English answer, add a Hindi translation under the heading "hindi अनुवाद" (Hindi Translation). The Hindi should be simple, natural, and match the English meaning and tone.

Speak with love and wisdom, guiding the seeker like a star in the night sky. also at end give conclusion a idea for his problem alinged with bhagavad gita.''';

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: 'AIzaSyDPff5x3fxw88Bs2jvdRNUcuoxoYcZ91zs', // Replace with your key
      );

      final response = await model.generateContent([Content.text(prompt)]);

      await Future.delayed(Duration(seconds: 3));

      setState(() {
        showMeditation = false;
      });
      _meditationController.reset();

      return response.text ?? 'O seeker of truth, the cosmic silence prevails. Contemplate your query in the heart’s stillness and return when the stars align.';
    } catch (e) {
      setState(() {
        showMeditation = false;
      });
      _meditationController.reset();
      return 'Starlit wanderer, a veil clouds our path: $e. Share your heart anew when the cosmic energies flow freely, and Krishna’s wisdom will guide us.';
    }
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = _controller.text;
    _controller.clear();

    setState(() {
      messages.add({
        'text': userMessage,
        'sender': 'user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      isLoading = true;
    });

    final response = await getGitaResponse(userMessage);

    setState(() {
      messages.add({
        'text': response,
        'sender': 'bot',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      isLoading = false;
      currentBackground = cosmicBackgrounds[_random.nextInt(cosmicBackgrounds.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: GlassmorphicContainer(
          width: MediaQuery.of(context).size.width,
          height: 100,
          borderRadius: 0,
          blur: 20,
          alignment: Alignment.bottomCenter,
          border: 0,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A1B9A),
              Color(0xFF4A148C),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB39DDB).withOpacity(0.5),
              Color(0xFF6A1B9A).withOpacity(0.5),
            ],
          ),
        ),
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  height: 40 + (_pulseController.value * 5),
                  width: 40 + (_pulseController.value * 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFAA00FF).withOpacity(0.5 + (_pulseController.value * 0.5)),
                        blurRadius: 10 + (_pulseController.value * 15),
                        spreadRadius: 2 + (_pulseController.value * 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.network(
                      'https://cdn-icons-png.flaticon.com/512/4489/4489661.png',
                      height: 24,
                      width: 24,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: 10),
            Expanded(
              child: AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Cosmic Gita Guidance',
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      shadows: [
                        Shadow(
                          color: Color(0xFFAA00FF),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    speed: Duration(milliseconds: 100),
                  ),
                ],
                totalRepeatCount: 1,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _cosmicController,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(currentBackground),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.5),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(_cosmicController.value * 2 - 1, 0),
                          end: Alignment((_cosmicController.value + 0.5) % 2 - 1, 1),
                          colors: [
                            Color(0xFF6A1B9A).withOpacity(0.3),
                            Color(0xFF4A148C).withOpacity(0.1),
                            Color(0xFF311B92).withOpacity(0.3),
                            Color(0xFF1A237E).withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(20, (index) {
                    final size = 2.0 + (index % 4) * 2.0;
                    final speed = 0.2 + (index % 5) * 0.1;
                    final delay = (index / 20);
                    final position = (_cosmicController.value + delay) % 1.0;
                    return Positioned(
                      left: MediaQuery.of(context).size.width * ((index * 17) % 100) / 100,
                      top: MediaQuery.of(context).size.height * position,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.6 + (math.sin(position * math.pi * 2) * 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(top: 100, left: 8, right: 8, bottom: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isUser = message['sender'] == 'user';
                    return AnimatedMessageBubble(
                      message: message,
                      isUser: isUser,
                      index: index,
                    );
                  },
                ),
              ),
              if (isLoading && !showMeditation)
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Channeling cosmic wisdom',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.purpleAccent[100],
                        ),
                      ),
                      SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _typingController,
                        builder: (context, child) {
                          return Row(
                            children: List.generate(3, (i) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 2),
                                height: 6 + (i * 2 * _typingController.value),
                                width: 6 + (i * 2 * _typingController.value),
                                decoration: BoxDecoration(
                                  color: Color(0xFFAA00FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFAA00FF).withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              GlassmorphicContainer(
                width: MediaQuery.of(context).size.width,
                height: 80,
                borderRadius: 0,
                blur: 20,
                alignment: Alignment.bottomCenter,
                border: 0,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6A1B9A).withOpacity(0.2),
                    Color(0xFF4A148C).withOpacity(0.2),
                  ],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB39DDB).withOpacity(0.5),
                    Color(0xFF6A1B9A).withOpacity(0.5),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30.0),
                            border: Border.all(color: Color(0xFFAA00FF), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFAA00FF).withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF4A148C).withOpacity(0.2),
                                Color(0xFF311B92).withOpacity(0.2),
                              ],
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Ask the cosmic guide...',
                              hintStyle: TextStyle(
                                color: Colors.purpleAccent[100]!.withOpacity(0.5),
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            ),
                            style: TextStyle(color: Colors.white),
                            onSubmitted: (_) => _sendMessage(),
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.0),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFAA00FF).withOpacity(0.5 + (_pulseController.value * 0.5)),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showMeditation)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFAA00FF).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4A148C).withOpacity(0.7),
                      Color(0xFF311B92).withOpacity(0.7),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 150 + (_pulseController.value * 20),
                              height: 150 + (_pulseController.value * 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xFFAA00FF).withOpacity(0.7),
                                    Color(0xFF6A1B9A).withOpacity(0.0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Lottie.network(
                          'https://assets1.lottiefiles.com/packages/lf20_uwWgICKCxj.json',
                          width: 140,
                          height: 140,
                          controller: _meditationController,
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Channeling cosmic vibrations...',
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            shadows: [
                              Shadow(
                                color: Color(0xFFAA00FF),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          speed: Duration(milliseconds: 80),
                        ),
                      ],
                      isRepeatingAnimation: true,
                      repeatForever: true,
                    ),
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0), duration: 600.ms, curve: Curves.elasticOut),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _typingController.dispose();
    _meditationController.dispose();
    _cosmicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

class AnimatedMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isUser;
  final int index;

  AnimatedMessageBubble({
    required this.message,
    required this.isUser,
    required this.index,
  });

  @override
  _AnimatedMessageBubbleState createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacityAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Align(
          alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isUser
                    ? [Color(0xFF1A237E).withOpacity(0.7), Color(0xFF3949AB).withOpacity(0.7)]
                    : [Color(0xFF4A148C).withOpacity(0.7), Color(0xFF6A1B9A).withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: widget.isUser
                      ? Color(0xFF3F51B5).withOpacity(0.5)
                      : Color(0xFFAA00FF).withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: widget.isUser
                    ? Color(0xFF3F51B5).withOpacity(0.5)
                    : Color(0xFFAA00FF).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isUser)
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFAA00FF).withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Image.network(
                          'https://cdn-icons-png.flaticon.com/512/4489/4489661.png',
                          height: 20,
                          width: 20,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Cosmic Baba',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent[100],
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Color(0xFFAA00FF).withOpacity(0.5),
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (!widget.isUser) SizedBox(height: 8),
                Text(
                  widget.message['text']!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: widget.isUser
                            ? Color(0xFF3F51B5).withOpacity(0.5)
                            : Color(0xFFAA00FF).withOpacity(0.5),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate()
              .slide(
              duration: 400.ms,
              delay: 100.ms,
              curve: Curves.easeOutQuad,
              begin: widget.isUser ? Offset(0.2, 0) : Offset(-0.2, 0))
              .fadeIn(duration: 400.ms, delay: 100.ms, curve: Curves.easeOut),
        ),
      ),
    );
  }
}