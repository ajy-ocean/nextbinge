import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("dotenv loaded successfully");
    print("TMDB key from .env: ${dotenv.env['TMDB_API_KEY'] ?? 'NOT_FOUND'}");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entertainment Recs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey, useMaterial3: true),
      home: const GenreSelector(),
    );
  }
}

class GenreSelector extends StatefulWidget {
  const GenreSelector({super.key});

  @override
  State<GenreSelector> createState() => _GenreSelectorState();
}

class _GenreSelectorState extends State<GenreSelector> {
  String? selectedGenre;

  final List<String> genres = [
    'Action',
    'Comedy',
    'Drama',
    'Horror',
    'Romance',
    'Thriller',
    'Science Fiction',
    'Animation',
    'Adventure',
    'Fantasy',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a Genre'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: genres.length,
              itemBuilder: (context, index) {
                final genre = genres[index];
                return ListTile(
                  title: Text(genre),
                  selected: selectedGenre == genre,
                  selectedTileColor: Colors.blueGrey.withOpacity(0.2),
                  onTap: () {
                    setState(() {
                      selectedGenre = genre;
                    });
                  },
                );
              },
            ),
          ),
          if (selectedGenre != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecsScreen(genre: selectedGenre!),
                    ),
                  );
                },
                icon: const Icon(Icons.movie),
                label: const Text('Get Recommendations'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RecsScreen extends StatelessWidget {
  final String genre;

  const RecsScreen({super.key, required this.genre});

  static const Map<String, int> genreIds = {
    'Action': 28,
    'Adventure': 12,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Documentary': 99,
    'Drama': 18,
    'Family': 10751,
    'Fantasy': 14,
    'History': 36,
    'Horror': 27,
    'Music': 10402,
    'Mystery': 9648,
    'Romance': 10749,
    'Science Fiction': 878,
    'TV Movie': 10770,
    'Thriller': 53,
    'War': 10752,
    'Western': 37,
  };

  Future<List<Map<String, dynamic>>> fetchMovieRecs(String selectedGenre) async {
    final apiKey = dotenv.env['TMDB_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      return [
        {'title': 'Error: TMDB API key not found.', 'posterPath': null},
      ];
    }

    final genreId = genreIds[selectedGenre] ?? 28;

    final url = Uri.parse(
      'https://api.themoviedb.org/3/discover/movie'
      '?api_key=$apiKey'
      '&with_genres=$genreId'
      '&sort_by=popularity.desc'
      '&page=1',
    );

    const maxRetries = 3;
    var lastError = '';

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print('Attempt ${attempt + 1}/$maxRetries → $selectedGenre (genre ID: $genreId)');

        final response = await http.get(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () => http.Response('Request timed out', 408),
            );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List<dynamic>;

          if (results.isEmpty) {
            return [
              {'title': 'No movies found for this genre right now.', 'posterPath': null},
            ];
          }

          return results.take(10).map((movie) {  // increased to 10 so grid looks better
            return {
              'title': movie['title'] as String? ?? 'Untitled',
              'posterPath': movie['poster_path'] as String?,
            };
          }).toList();
        } else {
          lastError = 'TMDB returned ${response.statusCode} - ${response.reasonPhrase}';
          print(lastError);
        }
      } catch (e) {
        lastError = e.toString();
        print('Attempt ${attempt + 1} failed: $e');

        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }

    return [
      {'title': 'Failed after $maxRetries attempts.', 'posterPath': null},
      {'title': lastError, 'posterPath': null},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$genre Recommendations'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchMovieRecs(genre),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          final recommendations = snapshot.data ?? [];

          if (recommendations.isEmpty) {
            return const Center(child: Text('No recommendations found.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,              // 2 items per row
              childAspectRatio: 0.68,         // taller than wide → good for posters + title
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final movie = recommendations[index];
              final title = movie['title'] as String;
              final posterPath = movie['posterPath'] as String?;

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: posterPath != null && posterPath.isNotEmpty
                          ? Image.network(
                              'https://image.tmdb.org/t/p/w342$posterPath',  // larger size: w342
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[850],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                    size: 60,
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[850],
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white54,
                                size: 80,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}