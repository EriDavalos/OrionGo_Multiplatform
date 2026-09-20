import 'package:flutter/material.dart';
import 'painters/azimuthalgrid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainPage(),
    );
  }
}

//////////////////// MAIN PAGE ////////////////////

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  int selectedIndex = 0;

  final pages = [
    HomePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Main(onSelect: (i) {
        setState(() => selectedIndex = i);
        Navigator.pop(context);
      }),

      body: Stack(
        children: [
          pages[selectedIndex],
          //Este crea el botón de menú
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            child: Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            ),
          ),
        ],
      )
    );
  }
}

//////////////////// MENU ////////////////////

class Main extends StatelessWidget {

  final Function(int) onSelect;

  const Main({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Drawer(

      child: ListView(
        children: [

          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Menú',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          ListTile(
            leading: Icon(Icons.home),
            title: Text('Inicio'),
            onTap: () => onSelect(0),
          ),

          /*
          ListTile(
            leading: Icon(Icons.devices),
            title: Text('Monturas'),
            onTap: () => onSelect(1),
          ),

          ListTile(
            leading: Icon(Icons.contactless_rounded),
            title: Text('Remoto'),
            onTap: () => onSelect(2),
          ),

          ListTile(
            leading: Icon(Icons.motion_photos_on_rounded),
            title: Text('Ajustes de motor'),
            onTap: () => onSelect(3),
          ),*/

          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Configuración'),
            onTap: () => onSelect(1),
          ),
          
        ],
      ),
    );
  }
}

//////////////////// HOME ////////////////////

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override

  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Color.fromARGB(255, 15, 15, 15),

      body: LayoutBuilder(
        
        builder: (context, constraints) {

          return CustomPaint(
            size: Size(
              constraints.maxWidth,
              constraints.maxHeight,
            ),
            painter: AzimuthalGridPainter(),
          );
        },
        
      )
            
    );
  }

}

//////////////////// SETTINGS ////////////////////

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Configuraciones"),),

      body: Center(
        child: Text("Este es la página de configuraciones"),
      ),
    );
  }
}