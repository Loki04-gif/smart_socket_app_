import 'dart:async'; // Zamanlayıcı için gerekli
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart'; // Bildirim izinleri için gerekli
import 'package:http/http.dart' as http;

String espIpAddress = "esp.local";
const Duration httpTimeout = Duration(seconds: 10);

Future<void> sendPlugCommand(String plugName, bool status) async {
  final String cleanedPlugName = plugName.replaceAll(' ', '%20');
  final String url = "http://$espIpAddress/$cleanedPlugName/${status ? 'on' : 'off'}";
  try {
    final response = await http.get(Uri.parse(url)).timeout(httpTimeout);
    if (response.statusCode != 200) {
      print("$plugName güncelleme başarısız: ${response.body}");
    }
  } catch (e) {
    print("Bağlantı hatası: $e");
  }
}
Future<void> resetWiFiSettings() async {
  final response = await http.get(Uri.parse("http://esp.local/resetwifi")).timeout(Duration(seconds: 5));
  if (response.statusCode == 200) {
    print("ESP Wi-Fi sıfırlandı.");
  } else {
    print("Sıfırlama başarısız.");
  }
}
void main() {
  runApp(MaterialApp(
    home: SmartPlugApp(),
  ));
}
class SmartPlugApp extends StatefulWidget {
  @override
  _SmartPlugAppState createState() => _SmartPlugAppState();
}

