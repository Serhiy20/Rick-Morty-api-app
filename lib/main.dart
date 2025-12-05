import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(const MyApp());
}

const String baseUrl = 'https://rickandmortyapi.com/api';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CharacterListProvider()),
      ],
      child: MaterialApp(
        title: 'Rick & Morty Browser',
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: const CharacterListScreen(),
      ),
    );
  }
}

class Character {
  final int id;
  final String name;
  final String status;
  final String species;
  final String image;
  final String locationName;
  final List<String> episodeUrls;

  Character({
    required this.id,
    required this.name,
    required this.status,
    required this.species,
    required this.image,
    required this.locationName,
    required this.episodeUrls,
  });

  factory Character.fromJson(Map<String, dynamic> j) {
    return Character(
      id: j['id'] as int,
      name: j['name'] ?? 'Unknown',
      status: j['status'] ?? 'unknown',
      species: j['species'] ?? 'unknown',
      image: j['image'] ?? '',
      locationName: (j['location']?['name']) ?? 'unknown',
      episodeUrls: List<String>.from(j['episode'] ?? []),
    );
  }
}

class Episode {
  final int id;
  final String name;
  final String airDate;
  final String episodeCode;
  final List<String> characterUrls;

  Episode({
    required this.id,
    required this.name,
    required this.airDate,
    required this.episodeCode,
    required this.characterUrls,
  });

  factory Episode.fromJson(Map<String, dynamic> j) {
    return Episode(
      id: j['id'] as int,
      name: j['name'] ?? 'Unknown',
      airDate: j['air_date'] ?? 'Unknown',
      episodeCode: j['episode'] ?? 'Unknown',
      characterUrls: List<String>.from(j['characters'] ?? []),
    );
  }
}


class ApiService {
  final client = http.Client();

  Future<Map<String, dynamic>> fetchCharacters({int page = 1, String? name}) async {
    final uri = Uri.parse('$baseUrl/character').replace(queryParameters: {
      'page': page.toString(),
      if (name != null && name.isNotEmpty) 'name': name,
    });
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else if (res.statusCode == 404) {
      return {'info': null, 'results': []};
    } else {
      throw Exception('Failed to load characters: ${res.statusCode}');
    }
  }

  Future<Character> fetchCharacterById(int id) async {
    final uri = Uri.parse('$baseUrl/character/$id');
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      return Character.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to load character');
    }
  }

  Future<List<Episode>> fetchEpisodesByUrls(List<String> urls) async {
    if (urls.isEmpty) return [];
    final ids = urls.map((u) => u.split('/').last).toSet().toList();
    final uri = Uri.parse('$baseUrl/episode/${ids.join(",")}');
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.map<Episode>((e) => Episode.fromJson(e)).toList();
      } else {
        return [Episode.fromJson(decoded)];
      }
    } else {
      throw Exception('Failed to load episodes');
    }
  }

  Future<Episode> fetchEpisodeById(int id) async {
    final uri = Uri.parse('$baseUrl/episode/$id');
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      return Episode.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to load episode');
    }
  }

  Future<List<Character>> fetchCharactersByUrls(List<String> urls) async {
    if (urls.isEmpty) return [];
    final ids = urls.map((u) => u.split('/').last).toSet().toList();
    final uri = Uri.parse('$baseUrl/character/${ids.join(",")}');
    final res = await client.get(uri);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.map<Character>((c) => Character.fromJson(c)).toList();
      } else {
        return [Character.fromJson(decoded)];
      }
    } else {
      throw Exception('Failed to load characters for episode');
    }
  }
}


enum LoadingStatus { idle, loading, error, empty }

class CharacterListProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  List<Character> characters = [];
  int _currentPage = 1;
  String _currentQuery = '';
  String? _nextUrl;
  bool _isFetching = false;
  String? errorMessage;
  LoadingStatus status = LoadingStatus.idle;

  CharacterListProvider() {
    fetchFirstPage();
  }

  Future<void> fetchFirstPage({String query = ''}) async {
    _currentPage = 1;
    _currentQuery = query;
    characters = [];
    _nextUrl = null;
    errorMessage = null;
    status = LoadingStatus.loading;
    notifyListeners();
    try {
      final json = await api.fetchCharacters(page: _currentPage, name: _currentQuery.isNotEmpty ? _currentQuery : null);
      final info = json['info'];
      final results = (json['results'] as List).cast<dynamic>();
      characters = results.map((e) => Character.fromJson(e)).toList();
      if (results.isEmpty) {
        status = LoadingStatus.empty;
      } else {
        status = LoadingStatus.idle;
        _nextUrl = info != null ? info['next'] as String? : null;
      }
    } catch (e) {
      status = LoadingStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> fetchNextPage() async {
    if (_isFetching) return;
    if (_nextUrl == null) return;
    _isFetching = true;
    notifyListeners();
    try {
      _currentPage += 1;
      final json = await api.fetchCharacters(page: _currentPage, name: _currentQuery.isNotEmpty ? _currentQuery : null);
      final info = json['info'];
      final results = (json['results'] as List).cast<dynamic>();
      characters.addAll(results.map((e) => Character.fromJson(e)));
      _nextUrl = info != null ? info['next'] as String? : null;
      status = characters.isEmpty ? LoadingStatus.empty : LoadingStatus.idle;
    } catch (e) {
      status = LoadingStatus.error;
      errorMessage = e.toString();
    }
    _isFetching = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchFirstPage(query: _currentQuery);
  }

  void search(String query) {
    fetchFirstPage(query: query.trim());
  }
}


class CharacterListScreen extends StatefulWidget {
  const CharacterListScreen({super.key});

  @override
  State<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late CharacterListProvider provider;

  @override
  void initState() {
    super.initState();
    provider = Provider.of<CharacterListProvider>(context, listen: false);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= (maxScroll - 300)) {
      provider.fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rick & Morty — Персонажі'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Consumer<CharacterListProvider>(
                builder: (context, p, _) {
                  if (p.status == LoadingStatus.loading && p.characters.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (p.status == LoadingStatus.error && p.characters.isEmpty) {
                    return ErrorView(
                      message: p.errorMessage ?? 'Помилка',
                      onRetry: () => p.fetchFirstPage(query: _searchController.text),
                    );
                  } else if (p.status == LoadingStatus.empty && p.characters.isEmpty) {
                    return EmptyView(message: 'Нічого не знайдено');
                  }

                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: p.characters.length + 1,
                      itemBuilder: (context, index) {
                        if (index < p.characters.length) {
                          final c = p.characters[index];
                          return CharacterCard(
                            character: c,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CharacterDetailScreen(characterId: c.id),
                                ),
                              );
                            },
                          );
                        } else {
                          if (p.status == LoadingStatus.loading) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else {
                            return const SizedBox(height: 32);
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Пошук по імені персонажа',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) {
                Provider.of<CharacterListProvider>(context, listen: false).search(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final q = _searchController.text;
              Provider.of<CharacterListProvider>(context, listen: false).search(q);
            },
            child: const Text('Знайти'),
          )
        ],
      ),
    );
  }
}

class CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback? onTap;
  const CharacterCard({super.key, required this.character, this.onTap});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'alive':
        return Colors.green;
      case 'dead':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: character.image,
            width: 64,
            height: 64,
            placeholder: (_, __) => Container(width: 64, height: 64, child: const Center(child: CircularProgressIndicator())),
            errorWidget: (_, __, ___) => Container(
              width: 64,
              height: 64,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            ),
            fit: BoxFit.cover,
          ),
        ),
        title: Text(character.name),
        subtitle: Text(character.species),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 12, color: _statusColor(character.status)),
            const SizedBox(height: 6),
            Text(character.status, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}


class CharacterDetailScreen extends StatefulWidget {
  final int characterId;
  const CharacterDetailScreen({super.key, required this.characterId});

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  final ApiService api = ApiService();
  Character? character;
  List<Episode> episodes = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCharacter();
  }

  Future<void> _loadCharacter() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final c = await api.fetchCharacterById(widget.characterId);
      final eps = await api.fetchEpisodesByUrls(c.episodeUrls);
      setState(() {
        character = c;
        episodes = eps;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі персонажа'),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : (error != null)
                ? ErrorView(message: error!, onRetry: _loadCharacter)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CachedNetworkImage(
                              imageUrl: character!.image,
                              width: 120,
                              height: 120,
                              placeholder: (_, __) => const SizedBox(width: 120, height: 120, child: Center(child: CircularProgressIndicator())),
                              errorWidget: (_, __, ___) => Container(width: 120, height: 120, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(character!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('Статус: ${character!.status}'),
                                  const SizedBox(height: 4),
                                  Text('Вид: ${character!.species}'),
                                  const SizedBox(height: 4),
                                  Text('Локація: ${character!.locationName}'),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Епізоди:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (episodes.isEmpty) const Text('Немає епізодів')
                        else ...episodes.map((ep) => ListTile(
                          title: Text(ep.name),
                          subtitle: Text('${ep.episodeCode} • ${ep.airDate}'),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => EpisodeScreen(episodeId: ep.id)),
                            );
                          },
                        )).toList(),
                      ],
                    ),
                  ),
      ),
    );
  }
}


class EpisodeScreen extends StatefulWidget {
  final int episodeId;
  const EpisodeScreen({super.key, required this.episodeId});

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  final ApiService api = ApiService();
  Episode? episode;
  List<Character> characters = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEpisode();
  }

  Future<void> _loadEpisode() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final e = await api.fetchEpisodeById(widget.episodeId);
      final chars = await api.fetchCharactersByUrls(e.characterUrls);
      setState(() {
        episode = e;
        characters = chars;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Епізод'),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : (error != null)
                ? ErrorView(message: error!, onRetry: _loadEpisode)
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(episode!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Код: ${episode!.episodeCode}'),
                        const SizedBox(height: 4),
                        Text('Дата виходу: ${episode!.airDate}'),
                        const SizedBox(height: 12),
                        const Text('Персонажі в серії:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: characters.isEmpty
                              ? const Text('Немає персонажів')
                              : ListView.builder(
                                  itemCount: characters.length,
                                  itemBuilder: (context, idx) {
                                    final c = characters[idx];
                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: c.image,
                                          width: 48,
                                          height: 48,
                                          placeholder: (_, __) => const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator())),
                                          errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      title: Text(c.name),
                                      subtitle: Text(c.species),
                                      onTap: () {
                                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CharacterDetailScreen(characterId: c.id)));
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}


class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Спробувати знову')),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}