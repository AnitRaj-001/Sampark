// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sampark/controller/search_controller.dart' as custom;
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key}); // No required parameters

  @override
  Widget build(BuildContext context) {
    final custom.SearchController controller = Get.put(custom.SearchController());

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
            Obx(
              () => TextField(
                onChanged: (value) {
                  controller.updateQuery(value);
                  if (value.isEmpty) controller.searchResults.clear();
                },
                onSubmitted: (_) => controller.searchUsers(),
                decoration: InputDecoration(
                  hintText: 'Type username here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.searchQuery.value.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.updateQuery('');
                            controller.searchResults.clear();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: controller.searchUsers,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Obx(
              () => controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : controller.searchResults.isEmpty && controller.searchQuery.value.isNotEmpty
                      ? const Text('No users found', style: TextStyle(color: Colors.grey))
                      : Expanded(
                          child: ListView.builder(
                            itemCount: controller.searchResults.length,
                            itemBuilder: (context, index) {
                              final user = controller.searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(backgroundImage: NetworkImage(user['image'])),
                                title: Text(user['name']),
                                subtitle: Text(user['email']),
                                trailing: IconButton(
                                  icon: const Icon(Icons.message),
                                  onPressed: () {
                                    controller.navigateToChat(
                                      user['uid'],
                                      user['name'],
                                      user['image'],
                                    );
                                    controller.searchQuery.value = '';
                                    controller.searchResults.clear();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}