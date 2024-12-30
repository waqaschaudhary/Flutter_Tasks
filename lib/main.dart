import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  Hive.registerAdapter(UserAdapter());

  // Initialize controllers
  Get.put(ThemeController());
  await Get.putAsync(() async => UserController()..init());

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeController = Get.find<ThemeController>();
      return GetMaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeController.themeMode,
        home: ProfileScreen(),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}

class ThemeController extends GetxController {
  Rx<ThemeMode> _themeMode = ThemeMode.light.obs;

  ThemeMode get themeMode => _themeMode.value;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeMode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = _themeMode.value == ThemeMode.light;
    _themeMode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    prefs.setBool('isDarkMode', isDarkMode);
  }
}

class User {
  String username;
  String profileImage;
  String bgImage;

  User({
    required this.username,
    required this.profileImage,
    required this.bgImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      profileImage: json['profileImage'],
      bgImage: json['bgImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'profileImage': profileImage,
      'bgImage': bgImage,
    };
  }
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 1;

  @override
  User read(BinaryReader reader) {
    return User(
      username: reader.read(),
      profileImage: reader.read(),
      bgImage: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.write(obj.username);
    writer.write(obj.profileImage);
    writer.write(obj.bgImage);
  }
}

class UserController extends GetxController {
  late Box<User> _userBox;

  Future<void> init() async {
    _userBox = await Hive.openBox<User>('users');
  }

  void addUser(User user) {
    _userBox.add(user);
  }

  List<User> getAllUsers() {
    return _userBox.values.toList();
  }

  void updateUser(int index, User user) {
    _userBox.putAt(index, user);
  }

  void deleteUser(int index) {
    _userBox.deleteAt(index);
  }
}

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  File? _profileImage;
  File? _bgImage;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userController = Get.find<UserController>();
    await userController.init(); // Ensure user data is loaded
    setState(() {
      _isLoading = false; // Set loading to false once data is ready
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final userController = Get.find<UserController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(userController
                                      .getAllUsers()
                                      .isNotEmpty
                                  ? userController.getAllUsers().first.bgImage
                                  : 'images/bg.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 20,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: AssetImage(
                                userController.getAllUsers().isNotEmpty
                                    ? userController
                                        .getAllUsers()
                                        .first
                                        .profileImage
                                    : 'images/profile.jpg'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _pickProfileImage,
                            child: const Text('Pick Profile Image'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _pickBackgroundImage,
                            child: const Text('Pick Background Image'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: themeController.themeMode == ThemeMode.dark,
                      onChanged: (value) => themeController.toggleTheme(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickProfileImage() async {
    await _requestPermissions();
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickBackgroundImage() async {
    await _requestPermissions();
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _bgImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request for Android storage permissions
      PermissionStatus status = await Permission.storage.request();
      if (!status.isGranted) {
        print("Storage permission denied");
        // Open app settings to request permission manually
        openAppSettings();
      } else {
        print("Storage permission granted");
      }

      // Handle MANAGE_EXTERNAL_STORAGE for Android 11+
      if (await Permission.manageExternalStorage.isDenied) {
        openAppSettings();
      }
    }
  }
}
