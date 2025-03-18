import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sampark/Screens/chat_screen.dart';
import 'package:sampark/model/user_model.dart';

class SearchScreen extends StatefulWidget {
  final UserModel user;
  const SearchScreen(this.user, {super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResult = [];
  bool isLoading = false;

  void onSearch() async {
    String query = searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      isLoading = true;
      searchResult.clear();
    });

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .get();

      List<Map<String, dynamic>> users = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((user) => user['email'] != widget.user.email)
          .toList();

      setState(() {
        searchResult = users;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
        centerTitle: true,
        backgroundColor: Colors.yellow,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Type username here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            searchController.clear();
                            searchResult.clear();
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: onSearch,
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => onSearch(),
            ),
            const SizedBox(height: 10),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (searchResult.isEmpty && searchController.text.isNotEmpty)
              const Text(
                'No users found',
                style: TextStyle(color: Colors.grey),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: searchResult.length,
                  itemBuilder: (context, index) {
                    final user = searchResult[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user['image']),
                      ),
                      title: Text(user['name']),
                      subtitle: Text(user['email']),
                      trailing: IconButton(
                        icon: const Icon(Icons.message),
                        onPressed: () {
                          searchController.clear();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                currentUser: widget.user,
                                friensId: user['uid'],
                                friendName: user['name'],
                                friendimage: user['image'],
                              ),
                            ),
                          );
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
}
