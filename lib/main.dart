import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart'; // Для работы с базой данных
import 'package:path/path.dart' as p; // Для работы с путями к файлам БД, ИСПОЛЬЗУЕМ ПРЕФИКС 'p'
import 'package:intl/intl.dart'; // Для форматирования дат
import 'package:flutter_localizations/flutter_localizations.dart'; // Для локализации DatePicker

// Данные для мотиваторов (текст и путь к изображению)
// Убедитесь, что пути соответствуют вашим файлам в assets/images/
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
    if (height > 0 && weight > 0) { // Добавил проверку weight > 0
      double heightInMeters = height / 100.0;
      bmi = weight / (heightInMeters * heightInMeters);
      if (bmi != null && bmi!.isFinite) { // Проверка на isFinite
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
        bmi = null; // Если результат не конечен, сбрасываем bmi
        bmiInterpretation = "Невозможно рассчитать ИМТ";
      }
    } else {
      bmi = null; // Если рост или вес некорректны, сбрасываем bmi
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
    _database = await _initDB('calories_counter_v3.db'); // Еще раз сменил имя на всякий случай
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath); // ИСПОЛЬЗУЕМ ПРЕФИКС p.
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE profile (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
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
    final id = await db.insert('profile', profile.toMap());
    profile.id = id;
    return profile;
  }

  Future<UserProfileModel?> getUserProfile() async {
    final db = await instance.database;
    final maps = await db.query(
      'profile',
      orderBy: 'id DESC',
      limit: 1,
    );
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
    return db.update(
      'profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteUserProfile(int id) async {
    final db = await instance.database;
    return db.delete(
      'profile',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<MealModel> createMeal(MealModel meal) async {
    final db = await instance.database;
    Map<String, dynamic> mealMap = meal.toMap();
    if (mealMap['id'] == null) {
      mealMap.remove('id');
    }
    final id = await db.insert('meals', mealMap);
    meal.id = id;
    return meal;
  }

  Future<List<MealModel>> getMealsByDateAndUser(String date, int userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'meals',
      where: 'date = ? AND nameId = ?',
      whereArgs: [date, userId],
      orderBy: 'mealNumber ASC',
    );
    return maps.map((json) => MealModel.fromMap(json)).toList();
  }

  Future<int> updateMeal(MealModel meal) async {
    final db = await instance.database;
    return await db.update(
      'meals',
      meal.toMap(),
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  Future<int> deleteMeal(int id) async {
    final db = await instance.database;
    return await db.delete(
      'meals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<WeightEntryModel> createWeightEntry(WeightEntryModel entry) async {
    final db = await instance.database;
    Map<String, dynamic> entryMap = entry.toMap();
    if (entryMap['id'] == null) {
      entryMap.remove('id');
    }
    final id = await db.insert('weight_tracker', entryMap);
    entry.id = id;
    return entry;
  }

  Future<List<WeightEntryModel>> getWeightEntriesByUser(int userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'weight_tracker',
      where: 'nameId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map((json) => WeightEntryModel.fromMap(json)).toList();
  }

  Future<int> updateWeightEntry(WeightEntryModel entry) async {
    final db = await instance.database;
    return await db.update(
      'weight_tracker',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteWeightEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'weight_tracker',
      where: 'id = ?',
      whereArgs: [id],
    );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            bodyLarge: TextStyle(fontSize: 16, color: Colors.black54),
            titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          )
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', ''),
      ],
      locale: const Locale('ru', 'RU'),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/motivators': (context) => const MotivatorScreenController(),
        '/registration': (context) => const RegistrationScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/profile') {
          final args = settings.arguments as UserProfileModel;
          return MaterialPageRoute(
            builder: (context) {
              return ProfileScreen(userProfile: args);
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

// SplashScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserProfile();
  }

  Future<void> _checkUserProfile() async {
    await Future.delayed(const Duration(seconds: 2));
    UserProfileModel? userProfile = await DatabaseHelper.instance.getUserProfile();
    if (mounted) {
      if (userProfile != null) {
        Navigator.pushReplacementNamed(context, '/home', arguments: userProfile);
      } else {
        Navigator.pushReplacementNamed(context, '/motivators');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(flex: 2),
            const Text(
              'ColoriesCounter',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              'Правильное питание ближе, чем ты\nдумаешь',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const Spacer(flex: 3),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/motivators');
              },
              child: const Text('Начать легко'),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

// MotivatorScreenController
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
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: motivatorData.length,
            onPageChanged: (int page) {
              if (mounted) {
                setState(() {
                  _currentPage = page;
                });
              }
            },
            itemBuilder: (context, index) {
              return MotivatorPage(
                imagePath: motivatorData[index]["image"]!,
                title: motivatorData[index]["title"]!,
                subtitle: motivatorData[index]["subtitle"]!,
              );
            },
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: () {
                if (_currentPage < motivatorData.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  );
                } else {
                  Navigator.pushReplacementNamed(context, '/registration');
                }
              },
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(motivatorData.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.blueAccent : Colors.grey.shade400,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// MotivatorPage
class MotivatorPage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;

  const MotivatorPage({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(150),
                    bottomRight: Radius.circular(150),
                  )
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20, top: 50),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Ошибка загрузки ассета: $imagePath, $error');
                    return const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.black87),
                ),
                const SizedBox(height: 15),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// RegistrationScreen
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
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if(mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final name = _nameController.text;
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);

      if (weight != null && height != null) {
        UserProfileModel userProfileData = UserProfileModel(
          name: name,
          weight: weight,
          height: height,
        );
        try {
          UserProfileModel savedProfile = await DatabaseHelper.instance.createUserProfile(userProfileData);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home', arguments: savedProfile);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка сохранения профиля: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пожалуйста, введите корректные числовые значения для веса и роста.')),
          );
          if(mounted){
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Данные для профиля', style: TextStyle(color: Colors.black87)),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/motivators');
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://placehold.co/400x800/E0E0FF/FFFFFF?text=Fill+Background&fontsize=16'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildTextField(
                    controller: _nameController,
                    labelText: 'Введите ваше имя',
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Пожалуйста, введите ваше имя';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _weightController,
                    labelText: 'Введите ваш вес (кг)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Пожалуйста, введите ваш вес';
                      if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Введите корректный вес';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _heightController,
                    labelText: 'Введите ваш рост (см)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: false), // Рост обычно целое число см
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Пожалуйста, введите ваш рост';
                      if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Введите корректный рост';
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Продолжить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
      style: const TextStyle(color: Colors.black87),
    );
  }
}

// ProfileScreen
class ProfileScreen extends StatelessWidget {
  final UserProfileModel userProfile;

  const ProfileScreen({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    Color bmiColor;
    String bmiInterpretationText = userProfile.bmiInterpretation ?? 'Данные для расчета ИМТ неполны';

    if (userProfile.bmi == null) {
      bmiColor = Colors.grey;
    } else if (userProfile.bmi! < 18.5) {
      bmiColor = Colors.blue.shade300;
    } else if (userProfile.bmi! < 25) {
      bmiColor = Colors.green.shade400;
    } else if (userProfile.bmi! < 30) {
      bmiColor = Colors.orange.shade400;
    } else {
      bmiColor = Colors.red.shade400;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  userProfile.name.isNotEmpty ? userProfile.name[0].toUpperCase() : 'П',
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                userProfile.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'ID: ${userProfile.id ?? "Нет ID"} | Зарегистрирован: ${userProfile.registrationDate != null ? DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(DateTime.parse(userProfile.registrationDate!)) : 'Н/Д'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileInfoCard(
              context,
              title: 'Масса тела (кг)',
              value: userProfile.weight.toStringAsFixed(1),
              icon: Icons.fitness_center,
            ),
            const SizedBox(height: 15),
            _buildProfileInfoCard(
              context,
              title: 'Рост (см)',
              value: userProfile.height.toStringAsFixed(0),
              icon: Icons.height,
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                'Индекс массы тела (ИМТ):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                userProfile.bmi?.toStringAsFixed(1) ?? 'Н/Д',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: bmiColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (userProfile.bmi != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade200, Colors.green.shade300, Colors.orange.shade300, Colors.red.shade300],
                      stops: const [0.0, 0.4, 0.65, 1.0],
                    ),
                  ),
                  child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 500),
                              left: _calculateBmiIndicatorPosition(constraints.maxWidth, userProfile.bmi!),
                              child: Container(
                                width: 4,
                                height: 20,
                                color: Colors.black87,
                              ),
                            )
                          ],
                        );
                      }
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                bmiInterpretationText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: bmiColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
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

