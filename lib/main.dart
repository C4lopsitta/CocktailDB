import 'dart:convert';
import 'package:cocktail/favorites_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'cocktail.dart';
import 'cocktail_detail.dart';
import 'favorites.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();

  // Creazione di un metodo of()
  // Riceve uno context di una classe stato
  // Ritorna lo stato "antenato" più vicino del tipo indicato
  // Questo metodo lo usiamo per accedere al metodo changeTheme() di _MyAppState da _MyHomePageState (due stati differenti)
  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CocktailDB',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: const MyHomePage(title: 'CocktailDB'),
    );
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  bool _nightMode = false;
  bool _hasSearched = false;

  TextEditingValue textEditingValue = const TextEditingValue();
  String _lastSelectedSuggestion = "";
  String _errorTextAutocomplete = "";
  List<Cocktail> cocktails = [];
  // stringa di input nella ricerca del cocktail
  String _inputString = "";

  String selectedLanguage = "EN";
  List<String> languages = ["EN", "IT", "ES", "DE", "FR"];


  @override
  void initState() {
    // Imposta lo switch della nightmode nell'impostazione giusta all'avvio
    // (nel caso il tema di sistema sia scuro)

    // Ottiene la luminosità impostata
    Brightness brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
    if(brightness == Brightness.dark){
      _nightMode = true;
    }
    super.initState();
  }

  final MaterialStateProperty<Icon?> lightIcon =
  MaterialStateProperty.resolveWith<Icon?>(
        (Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Icon(Icons.nightlight);
      }
      return const Icon(Icons.sunny);
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: IconButton(icon: const Icon(Icons.star), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoriteList())); },)
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Switch(
                  thumbIcon: lightIcon,
                  value: _nightMode,
                  onChanged: (bool value) {

                    setState(() {
                      _nightMode = value;
                      if(_nightMode) {
                        MyApp.of(context).changeTheme(ThemeMode.dark);
                      } else {
                        MyApp.of(context).changeTheme(ThemeMode.light);
                      }
                    });
                  })
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
            child: DropdownButton(
              value: selectedLanguage,
              items: languages.map((String language) {
                return DropdownMenuItem(
                  value: language,
                  child: Text(language),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedLanguage = newValue!;
                  if(_hasSearched) {
                    searchCocktails();
                  }
                });
              },
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text("Search for a cocktail", style: TextStyle(fontSize: 15),),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return [];
                  }
                  final suggestions = await fetchSuggestions(textEditingValue.text);
                  // tiene traccia del valore che è effettivamente scritto nel form
                  _inputString = textEditingValue.text;
                  return suggestions;
                },
                onSelected: (String selection) {
                  textEditingValue = TextEditingValue(text: selection);
                },
              ),
            ),
            Text(_errorTextAutocomplete, style: const TextStyle(color: Colors.red),),
            const SizedBox(height: 10,),
            ElevatedButton(onPressed: () {
              // Seconda condizione: Se il cocktail SELEZIONATO è diverso dall'ultimo selezionato
                if(textEditingValue.text.isNotEmpty && textEditingValue.text != _lastSelectedSuggestion){
                  searchCocktails();
                  _lastSelectedSuggestion = textEditingValue.text;
                  _errorTextAutocomplete = "";
                }
                else{
                  setState(() {
                    _errorTextAutocomplete = "Please select a cocktail from the list";
                  });
                }

                // Se il cocktail SCRITTO è uguale all'ultimo selezionato
                if(_inputString == _lastSelectedSuggestion){
                  _errorTextAutocomplete = "";
                }
                _hasSearched = true;
              }, child: const Text("Search"),),
            const SizedBox(height: 50,),
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.builder(
                itemCount: cocktails.length,
                itemBuilder: (BuildContext context, int index) => buildCard(context, index),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              ),
            ),
            const SizedBox(height: 100,),
          ],
        ),
      )
    );
  }

  Widget buildCard(BuildContext context, int index){
    return FutureBuilder<bool>(
      future: Favorites.isFavorite(cocktails[index].id),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        bool isFavorite = snapshot.data ?? false;
        return GestureDetector(
          child: Card(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 30,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cocktails[index].name, style: const TextStyle(fontWeight: FontWeight.bold),),
                        Text(cocktails[index].category!),
                      ],
                    ),
                    const SizedBox(width: 20,),
                    ...generateTags(cocktails[index], getScreenType(context)), // x smontare lista in singoli elementi,
                    const Spacer(),
                    IconButton(
                      icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                      onPressed: () {
                        setState(() {
                          if (isFavorite) {
                            Favorites.removeFavorite(cocktails[index].id);
                          } else {
                            Favorites.addFavorite(cocktails[index].id);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          onTap: () => {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TheCocktail(cocktail: cocktails[index], language: selectedLanguage,)))
          },
        );
      },
    );
  }

  Future searchCocktails() async {
    const domain = 'www.thecocktaildb.com';
    const path = '/api/json/v1/1/search.php';
    Map<String, dynamic> parameters = {'s': textEditingValue.text};
    Uri uri = Uri.https(domain, path, parameters);
    http.get(uri).then((result) {

      final cocktailsData = json.decode(result.body);
      final cocktailsDataItem = cocktailsData['drinks'];

      List<Cocktail> cocktails = cocktailsDataItem.map<Cocktail>((json) =>
          Cocktail.fromJson(json, selectedLanguage)).toList();
      setState(() {
        this.cocktails = cocktails;
      });
    });
  }

  Future<List<String>> fetchSuggestions(String query) async {
    final response = await http.get(Uri.parse('https://thecocktaildb.com/api/json/v1/1/search.php?s=$query'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> suggestions = [];
      for (var item in data['drinks'] ?? "") {
        suggestions.add(item['strDrink']);
      }
      return suggestions;
    } else {
      throw Exception('Failed to fetch suggestions');
    }
  }
}
