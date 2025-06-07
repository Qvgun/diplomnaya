import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fl_chart/fl_chart.dart';

// --- Новая модель для ИИ-подсказок ---
class MealSuggestion {
  final String name;
  final double calories;
  final double proteins;
  final double fats;
  final double carbs;
  final double grams;

  MealSuggestion({
    required this.name,
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
    required this.grams,
  });

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    return MealSuggestion(
      name: json['name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      proteins: (json['proteins'] as num?)?.toDouble() ?? 0.0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      grams: (json['grams'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

// --- Gemini Suggestion Service ---
class GeminiSuggestionService {
  static final GeminiSuggestionService instance = GeminiSuggestionService._init();
  GeminiSuggestionService._init();

  final String _apiKey = 'AIzaSyB5-jOWU5IZzw1uOWk5gZI0HSQnvs_u6-4';
  final String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  Future<List<MealSuggestion>> getMealSuggestions(String query) async {
    if (_apiKey.startsWith('YOUR_API_KEY')) {
      print("API ключ не установлен.");
      throw Exception('API ключ не настроен.');
    }

    final prompt = """
    Пользователь ищет продукт или блюдо и вводит '$query'. 
    Предложи до 7 релевантных вариантов, которые являются съедобными продуктами или блюдами. 
    Если запрос не похож на еду (например, "машина", "ботинки"), верни пустой список [].
    Для каждого варианта предоставь примерные значения калорий, белков, жиров, углеводов и стандартный вес порции в граммах.
    Ответ дай в виде списка JSON-объектов. Каждый объект должен содержать поля: "name", "calories", "proteins", "fats", "carbs", "grams".
    Пример:
    [
      {"name": "Куриная грудка отварная", "calories": 150, "proteins": 30, "fats": 3, "carbs": 0, "grams": 100}
    ]
    Не добавляй ничего лишнего, только список JSON.
    """;

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}]
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        if (body['candidates'] == null || (body['candidates'] as List).isEmpty) {
          print("Ответ от Gemini не содержит 'candidates'. Возможно, сработал защитный фильтр.");
          return [];
        }

        final content = body['candidates'][0]['content']['parts'][0]['text'] as String;

        try {
          final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```|([\s\S]*)');
          final match = jsonRegex.firstMatch(content);
          String cleanedContent = (match?.group(1) ?? match?.group(2) ?? '').trim();

          if (cleanedContent.isEmpty) {
            return [];
          }

          final List<dynamic> suggestionsJson = jsonDecode(cleanedContent);
          return suggestionsJson.map((json) => MealSuggestion.fromJson(json)).toList();
        } catch (e) {
          print("Ошибка парсинга JSON ответа от Gemini: $e");
          print("Неочищенный ответ от Gemini: $content");
          throw Exception('Не удалось обработать ответ от ИИ.');
        }

      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']['message'] as String? ?? 'Неизвестная ошибка API';
        print('Ошибка Gemini API: ${response.statusCode}');
        print('Сообщение: $errorMessage');

        if (errorMessage.contains("User location is not supported")) {
          throw Exception('API не доступен в вашем регионе. Пожалуйста, используйте VPN.');
        }
        if (response.statusCode == 429 || errorMessage.contains("RESOURCE_EXHAUSTED")) {
          throw Exception('Превышен лимит запросов. Попробуйте через минуту.');
        }
        throw Exception('Ошибка API: $errorMessage');
      }
    } catch (e) {
      print('Исключение при запросе к Gemini API: $e');
      throw Exception('Ошибка сети. Проверьте подключение к интернету и VPN.');
    }
  }
}

// Данные для мотиваторов
final List<Map<String, String>> motivatorData = [
  {
    "image": "assets/images/motivator1.png",
    "title": "Поддерживай водный баланс",
    "subtitle": "Правильная гидратация — ключ к здоровью и энергии.",
  },
  {
    "image": "assets/images/motivator2.png",
    "title": "Движение — это жизнь",
    "subtitle": "Добавь активности, и результат не заставит себя ждать.",
  },
  {
    "image": "assets/images/motivator3.png",
    "title": "Выбирай осознанно",
    "subtitle": "Наполни свою тарелку яркими и полезными продуктами.",
  },
  {
    "image": "assets/images/motivator4.png",
    "title": "Найди гармонию с собой",
    "subtitle": "Здоровое тело начинается со спокойного ума.",
  },
];

// --- Модели данных ---
class UserProfileModel {
  int? id;
  String name;
  double weight;
  double height;
  double? bmi;
  String? bmiInterpretation;
  String? registrationDate;

  UserProfileModel({
    this.id,
    required this.name,
    required this.weight,
    required this.height,
    this.bmi,
    this.bmiInterpretation,
    this.registrationDate,
  });

  void calculateBmi() {
    if (height > 0 && weight > 0) {
      double heightInMeters = height / 100.0;
      bmi = weight / (heightInMeters * heightInMeters);
      if (bmi != null && bmi!.isFinite) {
        bmi = double.parse(bmi!.toStringAsFixed(1));

        if (bmi! < 18.5) {
          bmiInterpretation = "Ниже нормального веса";
        } else if (bmi! >= 18.5 && bmi! < 25) {
          bmiInterpretation = "Нормальный вес";
        } else if (bmi! >= 25 && bmi! < 30) {
          bmiInterpretation = "Избыточная масса тела (предожирение)";
        } else if (bmi! >= 30 && bmi! < 35) {
          bmiInterpretation = "Ожирение I степени";
        } else if (bmi! >= 35 && bmi! < 40) {
          bmiInterpretation = "Ожирение II степени";
        } else {
          bmiInterpretation = "Ожирение III степени";
        }
      } else {
        bmi = null;
        bmiInterpretation = "Невозможно рассчитать ИМТ";
      }
    } else {
      bmi = null;
      bmiInterpretation = "Некорректные данные для расчета ИМТ";
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'height': height,
      'weightForBmi': weight,
      'bmi': bmi,
      'date': registrationDate ?? DateTime.now().toIso8601String(),
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    UserProfileModel profile = UserProfileModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      height: map['height'] as double,
      weight: map['weightForBmi'] as double,
      bmi: map['bmi'] as double?,
      registrationDate: map['date'] as String?,
    );
    if (profile.weight > 0 && profile.height > 0) {
      profile.calculateBmi();
    }
    return profile;
  }

  UserProfileModel copyWith({
    int? id,
    String? name,
    double? weight,
    double? height,
    double? bmi,
    String? bmiInterpretation,
    String? registrationDate,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bmi: bmi ?? this.bmi,
      bmiInterpretation: bmiInterpretation ?? this.bmiInterpretation,
      registrationDate: registrationDate ?? this.registrationDate,
    );
  }
}

class MealModel {
  int? id;
  int? userId;
  String nameOfFood;
  double proteins;
  double fats;
  double carbs;
  double calories;
  double grams;
  String date;
  int mealNumber;

  MealModel({
    this.id,
    this.userId,
    required this.nameOfFood,
    required this.proteins,
    required this.fats,
    required this.carbs,
    required this.calories,
    required this.grams,
    required this.date,
    required this.mealNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameId': userId,
      'nameOfFood': nameOfFood,
      'proteins': proteins,
      'fats': fats,
      'carbs': carbs,
      'calories': calories,
      'grams': grams,
      'date': date,
      'mealNumber': mealNumber,
    };
  }

  factory MealModel.fromMap(Map<String, dynamic> map) {
    return MealModel(
      id: map['id'] as int?,
      userId: map['nameId'] as int?,
      nameOfFood: map['nameOfFood'] as String,
      proteins: map['proteins'] as double,
      fats: map['fats'] as double,
      carbs: map['carbs'] as double,
      calories: map['calories'] as double,
      grams: map['grams'] as double,
      date: map['date'] as String,
      mealNumber: map['mealNumber'] as int,
    );
  }
}

class WeightEntryModel {
  int? id;
  int? userId;
  double weight;
  String date;

  WeightEntryModel({
    this.id,
    this.userId,
    required this.weight,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameId': userId,
      'weight': weight,
      'date': date,
    };
  }

  factory WeightEntryModel.fromMap(Map<String, dynamic> map) {
    return WeightEntryModel(
      id: map['id'] as int?,
      userId: map['nameId'] as int?,
      weight: map['weight'] as double,
      date: map['date'] as String,
    );
  }
}

// --- Database Helper ---
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('calories_counter_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE profile (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      height REAL NOT NULL,
      weightForBmi REAL NOT NULL,
      bmi REAL,
      date TEXT
    )
    ''');
    await db.execute('''
    CREATE TABLE meals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nameId INTEGER,
      nameOfFood TEXT NOT NULL,
      proteins REAL NOT NULL,
      fats REAL NOT NULL,
      carbs REAL NOT NULL,
      calories REAL NOT NULL,
      grams REAL NOT NULL,
      date TEXT NOT NULL,
      mealNumber INTEGER NOT NULL,
      FOREIGN KEY (nameId) REFERENCES profile (id) ON DELETE CASCADE
    )
    ''');
    await db.execute('''
    CREATE TABLE weight_tracker (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nameId INTEGER,
      weight REAL NOT NULL,
      date TEXT NOT NULL,
      FOREIGN KEY (nameId) REFERENCES profile (id) ON DELETE CASCADE
    )
    ''');
    print("Database and tables created!");
  }

  Future<UserProfileModel> createUserProfile(UserProfileModel profile) async {
    final db = await instance.database;
    profile.registrationDate = DateTime.now().toIso8601String();
    if (profile.weight > 0 && profile.height > 0) {
      profile.calculateBmi();
    }
    final id = await db.insert('profile', profile.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
    profile.id = id;
    return profile;
  }

  Future<List<UserProfileModel>> getAllUserProfiles() async {
    final db = await instance.database;
    final maps = await db.query('profile', orderBy: 'name ASC');
    if (maps.isNotEmpty) {
      return maps.map((map) => UserProfileModel.fromMap(map)).toList();
    } else {
      return [];
    }
  }

  Future<UserProfileModel?> getUserProfileById(int id) async {
    final db = await instance.database;
    final maps = await db.query('profile', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return UserProfileModel.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateUserProfile(UserProfileModel profile) async {
    final db = await instance.database;
    if (profile.weight > 0 && profile.height > 0) {
      profile.calculateBmi();
    }
    return db.update('profile', profile.toMap(), where: 'id = ?', whereArgs: [profile.id]);
  }

  Future<int> deleteUserProfile(int id) async {
    final db = await instance.database;
    return db.delete('profile', where: 'id = ?', whereArgs: [id]);
  }

  Future<MealModel> createMeal(MealModel meal) async {
    final db = await instance.database;
    Map<String, dynamic> mealMap = meal.toMap();
    if (mealMap['id'] == null) mealMap.remove('id');
    final id = await db.insert('meals', mealMap);
    meal.id = id;
    return meal;
  }

  Future<List<MealModel>> getMealsByDateAndUser(String date, int userId) async {
    final db = await instance.database;
    final maps = await db.query('meals', where: 'date = ? AND nameId = ?', whereArgs: [date, userId], orderBy: 'mealNumber ASC');
    return maps.map((json) => MealModel.fromMap(json)).toList();
  }

  Future<int> updateMeal(MealModel meal) async {
    final db = await instance.database;
    return await db.update('meals', meal.toMap(), where: 'id = ?', whereArgs: [meal.id]);
  }

  Future<int> deleteMeal(int id) async {
    final db = await instance.database;
    return await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  Future<WeightEntryModel> createWeightEntry(WeightEntryModel entry) async {
    final db = await instance.database;
    Map<String, dynamic> entryMap = entry.toMap();
    if (entryMap['id'] == null) entryMap.remove('id');
    final id = await db.insert('weight_tracker', entryMap);
    entry.id = id;
    return entry;
  }

  Future<List<WeightEntryModel>> getWeightEntriesByUser(int userId) async {
    final db = await instance.database;
    final maps = await db.query('weight_tracker', where: 'nameId = ?', whereArgs: [userId], orderBy: 'date ASC');
    return maps.map((json) => WeightEntryModel.fromMap(json)).toList();
  }

  Future<int> updateWeightEntry(WeightEntryModel entry) async {
    final db = await instance.database;
    return await db.update('weight_tracker', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteWeightEntry(int id) async {
    final db = await instance.database;
    return await db.delete('weight_tracker', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

// --- Основное приложение ---
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaloriesCounter',
      theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE0E0FF),
            background: const Color(0xFFE0E0FF),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            bodyLarge: TextStyle(fontSize: 16, color: Colors.black54),
            titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          )),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', '')],
      locale: const Locale('ru', 'RU'),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/user_selection': (context) => const UserSelectionScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/profile') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) {
              return ProfileScreen(
                userProfile: args['profile'],
                onProfileUpdated: args['onProfileUpdated'],
              );
            },
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Экраны ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/user_selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          const Spacer(flex: 2),
          const Text('ColoriesCounter', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          const Text('Правильное питание ближе, чем ты\nдумаешь', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
          const Spacer(flex: 3),
        ]),
      ),
    );
  }
}

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  late Future<List<UserProfileModel>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = DatabaseHelper.instance.getAllUserProfiles();
  }

  void _refreshProfiles() {
    setState(() {
      _profilesFuture = DatabaseHelper.instance.getAllUserProfiles();
    });
  }

  void _navigateToRegistration() async {
    final result = await Navigator.pushNamed(context, '/registration');
    if (result == true) {
      _refreshProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите профиль')),
      body: FutureBuilder<List<UserProfileModel>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return MotivatorScreenController();
          } else {
            final profiles = snapshot.data!;
            return ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(profile.name),
                  subtitle: Text('ID: ${profile.id}'),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/home', arguments: profile);
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToRegistration,
        child: const Icon(Icons.add),
        tooltip: 'Создать новый профиль',
      ),
    );
  }
}

class MotivatorScreenController extends StatefulWidget {
  const MotivatorScreenController({super.key});
  @override
  State<MotivatorScreenController> createState() => _MotivatorScreenControllerState();
}

class _MotivatorScreenControllerState extends State<MotivatorScreenController> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        PageView.builder(
          controller: _pageController,
          itemCount: motivatorData.length,
          onPageChanged: (int page) {
            if (mounted) setState(() => _currentPage = page);
          },
          itemBuilder: (context, index) => MotivatorPage(
            imagePath: motivatorData[index]["image"]!,
            title: motivatorData[index]["title"]!,
            subtitle: motivatorData[index]["subtitle"]!,
          ),
        ),
        Positioned(bottom: 30, right: 30, child: FloatingActionButton(
          onPressed: () {
            if (_currentPage < motivatorData.length - 1) {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
            } else {
              Navigator.pushNamed(context, '/registration');
            }
          },
          backgroundColor: Colors.blueAccent, child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
        )),
        Positioned(bottom: 50, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(motivatorData.length, (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0), width: 8.0, height: 8.0,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? Colors.blueAccent : Colors.grey.shade400),
        )))),
      ]),
    );
  }
}

class MotivatorPage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  const MotivatorPage({super.key, required this.imagePath, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
        Expanded(flex: 3, child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(150), bottomRight: Radius.circular(150)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('ОШИБКА ЗАГРУЗКИ АССЕТА "$imagePath": $error');
                return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text('Не удалось загрузить:\n${imagePath.split('/').last}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                ]);
              },
            ),
          ),
        )),
        const SizedBox(height: 40),
        Expanded(flex: 2, child: Column(children: [
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.black87)),
          const SizedBox(height: 15),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54)),
        ])),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose(); _weightController.dispose(); _heightController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (mounted) setState(() => _isLoading = true);
      final name = _nameController.text;
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);

      if (weight != null && height != null) {
        UserProfileModel userProfileData = UserProfileModel(name: name, weight: weight, height: height);
        try {
          await DatabaseHelper.instance.createUserProfile(userProfileData);
          if (mounted) {
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: Имя "$name" уже существует.')));
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, введите корректные числовые значения.')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый профиль', style: TextStyle(color: Colors.black87)),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                _buildTextField(controller: _nameController, labelText: 'Введите ваше имя (уникальное)', enabled: !_isLoading, validator: (v) => (v == null || v.isEmpty) ? 'Пожалуйста, введите ваше имя' : null),
                const SizedBox(height: 20),
                _buildTextField(controller: _weightController, labelText: 'Введите ваш вес (кг)', keyboardType: const TextInputType.numberWithOptions(decimal: true), enabled: !_isLoading, validator: (v) => (v == null || v.isEmpty) ? 'Пожалуйста, введите ваш вес' : (double.tryParse(v) == null || double.parse(v) <= 0) ? 'Введите корректный вес' : null),
                const SizedBox(height: 20),
                _buildTextField(controller: _heightController, labelText: 'Введите ваш рост (см)', keyboardType: const TextInputType.numberWithOptions(decimal: false), enabled: !_isLoading, validator: (v) => (v == null || v.isEmpty) ? 'Пожалуйста, введите ваш рост' : (double.tryParse(v) == null || double.parse(v) <= 0) ? 'Введите корректный рост' : null),
                const SizedBox(height: 40),
                _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _submitForm, child: const Text('Создать профиль')),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String labelText, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, bool enabled = true}) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText, labelStyle: const TextStyle(color: Colors.black54),
        filled: true, fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Colors.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Colors.red, width: 2)),
      ),
      validator: validator, style: const TextStyle(color: Colors.black87),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  UserProfileModel userProfile;
  final Future<void> Function() onProfileUpdated;

  ProfileScreen({
    super.key,
    required this.userProfile,
    required this.onProfileUpdated
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  void _showEditNameDialog() {
    final nameController = TextEditingController(text: widget.userProfile.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Изменить имя'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Новое имя'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final updatedProfile = widget.userProfile.copyWith(name: nameController.text);
                  await DatabaseHelper.instance.updateUserProfile(updatedProfile);
                  Navigator.pop(context);
                  await widget.onProfileUpdated();
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bmiColor;
    String bmiInterpretationText = widget.userProfile.bmiInterpretation ?? 'Данные для ИМТ неполны';
    if (widget.userProfile.bmi == null) bmiColor = Colors.grey;
    else if (widget.userProfile.bmi! < 18.5) bmiColor = Colors.blue.shade300;
    else if (widget.userProfile.bmi! < 25) bmiColor = Colors.green.shade400;
    else if (widget.userProfile.bmi! < 30) bmiColor = Colors.orange.shade400;
    else bmiColor = Colors.red.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Сменить пользователя',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/user_selection', (route) => false);
            },
          )
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Center(child: CircleAvatar(radius: 50, backgroundColor: Theme.of(context).primaryColor, child: Text(widget.userProfile.name.isNotEmpty ? widget.userProfile.name[0].toUpperCase() : 'П', style: const TextStyle(fontSize: 40, color: Colors.white)))),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.userProfile.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                onPressed: _showEditNameDialog,
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(child: Text('ID: ${widget.userProfile.id ?? "N/A"} | Зарегистрирован: ${widget.userProfile.registrationDate != null ? DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(DateTime.parse(widget.userProfile.registrationDate!)) : 'Н/Д'}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        const SizedBox(height: 20),
        _buildProfileInfoCard(context, title: 'Масса тела (кг)', value: widget.userProfile.weight.toStringAsFixed(1), icon: Icons.fitness_center),
        const SizedBox(height: 15),
        _buildProfileInfoCard(context, title: 'Рост (см)', value: widget.userProfile.height.toStringAsFixed(0), icon: Icons.height),
        const SizedBox(height: 30),
        Center(child: Text('Индекс массы тела (ИМТ):', style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 10),
        Center(child: Text(widget.userProfile.bmi?.toStringAsFixed(1) ?? 'Н/Д', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: bmiColor, fontWeight: FontWeight.bold, fontSize: 36))),
        const SizedBox(height: 10),
        if (widget.userProfile.bmi != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Container(height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(colors: [Colors.blue.shade200, Colors.green.shade300, Colors.orange.shade300, Colors.red.shade300], stops: const [0.0, 0.4, 0.65, 1.0])),
          child: LayoutBuilder(builder: (context, constraints) => Stack(children: [
            AnimatedPositioned(duration: const Duration(milliseconds: 500), left: _calculateBmiIndicatorPosition(constraints.maxWidth, widget.userProfile.bmi!), child: Container(width: 4, height: 20, color: Colors.black87))
          ])),
        )),
        const SizedBox(height: 10),
        Center(child: Text(bmiInterpretationText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: bmiColor, fontWeight: FontWeight.bold))),
        const SizedBox(height: 40),
      ])),
    );
  }

  Widget _buildProfileInfoCard(BuildContext context, {required String title, required String value, required IconData icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).primaryColor),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  double _calculateBmiIndicatorPosition(double scaleActualWidth, double bmi) {
    double minBmi = 15.0;
    double maxBmi = 40.0;
    const double indicatorWidth = 4.0;
    if (bmi < minBmi) return 0;
    if (bmi > maxBmi) return scaleActualWidth - indicatorWidth;
    double position = ((bmi - minBmi) / (maxBmi - minBmi)) * scaleActualWidth;
    return position.clamp(0, scaleActualWidth - indicatorWidth);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  UserProfileModel? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is UserProfileModel) {
          if (mounted) setState(() => _currentUserProfile = args);
        } else {
          Navigator.pushReplacementNamed(context, '/user_selection');
        }
      }
    });
  }

  Future<void> _refreshProfile() async {
    if (_currentUserProfile?.id == null) return;
    final profileFromDb = await DatabaseHelper.instance.getUserProfileById(_currentUserProfile!.id!);
    if (mounted && profileFromDb != null) {
      setState(() {
        _currentUserProfile = profileFromDb;
      });
    }
  }

  List<Widget> _buildWidgetOptions(UserProfileModel? profile) {
    if (profile == null) return List.filled(3, const Center(child: CircularProgressIndicator()));
    return <Widget>[
      FoodTrackingScreen(currentUserProfile: profile, key: ValueKey('food_${profile.id}')),
      ProfileScreen(userProfile: profile, onProfileUpdated: _refreshProfile, key: ValueKey('profile_${profile.id}')),
      WeightTrackingScreen(currentUserProfile: profile, onWeightUpdated: _refreshProfile, key: ValueKey('weight_${profile.id}')),
    ];
  }

  void _onItemTapped(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserProfile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final widgetOptions = _buildWidgetOptions(_currentUserProfile);
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Питание'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_weight), label: 'Вес'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped, type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class FoodTrackingScreen extends StatefulWidget {
  final UserProfileModel currentUserProfile;
  const FoodTrackingScreen({super.key, required this.currentUserProfile});
  @override
  State<FoodTrackingScreen> createState() => _FoodTrackingScreenState();
}

class _FoodTrackingScreenState extends State<FoodTrackingScreen> {
  DateTime _selectedDate = DateTime.now();
  List<MealModel> _mealsForSelectedDate = [];
  Map<String, double> _dailyTotals = {'calories': 0.0, 'proteins': 0.0, 'fats': 0.0, 'carbs': 0.0, 'grams': 0.0};
  bool _isLoadingMeals = true;

  @override
  void initState() { super.initState(); _loadMealsForSelectedDate(); }

  Future<void> _loadMealsForSelectedDate() async {
    if (widget.currentUserProfile.id == null) {
      if (mounted) {
        setState(() => _isLoadingMeals = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: ID Профиля не найден.')));
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoadingMeals = true);
    final formattedDate = DateFormat('yyyy-MM-dd', 'ru_RU').format(_selectedDate);
    final meals = await DatabaseHelper.instance.getMealsByDateAndUser(formattedDate, widget.currentUserProfile.id!);
    if (mounted) setState(() { _mealsForSelectedDate = meals; _calculateDailyTotals(); _isLoadingMeals = false; });
  }

  void _calculateDailyTotals() {
    double c = 0, p = 0, f = 0, carb = 0, g = 0;
    for (var meal in _mealsForSelectedDate) { c += meal.calories; p += meal.proteins; f += meal.fats; carb += meal.carbs; g += meal.grams; }
    if (mounted) setState(() => _dailyTotals = {'calories': c, 'proteins': p, 'fats': f, 'carbs': carb, 'grams': g});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('ru', 'RU'));
    if (picked != null && picked != _selectedDate) {
      if (mounted) setState(() => _selectedDate = picked);
      _loadMealsForSelectedDate();
    }
  }

  void _navigateToAddMealScreen() async {
    if (widget.currentUserProfile.id == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: Профиль не определен.'))); return; }
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditMealScreen(profileId: widget.currentUserProfile.id!, selectedDate: _selectedDate)));
    if (result == true && mounted) _loadMealsForSelectedDate();
  }

  void _navigateToEditMealScreen(MealModel meal) async {
    if (widget.currentUserProfile.id == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: Профиль не определен.'))); return; }
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditMealScreen(profileId: widget.currentUserProfile.id!, selectedDate: DateTime.parse(meal.date), mealToEdit: meal)));
    if (result == true && mounted) _loadMealsForSelectedDate();
  }

  Future<void> _deleteMeal(int mealId) async {
    final bool? confirm = await showDialog<bool>(context: context, builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Удалить прием пищи?'), content: const Text('Вы уверены?'),
      actions: [TextButton(child: const Text('Отмена'), onPressed: () => Navigator.of(ctx).pop(false)), TextButton(child: const Text('Удалить', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(ctx).pop(true))],
    ));
    if (confirm == true) { await DatabaseHelper.instance.deleteMeal(mealId); _loadMealsForSelectedDate(); }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserProfile.id == null) return Scaffold(appBar: AppBar(title: const Text('Контроль питания')), body: const Center(child: Text('Ошибка профиля (ID отсутствует).')));
    return Scaffold(
      appBar: AppBar(title: Text('Питание: ${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDate)}'), actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context))], automaticallyImplyLeading: false),
      body: Column(children: [
        _buildDailyTotalsCard(),
        Expanded(child: _isLoadingMeals ? const Center(child: CircularProgressIndicator()) : _mealsForSelectedDate.isEmpty
            ? Center(child: Text('Нет записей о приемах пищи на\n${DateFormat('dd MMMM finalList', 'ru_RU').format(_selectedDate)}', textAlign: TextAlign.center))
            : ListView.builder(padding: const EdgeInsets.only(bottom: 80.0),itemCount: _mealsForSelectedDate.length, itemBuilder: (context, index) {
          final meal = _mealsForSelectedDate[index];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: ListTile(
            title: Text(meal.nameOfFood, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('К: ${meal.calories.toStringAsFixed(0)}ккал, Б: ${meal.proteins.toStringAsFixed(1)}г, Ж: ${meal.fats.toStringAsFixed(1)}г, У: ${meal.carbs.toStringAsFixed(1)}г\nГраммы: ${meal.grams.toStringAsFixed(0)}г, Прием №${meal.mealNumber}'),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _navigateToEditMealScreen(meal)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { if (meal.id != null) _deleteMeal(meal.id!); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: ID отсутствует.'))); }),
            ]), onTap: () => _navigateToEditMealScreen(meal),
          ));
        })),
      ]),
      floatingActionButton: FloatingActionButton(heroTag: 'fab_food', onPressed: _navigateToAddMealScreen, tooltip: 'Добавить прием пищи', child: const Icon(Icons.add)),
    );
  }

  Widget _buildDailyTotalsCard() {
    return Card(margin: const EdgeInsets.all(8.0), child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Дневная сводка:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Калории: ${_dailyTotals['calories']?.toStringAsFixed(0) ?? '0'} ккал'),
          Text('Граммы: ${_dailyTotals['grams']?.toStringAsFixed(0) ?? '0'} г'),
        ]),
        const SizedBox(height: 4), Text('Белки: ${_dailyTotals['proteins']?.toStringAsFixed(1) ?? '0'} г'),
        const SizedBox(height: 4), Text('Жиры: ${_dailyTotals['fats']?.toStringAsFixed(1) ?? '0'} г'),
        const SizedBox(height: 4), Text('Углеводы: ${_dailyTotals['carbs']?.toStringAsFixed(1) ?? '0'} г'),
      ]),
    ));
  }
}

class AddEditMealScreen extends StatefulWidget {
  final int profileId;
  final DateTime selectedDate;
  final MealModel? mealToEdit;
  const AddEditMealScreen({super.key, required this.profileId, required this.selectedDate, this.mealToEdit});
  @override
  State<AddEditMealScreen> createState() => _AddEditMealScreenState();
}

class _AddEditMealScreenState extends State<AddEditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _proteinsController, _fatsController, _carbsController, _caloriesController, _gramsController;
  bool get _isEditing => widget.mealToEdit != null;

  MealSuggestion? _baseSuggestion;
  double _servingMultiplier = 1.0;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.mealToEdit?.nameOfFood ?? '');
    _proteinsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.proteins));
    _fatsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.fats));
    _carbsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.carbs));
    _caloriesController = TextEditingController(text: _formatDouble(widget.mealToEdit?.calories, 0));
    _gramsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.grams, 0));

    if (_isEditing) {
      _baseSuggestion = MealSuggestion(
        name: widget.mealToEdit!.nameOfFood,
        calories: widget.mealToEdit!.calories,
        proteins: widget.mealToEdit!.proteins,
        fats: widget.mealToEdit!.fats,
        carbs: widget.mealToEdit!.carbs,
        grams: widget.mealToEdit!.grams,
      );
    }
  }

  void _updateFieldsFromSuggestion(MealSuggestion suggestion) {
    _baseSuggestion = suggestion;
    _servingMultiplier = 1.0;

    _updateTextFields();
  }

  void _updateTextFields() {
    if (_baseSuggestion == null) return;

    setState(() {
      _nameController.text = _baseSuggestion!.name;
      _caloriesController.text = (_baseSuggestion!.calories * _servingMultiplier).toStringAsFixed(0);
      _proteinsController.text = (_baseSuggestion!.proteins * _servingMultiplier).toStringAsFixed(1);
      _fatsController.text = (_baseSuggestion!.fats * _servingMultiplier).toStringAsFixed(1);
      _carbsController.text = (_baseSuggestion!.carbs * _servingMultiplier).toStringAsFixed(1);
      _gramsController.text = (_baseSuggestion!.grams * _servingMultiplier).toStringAsFixed(0);
    });
  }

  void _changeMultiplier(double change) {
    if (_baseSuggestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала выберите блюдо из подсказок')));
      return;
    }
    setState(() {
      _servingMultiplier += change;
      if (_servingMultiplier < 0.5) _servingMultiplier = 0.5;
    });
    _updateTextFields();
  }

  String _formatDouble(double? value, [int precision = 1]) {
    if (value == null || value == 0.0) return '';
    return value.toStringAsFixed(precision);
  }

  @override
  void dispose() {
    _nameController.dispose(); _proteinsController.dispose(); _fatsController.dispose();
    _carbsController.dispose(); _caloriesController.dispose(); _gramsController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _saveMeal() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final name = _nameController.text;
      final p = double.tryParse(_proteinsController.text) ?? 0.0;
      final f = double.tryParse(_fatsController.text) ?? 0.0;
      final c = double.tryParse(_carbsController.text) ?? 0.0;
      final cal = double.tryParse(_caloriesController.text) ?? 0.0;
      final g = double.tryParse(_gramsController.text) ?? 0.0;

      int mealNum;
      if (_isEditing && widget.mealToEdit?.mealNumber != null) mealNum = widget.mealToEdit!.mealNumber;
      else {
        final formattedDate = DateFormat('yyyy-MM-dd', 'ru_RU').format(widget.selectedDate);
        final meals = await DatabaseHelper.instance.getMealsByDateAndUser(formattedDate, widget.profileId);
        mealNum = meals.length + 1;
      }

      final meal = MealModel(id: widget.mealToEdit?.id, userId: widget.profileId, nameOfFood: name, proteins: p, fats: f, carbs: c, calories: cal, grams: g, date: DateFormat('yyyy-MM-dd', 'ru_RU').format(widget.selectedDate), mealNumber: mealNum);
      if (_isEditing) await DatabaseHelper.instance.updateMeal(meal);
      else await DatabaseHelper.instance.createMeal(meal);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Редактировать' : 'Добавить прием пищи'), actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveMeal)]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Autocomplete<MealSuggestion>(
            displayStringForOption: (MealSuggestion option) => option.name,
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              if (textEditingValue.text.length < 2) {
                return const Iterable<MealSuggestion>.empty();
              }

              final completer = Completer<List<MealSuggestion>>();
              _debounce = Timer(const Duration(milliseconds: 500), () async {
                try {
                  final suggestions = await GeminiSuggestionService.instance.getMealSuggestions(textEditingValue.text);
                  if (!completer.isCompleted) completer.complete(suggestions);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")))
                    );
                  }
                  if (!completer.isCompleted) completer.complete([]);
                }
              });

              return completer.future;
            },
            onSelected: (MealSuggestion selection) {
              FocusScope.of(context).unfocus();
              _updateFieldsFromSuggestion(selection);
            },
            fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
              return _buildTextField(controller: fieldController, focusNode: fieldFocusNode, labelText: 'Название продукта/блюда', validator: (v) => (v == null || v.isEmpty) ? 'Введите название' : null);
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 220, maxWidth: MediaQuery.of(context).size.width - 32),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final MealSuggestion option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: ListTile(
                            title: Text(option.name),
                            subtitle: Text('~${option.calories.toInt()} ккал, ${option.grams.toInt()} г', style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          if (_baseSuggestion != null) _buildServingMultiplierControls(),

          _buildTextField(controller: _caloriesController, labelText: 'Калории (ккал)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorRequiredPositive),
          _buildTextField(controller: _proteinsController, labelText: 'Белки (г)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorPositiveOrZero),
          _buildTextField(controller: _fatsController, labelText: 'Жиры (г)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorPositiveOrZero),
          _buildTextField(controller: _carbsController, labelText: 'Углеводы (г)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorPositiveOrZero),
          _buildTextField(controller: _gramsController, labelText: 'Граммы', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorRequiredPositive),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saveMeal, child: const Text('Сохранить')),
        ]),
      )),
    );
  }

  Widget _buildServingMultiplierControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _changeMultiplier(-0.5),
          ),
          Text(
            'Порции: x${_servingMultiplier.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _changeMultiplier(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
        required String labelText,
        FocusNode? focusNode,
        TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator,
        bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
              labelText: labelText,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              labelStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.red, width: 1)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.red, width: 2))),
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          style: const TextStyle(color: Colors.black87)),
    );
  }

  String? _numericValidatorPositiveOrZero(String? value) {
    if (value == null || value.isEmpty) return 'Это поле обязательно';
    if (double.tryParse(value) == null) return 'Введите корректное число (напр. 10.5)';
    if (double.parse(value) < 0) return 'Значение не может быть отрицательным';
    return null;
  }
  String? _numericValidatorRequiredPositive(String? value) {
    if (value == null || value.isEmpty) return 'Это поле обязательно';
    if (double.tryParse(value) == null) return 'Введите корректное число (напр. 100.0)';
    if (double.parse(value) <= 0) return 'Значение должно быть больше нуля';
    return null;
  }
}

// --- WeightTrackingScreen ---
class WeightTrackingScreen extends StatefulWidget {
  final UserProfileModel currentUserProfile;
  final Future<void> Function() onWeightUpdated;

  const WeightTrackingScreen({
    super.key,
    required this.currentUserProfile,
    required this.onWeightUpdated,
  });

  @override
  State<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends State<WeightTrackingScreen> {
  List<WeightEntryModel> _weightEntries = [];
  bool _isLoading = true;

  final TextEditingController _weightController = TextEditingController();
  DateTime _selectedDateForEntry = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadWeightEntries();
  }

  Future<void> _loadWeightEntries() async {
    if (mounted) setState(() => _isLoading = true);
    if (widget.currentUserProfile.id == null) {
      if(mounted) setState(() => _isLoading = false);
      return;
    }
    final entries = await DatabaseHelper.instance.getWeightEntriesByUser(widget.currentUserProfile.id!);
    if (mounted) {
      setState(() {
        _weightEntries = entries;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteWeightEntry(int id) async {
    final bool? confirm = await showDialog<bool>(context: context, builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Удалить взвешивание?'), content: const Text('Вы уверены?'),
      actions: [TextButton(child: const Text('Отмена'), onPressed: () => Navigator.of(ctx).pop(false)), TextButton(child: const Text('Удалить', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(ctx).pop(true))],
    ));
    if (confirm != true) return;

    await DatabaseHelper.instance.deleteWeightEntry(id);
    final remainingEntries = await DatabaseHelper.instance.getWeightEntriesByUser(widget.currentUserProfile.id!);

    double? newWeightForProfile;
    if (remainingEntries.isNotEmpty) {
      newWeightForProfile = remainingEntries.last.weight;
    } else {
      final originalProfile = await DatabaseHelper.instance.getUserProfileById(widget.currentUserProfile.id!);
      if (originalProfile != null) {
        newWeightForProfile = originalProfile.weight;
      }
    }

    if (newWeightForProfile != null) {
      final updatedProfile = widget.currentUserProfile.copyWith(weight: newWeightForProfile);
      await DatabaseHelper.instance.updateUserProfile(updatedProfile);
    }

    if (mounted) {
      setState(() {
        _weightEntries = remainingEntries;
      });
    }

    await widget.onWeightUpdated();
  }

  Future<void> _saveWeight(double weight, {WeightEntryModel? entry}) async {
    final bool isEditing = entry != null;
    final entryDate = DateFormat('yyyy-MM-dd').format(_selectedDateForEntry);

    final newEntry = WeightEntryModel(
      id: isEditing ? entry.id : null,
      userId: widget.currentUserProfile.id!,
      weight: weight,
      date: entryDate,
    );

    if (isEditing) {
      await DatabaseHelper.instance.updateWeightEntry(newEntry);
    } else {
      await DatabaseHelper.instance.createWeightEntry(newEntry);
    }

    final allEntries = await DatabaseHelper.instance.getWeightEntriesByUser(widget.currentUserProfile.id!);

    if (allEntries.isNotEmpty) {
      final latestEntry = allEntries.last;
      if (widget.currentUserProfile.weight != latestEntry.weight) {
        final updatedProfile = widget.currentUserProfile.copyWith(weight: latestEntry.weight);
        await DatabaseHelper.instance.updateUserProfile(updatedProfile);
      }
    }

    if (mounted) Navigator.of(context).pop();
    _loadWeightEntries();
    await widget.onWeightUpdated();
  }

  Future<void> _showAddEditDialog({WeightEntryModel? entry}) async {
    bool isEditing = entry != null;
    _weightController.text = isEditing ? entry.weight.toStringAsFixed(1) : '';
    _selectedDateForEntry = isEditing ? DateTime.parse(entry.date) : DateTime.now();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Редактировать вес' : 'Добавить вес'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Вес (кг)', suffixText: 'кг'),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Дата: ${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDateForEntry)}'),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDateForEntry,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        locale: const Locale('ru', 'RU'),
                      );
                      if (picked != null && picked != _selectedDateForEntry) {
                        setDialogState(() {
                          _selectedDateForEntry = picked;
                        });
                      }
                    },
                  )
                ]),
              ]),
              actions: <Widget>[
                TextButton(child: const Text('Отмена'), onPressed: () => Navigator.of(context).pop()),
                TextButton(
                  child: const Text('Сохранить'),
                  onPressed: () async {
                    final weight = double.tryParse(_weightController.text);
                    if (weight != null && weight > 0) {
                      await _saveWeight(weight, entry: entry);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, введите корректный вес.')));
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчет по взвешиваниям'), automaticallyImplyLeading: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildChart(),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text('История взвешиваний', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: _buildHistoryList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_weight',
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Добавить взвешивание',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHistoryList() {
    final reversedEntries = _weightEntries.reversed.toList();
    if (reversedEntries.isEmpty) {
      return const Center(child: Text('Нет записей о взвешиваниях.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80.0),
      itemCount: reversedEntries.length,
      itemBuilder: (context, index) {
        final entry = reversedEntries[index];
        return ListTile(
          leading: const Icon(Icons.monitor_weight_outlined, color: Colors.deepPurple),
          title: Text('${entry.weight.toStringAsFixed(1)} кг', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(DateFormat('dd MMMM yyyy', 'ru_RU').format(DateTime.parse(entry.date))),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _showAddEditDialog(entry: entry)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteWeightEntry(entry.id!)),
          ]),
        );
      },
    );
  }

  Widget _buildChart() {
    if (_weightEntries.length < 2) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text('Нужно как минимум два взвешивания для построения графика.', textAlign: TextAlign.center),
      );
    }
    List<FlSpot> spots = _weightEntries.map((entry) {
      DateTime date = DateTime.parse(entry.date);
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), entry.weight);
    }).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _getBottomTitleInterval(),
              getTitlesWidget: (value, meta) {
                DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(DateFormat('dd.MM', 'ru_RU').format(date), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.deepPurple,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.deepPurple.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }

  double _getBottomTitleInterval() {
    if (_weightEntries.length < 2) return 1;
    DateTime first = DateTime.parse(_weightEntries.first.date);
    DateTime last = DateTime.parse(_weightEntries.last.date);
    int totalDays = last.difference(first).inDays;

    if (totalDays == 0) return 1;

    double intervalInDays = (totalDays / 4).ceilToDouble();
    if (intervalInDays < 1) intervalInDays = 1;

    return intervalInDays * 24 * 60 * 60 * 1000;
  }
}