// HomeScreen (с BottomNavigationBar)
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
    // Пробуем получить аргументы сразу, если HomeScreen открывается первым после загрузки/регистрации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Добавлена проверка mounted
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is UserProfileModel) {
          if (mounted) { // Добавлена проверка mounted
            setState(() {
              _currentUserProfile = args;
            });
          }
        } else {
          _loadProfileFromDb();
        }
      }
    });
  }

  Future<void> _loadProfileFromDb() async {
    final profile = await DatabaseHelper.instance.getUserProfile();
    if (mounted) {
      if (profile != null) {
        setState(() {
          _currentUserProfile = profile;
        });
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  List<Widget> _buildWidgetOptions(UserProfileModel? profile) {
    if (profile == null) {
      return List.filled(3, const Center(child: CircularProgressIndicator(key: ValueKey("loadingIndicatorHomeScreen"))));
    }
    return <Widget>[
      FoodTrackingScreen(currentUserProfile: profile, key: const ValueKey("foodTrackingScreen")),
      ProfileScreen(userProfile: profile,  key: const ValueKey("profileScreen")),
      WeightTrackingScreen(currentUserProfile: profile, key: const ValueKey("weightTrackingScreen")),
    ];
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(key: ValueKey("loadingProfileIndicator"))),
      );
    }

    final widgetOptions = _buildWidgetOptions(_currentUserProfile);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Питание'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_weight), label: 'Вес'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// FoodTrackingScreen
class FoodTrackingScreen extends StatefulWidget {
  final UserProfileModel currentUserProfile;
  const FoodTrackingScreen({super.key, required this.currentUserProfile});

  @override
  State<FoodTrackingScreen> createState() => _FoodTrackingScreenState();
}

class _FoodTrackingScreenState extends State<FoodTrackingScreen> {
  DateTime _selectedDate = DateTime.now();
  List<MealModel> _mealsForSelectedDate = [];
  Map<String, double> _dailyTotals = {
    'calories': 0.0, 'proteins': 0.0, 'fats': 0.0, 'carbs': 0.0, 'grams': 0.0,
  };
  bool _isLoadingMeals = true;

  @override
  void initState() {
    super.initState();
    _loadMealsForSelectedDate();
  }

  Future<void> _loadMealsForSelectedDate() async {
    if (widget.currentUserProfile.id == null) {
      if (mounted) {
        setState(() => _isLoadingMeals = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка: ID Профиля не найден для загрузки приемов пищи.')),
            );
          }
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoadingMeals = true);

    final formattedDate = DateFormat('yyyy-MM-dd', 'ru_RU').format(_selectedDate);
    final meals = await DatabaseHelper.instance.getMealsByDateAndUser(formattedDate, widget.currentUserProfile.id!);
    if (mounted) {
      setState(() {
        _mealsForSelectedDate = meals;
        _calculateDailyTotals();
        _isLoadingMeals = false;
      });
    }
  }

  void _calculateDailyTotals() {
    double totalCalories = 0, totalProteins = 0, totalFats = 0, totalCarbs = 0, totalGrams = 0;
    for (var meal in _mealsForSelectedDate) {
      totalCalories += meal.calories; totalProteins += meal.proteins; totalFats += meal.fats;
      totalCarbs += meal.carbs; totalGrams += meal.grams;
    }
    if (mounted) {
      setState(() {
        _dailyTotals = {
          'calories': totalCalories, 'proteins': totalProteins, 'fats': totalFats,
          'carbs': totalCarbs, 'grams': totalGrams,
        };
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), // Ограничим будущие даты
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) setState(() => _selectedDate = picked);
      _loadMealsForSelectedDate();
    }
  }

  void _navigateToAddMealScreen() async {
    if (widget.currentUserProfile.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: Профиль не определен.')));
      return;
    }
    final result = await Navigator.push(
      context, MaterialPageRoute(builder: (context) => AddEditMealScreen(
      profileId: widget.currentUserProfile.id!, selectedDate: _selectedDate,
    )),
    );
    if (result == true && mounted) _loadMealsForSelectedDate();
  }

  void _navigateToEditMealScreen(MealModel meal) async {
    if (widget.currentUserProfile.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: Профиль не определен.')));
      return;
    }
    final result = await Navigator.push(
      context, MaterialPageRoute(builder: (context) => AddEditMealScreen(
      profileId: widget.currentUserProfile.id!, selectedDate: DateTime.parse(meal.date), mealToEdit: meal,
    )),
    );
    if (result == true && mounted) _loadMealsForSelectedDate();
  }

  Future<void> _deleteMeal(int mealId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context, builder: (BuildContext context) => AlertDialog(
      title: const Text('Удалить прием пищи?'),
      content: const Text('Вы уверены, что хотите удалить эту запись?'),
      actions: <Widget>[
        TextButton(child: const Text('Отмена'), onPressed: () => Navigator.of(context).pop(false)),
        TextButton(child: const Text('Удалить', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop(true)),
      ],
    ),
    );
    if (confirmDelete == true) {
      await DatabaseHelper.instance.deleteMeal(mealId);
      _loadMealsForSelectedDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserProfile.id == null) {
      return Scaffold(appBar: AppBar(title: const Text('Контроль питания')),
          body: const Center(child: Text('Ошибка профиля пользователя (ID отсутствует).')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Питание: ${DateFormat('dd.MM.yyyy', 'ru_RU').format(_selectedDate)}'),
        actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context))],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildDailyTotalsCard(),
          Expanded(
            child: _isLoadingMeals
                ? const Center(child: CircularProgressIndicator())
                : _mealsForSelectedDate.isEmpty
                ? Center(child: Text('Нет записей о приемах пищи на\n${DateFormat('dd MMMM yyyy г.', 'ru_RU').format(_selectedDate)}', textAlign: TextAlign.center,))
                : ListView.builder(
              itemCount: _mealsForSelectedDate.length,
              itemBuilder: (context, index) {
                final meal = _mealsForSelectedDate[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    title: Text(meal.nameOfFood, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('К: ${meal.calories.toStringAsFixed(0)}ккал, Б: ${meal.proteins.toStringAsFixed(1)}г, Ж: ${meal.fats.toStringAsFixed(1)}г, У: ${meal.carbs.toStringAsFixed(1)}г\nГраммы: ${meal.grams.toStringAsFixed(0)}г, Прием №${meal.mealNumber}'),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _navigateToEditMealScreen(meal)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                        if (meal.id != null) _deleteMeal(meal.id!);
                        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: ID приема пищи отсутствует.')));
                      }),
                    ]),
                    onTap: () => _navigateToEditMealScreen(meal),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMealScreen, tooltip: 'Добавить прием пищи', child: const Icon(Icons.add),
      ),
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

// AddEditMealScreen
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.mealToEdit?.nameOfFood ?? '');
    _proteinsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.proteins));
    _fatsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.fats));
    _carbsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.carbs));
    _caloriesController = TextEditingController(text: _formatDouble(widget.mealToEdit?.calories, 0));
    _gramsController = TextEditingController(text: _formatDouble(widget.mealToEdit?.grams, 0));
  }

  String _formatDouble(double? value, [int precision = 1]) {
    if (value == null || value == 0.0) return ''; // Не показываем 0.0, если значение 0
    return value.toStringAsFixed(precision);
  }

  @override
  void dispose() {
    _nameController.dispose(); _proteinsController.dispose(); _fatsController.dispose();
    _carbsController.dispose(); _caloriesController.dispose(); _gramsController.dispose();
    super.dispose();
  }

  Future<void> _saveMeal() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final name = _nameController.text;
      final proteins = double.tryParse(_proteinsController.text) ?? 0.0;
      final fats = double.tryParse(_fatsController.text) ?? 0.0;
      final carbs = double.tryParse(_carbsController.text) ?? 0.0;
      final calories = double.tryParse(_caloriesController.text) ?? 0.0;
      final grams = double.tryParse(_gramsController.text) ?? 0.0;

      int mealNumberForEntry;
      if (_isEditing && widget.mealToEdit?.mealNumber != null) { // Добавил проверку на null
        mealNumberForEntry = widget.mealToEdit!.mealNumber;
      } else {
        final formattedDate = DateFormat('yyyy-MM-dd','ru_RU').format(widget.selectedDate);
        final existingMeals = await DatabaseHelper.instance.getMealsByDateAndUser(formattedDate, widget.profileId);
        mealNumberForEntry = existingMeals.length + 1;
      }

      final meal = MealModel(
        id: widget.mealToEdit?.id, userId: widget.profileId, nameOfFood: name,
        proteins: proteins, fats: fats, carbs: carbs, calories: calories, grams: grams,
        date: DateFormat('yyyy-MM-dd','ru_RU').format(widget.selectedDate), mealNumber: mealNumberForEntry,
      );

      if (_isEditing) await DatabaseHelper.instance.updateMeal(meal);
      else await DatabaseHelper.instance.createMeal(meal);

      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать прием пищи' : 'Добавить прием пищи'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveMeal)],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          _buildTextField(_nameController, 'Название продукта/блюда', validator: (v) => (v == null || v.isEmpty) ? 'Введите название' : null),
          _buildTextField(_caloriesController, 'Калории (ккал)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorRequiredPositive),
          _buildTextField(_proteinsController, 'Белки (г)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorPositiveOrZero),
          _buildTextField(_fatsController, 'Жиры (г)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorPositiveOrZero),
          _buildTextField(_carbsController, 'Углеводы (г)', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorPositiveOrZero),
          _buildTextField(_gramsController, 'Граммы', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _numericValidatorRequiredPositive),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saveMeal, child: const Text('Сохранить')),
        ]),
      )),
    );
  }

  // ИСПРАВЛЕННЫЙ _buildTextField в AddEditMealScreen
  Widget _buildTextField(
      TextEditingController controller,
      String labelText,
      {TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator, // Теперь validator - именованный параметр
        bool enabled = true} // Добавил enabled для консистентности, если понадобится
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          // Можно добавить стили от RegistrationScreen, если хотите унифицировать
          labelStyle: const TextStyle(color: Colors.black54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        keyboardType: keyboardType, // Используем переданный keyboardType
        validator: validator,
        enabled: enabled,
        style: const TextStyle(color: Colors.black87),
      ),
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

// WeightTrackingScreen - ЗАГЛУШКА
class WeightTrackingScreen extends StatefulWidget {
  final UserProfileModel currentUserProfile;
  const WeightTrackingScreen({super.key, required this.currentUserProfile});

  @override
  State<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends State<WeightTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчет по взвешиваниям'), automaticallyImplyLeading: false,),
      body: Center(child: Text('Экран отчета по взвешиваниям для ID: ${widget.currentUserProfile.id ?? "N/A"}')),
    );
  }
}