class _SmartPlugAppState extends State<SmartPlugApp> {
  bool isDarkTheme = false; // Tema durumu

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }
  Future<void> _checkNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      // Kullanıcıyı bilgilendiren dialog göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationPermissionDialog();
      });
    }
  }
  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bildirim İzni Gerekli'),
          content: Text('Bildirim almak için, ayarlardan bildirimi açmanız gerekiyor.'),
          actions: [
            TextButton(
              onPressed: () {
                openAppSettings(); // Kullanıcıyı ayarlar sekmesine yönlendir
                Navigator.of(context).pop();
              },
              child: Text('Ayarlara Git'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return SmartPlugHome(
      isDarkTheme: isDarkTheme,
      onThemeChanged: (bool value) {
        setState(() {
          isDarkTheme = value; // Tema değiştir
        });
      },
    );
  }
}
class SmartPlugHome extends StatefulWidget {
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeChanged;

  SmartPlugHome({required this.isDarkTheme, required this.onThemeChanged});

  @override
  _SmartPlugHomeState createState() => _SmartPlugHomeState();
} 
class _SmartPlugHomeState extends State<SmartPlugHome> with SingleTickerProviderStateMixin {
  bool plug1Status = false;
  bool plug2Status = false;
  bool plug3Status = false;

  String plug1Name = 'Priz 1';
  String plug2Name = 'Priz 2';
  String plug3Name = 'Priz 3';

  Timer? plug1Timer;
  Timer? plug2Timer;
  Timer? plug3Timer;

  Duration? plug1RemainingTime;
  Duration? plug2RemainingTime;
  Duration? plug3RemainingTime;

  late TabController _tabController;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  //  **Getter olarak plugStatuses tanımlandı**
  List<bool> get plugStatuses {
    return [plug1Status, plug2Status, plug3Status];
  }
  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  _initializeNotifications();
  fetchPlugStatus(); // Uygulama başlar başlamaz ESP durumunu çek

  Timer.periodic(Duration(seconds: 10), (timer) {
    fetchPlugStatus(); //  Her 10 saniyede bir güncelle
  });
}
  void _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
 Future<void> fetchPlugStatus() async {
  final String statusUrl = "http://$espIpAddress/status";
  print("ESP'den durum alınıyor: $statusUrl");

    try {
      final response = await http.get(Uri.parse(statusUrl)).timeout(httpTimeout);

      if (response.statusCode == 200) {
        final statuses = response.body.split(','); // Örneğin: "1,0,1"

        if (statuses.length == 3) {
          setState(() {
            plug1Status = statuses[0] == '1';
            plug2Status = statuses[1] == '1';
            plug3Status = statuses[2] == '1';
          });

          print("Priz 1: ${plug1Status ? 'Açık' : 'Kapalı'}");
          print("Priz 2: ${plug2Status ? 'Açık' : 'Kapalı'}");
          print("Priz 3: ${plug3Status ? 'Açık' : 'Kapalı'}");
        } else {
          print("Geçersiz yanıt formatı: ${response.body}");
        }
      } else {
        print("Durum alınamadı: ${response.statusCode}");
      }
    } catch (e) {
      print("ESP bağlantı hatası: $e");
    }
  }
// Bildirim gönderme fonksiyonu
Future<void> _showNotification(String plugName) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
          'your_channel_id', 'your_channel_name',
          importance: Importance.max, priority: Priority.high, showWhen: false);
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
      0,
      'Priz Kapandı',
      '$plugName zamanlayıcı süresi dolduğu için kapandı.',
      platformChannelSpecifics);
}
@override
void dispose() {
  _tabController.dispose();
  plug1Timer?.cancel();
  plug2Timer?.cancel();
  plug3Timer?.cancel();
  super.dispose();
}
// Kalan süreyi 'HH:MM:SS' formatında göster
String getRemainingTime(Duration? remaining) {
  if (remaining == null) return '00:00:00';
  return '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
}
// Priz zamanlayıcısını başlat
void _startTimer(
  int minutes,
  ValueChanged<bool> onChanged,
  String plugName,
  ValueChanged<Duration> onRemainingTimeUpdated,
  Timer? existingTimer,
) {
  if (minutes <= 0) return; // Geçersiz süre kontrolü

  existingTimer?.cancel();
  int totalSeconds = minutes * 60;

  Timer timer = Timer.periodic(Duration(seconds: 1), (timer) {
    if (totalSeconds > 0) {
      totalSeconds--;
      onRemainingTimeUpdated(Duration(seconds: totalSeconds));

      setState(() {
        if (plugName == plug1Name) plug1RemainingTime = Duration(seconds: totalSeconds);
        if (plugName == plug2Name) plug2RemainingTime = Duration(seconds: totalSeconds);
        if (plugName == plug3Name) plug3RemainingTime = Duration(seconds: totalSeconds);
      });
    } else {
      timer.cancel();
      onChanged(false); // Prizi kapat
      sendPlugCommand(plugName, false); // ESP'ye kapatma komutunu gönder
      _showNotification(plugName); //  Bildirim gönder
    }
  });

  setState(() {
    if (plugName == plug1Name) plug1Timer = timer;
    if (plugName == plug2Name) plug2Timer = timer;
    if (plugName == plug3Name) plug3Timer = timer;
  });
}
// Zamanlayıcı ayarlama için dialog
void _showTimerDialog(ValueChanged<int> onTimeSelected) {
  TextEditingController timerController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Zamanlayıcı Ayarla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kapanma süresini ayarlayın (dakika cinsinden):'),
            SizedBox(height: 20),
            TextField(
              controller: timerController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly, // Sadece rakamlara izin ver
                FilteringTextInputFormatter.deny(RegExp(r'\s')), // Boşlukları engelle
              ],
              decoration: InputDecoration(
                hintText: 'Dakika Girin',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              String input = timerController.text.trim();
              int? selectedTime = int.tryParse(input);

              if (input.isEmpty || selectedTime == null || selectedTime <= 0) {
                // Geçersiz girişte uyarı göster
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Hata'),
                    content: Text('Lütfen geçerli ve 0’dan büyük bir dakika değeri giriniz!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Tamam'),
                      ),
                    ],
                  ),
                );
              } else {
                // Geçerli giriş varsa zamanlayıcı başlat
                onTimeSelected(selectedTime);
                Navigator.of(context).pop();
              }
            },
            child: Text('Ayarla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal'),
          ),
        ],
      );
    },
  );
}
  void _showNameDialog() {
  TextEditingController plug1Controller = TextEditingController(text: plug1Name);
  TextEditingController plug2Controller = TextEditingController(text: plug2Name);
  TextEditingController plug3Controller = TextEditingController(text: plug3Name);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Priz İsimlerini Ayarla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plug1Controller,
              decoration: InputDecoration(labelText: 'Priz 1 Adı'),
            ),
            TextField(
              controller: plug2Controller,
              decoration: InputDecoration(labelText: 'Priz 2 Adı'),
            ),
            TextField(
              controller: plug3Controller,
              decoration: InputDecoration(labelText: 'Priz 3 Adı'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              String newPlug1Name = plug1Controller.text.trim();
              String newPlug2Name = plug2Controller.text.trim();
              String newPlug3Name = plug3Controller.text.trim();

              if (newPlug1Name.isEmpty || newPlug2Name.isEmpty || newPlug3Name.isEmpty) {
                _showErrorDialog('Priz isimleri boş bırakılamaz.');
                return;
              }

              if (newPlug1Name.toLowerCase() == newPlug2Name.toLowerCase() ||
                  newPlug1Name.toLowerCase() == newPlug3Name.toLowerCase() ||
                  newPlug2Name.toLowerCase() == newPlug3Name.toLowerCase()) {
                _showErrorDialog('Priz isimleri benzersiz olmalıdır.');
                return;
              }

              setState(() {
                if (plug1Name != newPlug1Name) {
                  plug1Timer?.cancel();
                  plug1RemainingTime = null;
                }
                if (plug2Name != newPlug2Name) {
                  plug2Timer?.cancel();
                  plug2RemainingTime = null;
                }
                if (plug3Name != newPlug3Name) {
                  plug3Timer?.cancel();
                  plug3RemainingTime = null;
                }

                plug1Name = newPlug1Name;
                plug2Name = newPlug2Name;
                plug3Name = newPlug3Name;
              });

              Navigator.of(context).pop();
            },
            child: Text('Kaydet'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('İptal'),
          ),
        ],
      );
    },
  );
}
void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Hata'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Tamam'),
        ),
      ],
    ),
  );
}
@override
Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
  title: Text(
    'Akıllı Priz (IP: $espIpAddress)', //  Güncel IP’yi göster
    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  ),
  centerTitle: true,
  elevation: 5,
  actions: [
    PopupMenuButton<int>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          value: 1,
          child: Text(widget.isDarkTheme ? 'Aydınlık Mod' : 'Karanlık Mod'),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Text('Prizlere İsim Ver'),
        ),
      ],
      onSelected: (value) {
        if (value == 1) {
          widget.onThemeChanged(!widget.isDarkTheme); // Tema değiştir
        } else if (value == 2) {
          _showNameDialog(); // Priz isimlerini ayarla
             }
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: 'Prizler'),
          Tab(text: 'Zamanlayıcı'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        _buildPlugControlView(),
        _buildTimerView(), 
      ],
    ),
  );
}
// _buildTimerView() Tanımlandı
Widget _buildTimerView() {
  return Container(
    height: MediaQuery.of(context).size.height,
    width: MediaQuery.of(context).size.width,
    decoration: BoxDecoration(
      gradient: widget.isDarkTheme
          ? LinearGradient(
              colors: [Color(0xFF1B1B1B), Color(0xFF1B1B1B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : LinearGradient(
              colors: [Color(0xFFF0F4FF), Color(0xFFCED9F4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTimerCard(plug1Name, plug1RemainingTime, plug1Status, plug1Timer, _updatePlug1),
          SizedBox(height: 20),
          _buildTimerCard(plug2Name, plug2RemainingTime, plug2Status, plug2Timer, _updatePlug2),
          SizedBox(height: 20),
          _buildTimerCard(plug3Name, plug3RemainingTime, plug3Status, plug3Timer, _updatePlug3),
        ],
      ),
    ),
  );
}
Widget _buildPlugControlView() {
  return Container(
    height: MediaQuery.of(context).size.height,
    width: MediaQuery.of(context).size.width,
    decoration: BoxDecoration(
      gradient: widget.isDarkTheme
          ? LinearGradient(
              colors: [Color(0xFF1B1B1B), Color(0xFF1B1B1B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : LinearGradient(
              colors: [Color(0xFFF0F4FF), Color(0xFFCED9F4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          Column(
            children: List.generate(3, (index) => _buildPlugCard(
              index == 0 ? plug1Name : index == 1 ? plug2Name : plug3Name, 
              index == 0 ? plug1Status : index == 1 ? plug2Status : plug3Status, 
              (value) => _togglePlug(index, value)
            )),
          ),
           SizedBox(height: 20),
      ElevatedButton(
        onPressed: resetWiFiSettings,
        child: Text("Wi-Fi Ayarlarını Sıfırla"),
      ),
        ],
      ),
    ),
  );
}
// Tek bir priz kartı oluşturmak için fonksiyon
Widget _buildPlugCardByIndex(int index) {
  return Column(
    children: [
      SwitchListTile(
  title: Text(index == 0 ? plug1Name : index == 1 ? plug2Name : plug3Name),
  value: index == 0 ? plug1Status : index == 1 ? plug2Status : plug3Status,
  onChanged: (value) {
    _togglePlug(index, value);
  },
),
      SizedBox(height: 10),
    ],
  );
}
// Tek bir prizi aç/kapat
void _togglePlug(int index, bool value) {
  setState(() {
    if (index == 0) {
      plug1Status = value;
      sendPlugCommand(plug1Name, value); // ESP’ye komut gönder
      if (!value) {
        plug1Timer?.cancel();
        plug1RemainingTime = null;
      }
    } else if (index == 1) {
      plug2Status = value;
      sendPlugCommand(plug2Name, value); // ESP’ye komut gönder
      if (!value) {
        plug2Timer?.cancel();
        plug2RemainingTime = null;
      }
    } else if (index == 2) {
      plug3Status = value;
      sendPlugCommand(plug3Name, value); // ESP’ye komut gönder
      if (!value) {
        plug3Timer?.cancel();
        plug3RemainingTime = null;
      }
    }
  });
}
void _updatePlug1(int minutes) {
  _startTimer(minutes, (value) {
    setState(() {
      plug1Status = value;
      if (!value) sendPlugCommand(plug1Name, false); //  Priz 1 için kapatma komutu
    });
  }, plug1Name, (duration) {
    setState(() {
      plug1RemainingTime = duration;
    });
  }, plug1Timer);
}

void _updatePlug2(int minutes) {
  _startTimer(minutes, (value) {
    setState(() {
      plug2Status = value;
      if (!value) sendPlugCommand(plug2Name, false); //  Priz 2 için kapatma komutu
    });
  }, plug2Name, (duration) {
    setState(() {
      plug2RemainingTime = duration;
    });
  }, plug2Timer);
}

void _updatePlug3(int minutes) {
  _startTimer(minutes, (value) {
    setState(() {
      plug3Status = value;
      if (!value) sendPlugCommand(plug3Name, false); //  Priz 3 için kapatma komutu
    });
  }, plug3Name, (duration) {
    setState(() {
      plug3RemainingTime = duration;
    });
  }, plug3Timer);
}
void _resetTimer(String plugName) {
  setState(() {
    if (plugName == plug1Name) {
      plug1Timer?.cancel();
      plug1RemainingTime = null;
    } else if (plugName == plug2Name) {
      plug2Timer?.cancel();
      plug2RemainingTime = null;
    } else if (plugName == plug3Name) {
      plug3Timer?.cancel();
      plug3RemainingTime = null;
    }
  });
}
Widget _buildPlugCard(String title, bool isPlugOn, ValueChanged<bool> onChanged) {
  return Card(
    elevation: 5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: ListTile(
      contentPadding: EdgeInsets.all(16.0),
      title: Text(title, style: TextStyle(fontSize: 20)),
      trailing: Switch(
        value: isPlugOn,
        onChanged: (value) {
          setState(() {
            onChanged(value);
            if (!value) _resetTimer(title);
          });
        },
      ),
      leading: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => ScaleTransition(child: child, scale: animation),
        child: Icon(
          isPlugOn ? Icons.power : Icons.power_off,
          key: ValueKey(isPlugOn),
          color: isPlugOn ? Colors.green : Colors.red,
          size: 40,
        ),
      ),
    ),
  );
}
Widget _buildTimerCard(String title, Duration? remainingTime, bool isPlugOn, Timer? existingTimer, ValueChanged<int> onTimeSelected) {
  double progress = remainingTime != null && existingTimer != null
      ? remainingTime.inSeconds / (existingTimer.tick + remainingTime.inSeconds).toDouble()
      : 0.0;

  return Card(
    elevation: 5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: ListTile(
      contentPadding: EdgeInsets.all(16.0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title Zamanlayıcı', style: TextStyle(fontSize: 20)),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            color: Colors.blue,
            minHeight: 8,
          ),
        ],
      ),
      subtitle: Text('Kalan süre: ${getRemainingTime(remainingTime)}'),
      trailing: ElevatedButton(
        onPressed: isPlugOn
            ? () => _showTimerDialog(onTimeSelected)
            : null,
        child: Text('Ayarla'),
      ),
    ),
  );
}
}
