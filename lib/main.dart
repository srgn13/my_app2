import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// =====================
// ログイン画面
// =====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _controller = TextEditingController();
  String error = "";
  String savedPassword = "hashiba";

  @override
  void initState() {
    super.initState();
    loadSavedPassword();
  }

  Future<void> loadSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedPassword = prefs.getString("appPassword") ?? "hashiba";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("パスワードを入力してください", style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "パスワード",
                ),
              ),
              const SizedBox(height: 10),
              Text(error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_controller.text == savedPassword) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ShiftHomePage()),
                    );
                  } else {
                    setState(() => error = "パスワードが違います");
                  }
                },
                child: const Text("ログイン"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================
// シフト管理画面（店舗管理）
// =====================
class ShiftHomePage extends StatefulWidget {
  const ShiftHomePage({super.key});

  @override
  State<ShiftHomePage> createState() => _ShiftHomePageState();
}

class _ShiftHomePageState extends State<ShiftHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _periodIndex = 0;

  int currentYear = 2026;
  int currentMonth = 6;

  // ★ 店舗一覧（動的に増減）
  List<String> stores = ["阿倍野", "立花", "都島", "天満"];

  // ★ 店舗ごとのスタッフ一覧
  Map<String, List<String>> storeStaff = {
    "阿倍野": ["航", "ターボーさん"],
    "立花": ["吉良", "たかちゃん", "aaa"],
    "都島": ["みなみ", "吉良"],
    "天満": ["航", "吉良", "たかちゃん"],
  };

  // シフトデータ（スタッフ名ベース）
  Map<String, Map<int, String>> shiftData = {};

    // デフォルト開始時間
  String getDefaultStartTime(String store) {
    if (store == "阿倍野" || store == "天満") return "10:00";
    return "13:00";
  }

  // 時間リスト
  List<String> timeOptions = [
    for (int h = 0; h < 24; h++)
      for (int m = 0; m < 60; m += 30)
        "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: stores.length, vsync: this);
    loadShift();
  }
  // =====================
  // 保存
  // =====================
  Future<void> saveShift() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("shiftData", jsonEncode(shiftData));
    await prefs.setString("stores", jsonEncode(stores));
    await prefs.setString("storeStaff", jsonEncode(storeStaff));
  }

  // =====================
  // 読み込み
  // =====================
  Future<void> loadShift() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("shiftData");
    final storeData = prefs.getString("stores");
    final staffData = prefs.getString("storeStaff");

    if (storeData != null) {
      stores = List<String>.from(jsonDecode(storeData));
      _tabController = TabController(length: stores.length, vsync: this);
    }

    if (staffData != null) {
      storeStaff = Map<String, List<String>>.from(
        jsonDecode(staffData).map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        ),
      );
    }

    if (data != null) {
      shiftData = Map<String, Map<int, String>>.from(
        jsonDecode(data).map(
          (key, value) => MapEntry(
            key,
            Map<int, String>.from(
              value.map((k, v) => MapEntry(int.parse(k), v)),
            ),
          ),
        ),
      );
    }

    setState(() {});
  }

  // =====================
  // 日付リスト
  // =====================
  List<int> get days {
    int lastDay = DateTime(currentYear, currentMonth + 1, 0).day;
    return _periodIndex == 0
        ? List.generate(15, (i) => i + 1)
        : List.generate(lastDay - 15, (i) => i + 16);
  }

  // =====================
  // 店舗追加
  // =====================
  Future<void> addStore() async {
    String newStore = "";

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("店舗追加"),
          content: TextField(
            decoration: const InputDecoration(labelText: "店舗名"),
            onChanged: (v) => newStore = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, newStore),
              child: const Text("追加"),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        stores.add(result);
        storeStaff[result] = [];
        _tabController = TabController(length: stores.length, vsync: this);
      });
      saveShift();
    }
  }

  // =====================
  // 店舗名変更
  // =====================
  Future<void> renameStore() async {
    final oldName = stores[_tabController.index];
    String newName = oldName;

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("$oldName の名前を変更"),
          content: TextField(
            decoration: const InputDecoration(labelText: "新しい店舗名"),
            onChanged: (v) => newName = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, newName),
              child: const Text("変更"),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        final idx = stores.indexOf(oldName);
        stores[idx] = result;

        storeStaff[result] = storeStaff[oldName]!;
        storeStaff.remove(oldName);

        _tabController = TabController(length: stores.length, vsync: this);
      });
      saveShift();
    }
  }

  // =====================
  // 店舗削除
  // =====================
  Future<void> deleteStore() async {
    if (stores.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("最後の店舗は削除できません")),
      );
      return;
    }

    final storeName = stores[_tabController.index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("$storeName を削除しますか？"),
          content: const Text("スタッフ情報も削除されます。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("削除"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        storeStaff.remove(storeName);
        stores.remove(storeName);
        _tabController = TabController(length: stores.length, vsync: this);
      });
      saveShift();
    }
  }
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final storeName = stores[_tabController.index];
    final staffList = storeStaff[storeName] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("シフト管理"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await saveShift();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("保存しました")),
              );
            },
          ),

          // ︙メニュー（店舗管理）
          PopupMenuButton(
            onSelected: (value) async {
              if (value == "addStore") addStore();
              if (value == "renameStore") renameStore();
              if (value == "deleteStore") deleteStore();
              if (value == "changePass") {
                showDialog(
                  context: context,
                  builder: (_) => PasswordChangeDialog(
                    onChanged: (newPass) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString("appPassword", newPass);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("パスワードを変更しました")),
                      );
                    },
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "addStore", child: Text("店舗追加")),
              PopupMenuItem(value: "renameStore", child: Text("店舗名変更")),
              PopupMenuItem(value: "deleteStore", child: Text("店舗削除")),
              PopupMenuItem(value: "changePass", child: Text("パスワード変更")),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (_) => setState(() {}),
          tabs: stores.map((s) => Tab(text: s)).toList(),
        ),
      ),

      // =====================
      // ここからシフト表
      // =====================
      body: Column(
        children: [
          // スタッフ追加
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text("スタッフ追加"),
                onPressed: () async {
                  String newName = "";

                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        title: const Text("スタッフ追加"),
                        content: TextField(
                          decoration: const InputDecoration(labelText: "名前"),
                          onChanged: (v) => newName = v,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("キャンセル"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, newName),
                            child: const Text("追加"),
                          ),
                        ],
                      );
                    },
                  );

                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      storeStaff[storeName]!.add(result);
                    });
                    saveShift();
                  }
                },
              ),
            ],
          ),

          // 月移動
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: () {
                  setState(() {
                    if (currentMonth == 1) {
                      currentMonth = 12;
                      currentYear--;
                    } else {
                      currentMonth--;
                    }
                  });
                },
              ),
              Text(
                "$currentYear年${currentMonth}月",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: () {
                  setState(() {
                    if (currentMonth == 12) {
                      currentMonth = 1;
                      currentYear++;
                    } else {
                      currentMonth++;
                    }
                  });
                },
              ),
            ],
          ),

          // 期間切り替え
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text("1〜15日"),
                selected: _periodIndex == 0,
                onSelected: (_) => setState(() => _periodIndex = 0),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text("16〜末日"),
                selected: _periodIndex == 1,
                onSelected: (_) => setState(() => _periodIndex = 1),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =====================
                  // 日付行（曜日つき）
                  // =====================
                  Row(
                    children: [
                      Container(width: 200, height: 50),
                      ...days.map((d) {
                        final weekday = ["日", "月", "火", "水", "木", "金", "土"]
                            [DateTime(currentYear, currentMonth, d).weekday % 7];

                        Color weekdayColor =
                            weekday == "土" ? Colors.blue : weekday == "日" ? Colors.red : Colors.black;

                        return Column(
                          children: [
                            // 日付
                            Container(
                              width: 50,
                              height: 30,
                              alignment: Alignment.center,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: (today.year == currentYear &&
                                        today.month == currentMonth &&
                                        today.day == d)
                                    ? Colors.yellow[300]
                                    : Colors.white,
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                d.toString(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: (today.year == currentYear &&
                                          today.month == currentMonth &&
                                          today.day == d)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),

                            // 曜日
                            Container(
                              width: 50,
                              height: 20,
                              alignment: Alignment.center,
                              child: Text(
                                weekday,
                                style: TextStyle(color: weekdayColor),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),

                  const SizedBox(height: 10),
                  // =====================
                  // スタッフ行（並び替え対応）
                  // =====================
                  SizedBox(
                    width: 2000,
                    child: ReorderableListView(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = staffList.removeAt(oldIndex);
                          staffList.insert(newIndex, item);
                        });
                        saveShift();
                      },
                      children: [
                        for (final name in staffList)
                          Row(
                            key: ValueKey("staff-$name"),
                            children: [
                              // 左側：並び替え・名前・編集・削除
                              SizedBox(
  width: 200,
  child: Row(
    children: [
      // 並び替えハンドル
      ReorderableDragStartListener(
        index: staffList.indexOf(name),
        child: const Icon(Icons.drag_handle),
      ),

      // ← 名前を左寄せにする部分
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            name,
            textAlign: TextAlign.left,
          ),
        ),
      ),

      const SizedBox(width: 4),

      // 編集
      GestureDetector(
        onTap: () async {
          // ここは Mayumi の既存コードそのまま
          String newName = name;
          final result = await showDialog<String>(
            context: context,
            builder: (_) {
              return AlertDialog(
                title: Text("$name の名前を変更"),
                content: TextField(
                                    decoration: const InputDecoration(
                    labelText: "新しい名前",
                  ),
                  onChanged: (v) => newName = v,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("キャンセル"),
                  ),
              
                  TextButton(
                    onPressed: () => Navigator.pop(context, newName),
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );

          if (result != null && result.isNotEmpty) {
            setState(() {
              final idx = staffList.indexOf(name);
              staffList[idx] = result;

              if (shiftData.containsKey(name)) {
                shiftData[result] = shiftData[name]!;
                shiftData.remove(name);
              }
            });
            saveShift();
          }
        },
        child: const Icon(Icons.edit, size: 18, color: Colors.green),
      ),

      const SizedBox(width: 4),

      // 削除
      GestureDetector(
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) {
              return AlertDialog(
                title: Text("$name を削除しますか？"),
                content: const Text("このスタッフのシフトも削除されます。"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("キャンセル"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("削除"),
                  ),
                ],
              );
            },
          );

          if (confirm == true) {
            setState(() {
              staffList.remove(name);
              shiftData.remove(name);
            });
            saveShift();
          }
        },
        child: const Icon(Icons.delete, size: 18, color: Colors.red),
      ),
    ],
  ),
),

                              // =====================
                              // 日付セル（時間入力・休み）
                              // =====================
                              ...days.map((d) {
                                final currentValue = shiftData[name]?[d] ?? "";

                                return GestureDetector(
                                  onTap: () async {
                                    String selected = currentValue.isEmpty
                                        ? getDefaultStartTime(storeName)
                                        : currentValue;

                                    final result = await showDialog<String>(
                                      context: context,
                                      builder: (_) {
                                        return AlertDialog(
                                          title: Text("$name の $d 日"),
                                          content: StatefulBuilder(
                                            builder: (context, setStateSB) {
                                              return DropdownButton<String>(
                                                value: selected,
                                                isExpanded: true,
                                                items: [
                                                  const DropdownMenuItem(
                                                    value: "休",
                                                    child: Text("休み"),
                                                  ),
                                                  ...timeOptions.map(
                                                    (t) => DropdownMenuItem(
                                                      value: t,
                                                      child: Text(t),
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (value) {
                                                  setStateSB(() => selected = value!);
                                                },
                                              );
                                            },
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text("キャンセル"),
                                            ),
                                            TextButton(
    onPressed: () => Navigator.pop(context, ""),
    child: const Text("削除"),
  ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, selected),
                                              child: const Text("OK"),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (result != null) {
                                      setState(() {
                                        shiftData[name] ??= {};
                                        shiftData[name]![d] = result;
                                      });
                                      saveShift();
                                    }
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    margin: const EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: currentValue == "休"
                                          ? Colors.grey[300]
                                          : Colors.white,
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: Text(
                                      currentValue,
                                      style: TextStyle(
                                        color: currentValue == "休"
                                            ? Colors.black54
                                            : Colors.black,
                                                                            ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// パスワード変更ダイアログ
// =====================
class PasswordChangeDialog extends StatefulWidget {
  final Future<void> Function(String) onChanged;
  const PasswordChangeDialog({super.key, required this.onChanged});

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  String newPass = "";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("パスワード変更"),
      content: TextField(
        obscureText: true,
        decoration: const InputDecoration(labelText: "新しいパスワード"),
        onChanged: (v) => newPass = v,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        TextButton(
          onPressed: () async {
            await widget.onChanged(newPass);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("変更"),
        ),
      ],
    );
  }
}
