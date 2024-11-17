import 'package:chat/call.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List messages = [];

  final String senderUsername = 'user1';
  final String receiverUsername = 'user3';
  String? conversationId;
  String whosend = '';
  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    getConversationId().then((_) {
      checkAndCreateConversation().then((_) {
        getMessages();
        setupSocket();
      });
    });
  }

  void setupSocket() {
    socket = IO.io('http://196.188.168.149:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket?.connect();

    socket?.onConnect((_) {
      print('Connected to Socket.IO server');
      if (conversationId != null) {
        socket?.emit('joinConversation', conversationId);
      }
    });

    socket?.on('newMessage', (data) {
      setState(() {
        messages.add(data);
      });
      _scrollToBottom();
    });

    socket?.onDisconnect((_) {
      print('Disconnected from server');
    });
  }

  Future<void> checkAndCreateConversation() async {
    var url = Uri.parse('http://196.188.168.149:3000/api/conversations');
    var data = {
      'senderUsername': senderUsername,
      'receiverUsername': receiverUsername,
    };

    var response = await http.get(
      Uri.parse(
          'http://196.188.168.149:3000/api/conversations/$senderUsername/$receiverUsername'),
    );

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      conversationId = responseData['conversationId'];
      await saveConversationId(conversationId!);
      if (socket != null && socket!.connected) {
        socket?.emit('joinConversation', conversationId);
      }
    } else {
      var createResponse = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (createResponse.statusCode == 200) {
        var createResponseData = json.decode(createResponse.body);
        conversationId = createResponseData['conversationId'];
        await saveConversationId(conversationId!);
        if (socket != null && socket!.connected) {
          socket?.emit('joinConversation', conversationId);
        }
      }
    }
  }

  Future<void> saveConversationId(String conversationId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversationId', conversationId);
  }

  Future<void> getConversationId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    conversationId = prefs.getString('conversationId');
    setState(() {});
  }

  Future<void> sendMessage() async {
    if (_messageController.text.isEmpty || conversationId == null) {
      return;
    }

    final messageData = {
      'conversationId': conversationId,
      'senderUsername': senderUsername,
      'receiverUsername': receiverUsername,
      'message': _messageController.text,
    };

    final response = await http.post(
      Uri.parse('http://196.188.168.149:3000/api/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(messageData),
    );

    if (response.statusCode == 200) {
      _messageController.clear();
      _scrollToBottom();
      socket?.emit('sendMessage', messageData);
    } else {
      print('Failed to send message');
    }
  }

  Future<void> getMessages() async {
    if (conversationId == null) return;

    final response = await http.get(
      Uri.parse(
          'http://196.188.168.149:3000/api/messages/conversation/$conversationId'),
    );

    if (response.statusCode == 200) {
      setState(() {
        messages = json.decode(response.body);
      });
      _scrollToBottom();
    } else {
      print('Failed to fetch messages');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Felegulegn'),
        backgroundColor: Colors.blueAccent.withOpacity(0.2),
        elevation: 0,
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.video_call), // Icon for the button
        //     onPressed: () {
        //       // Use Navigator to push to the CallPage
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder: (context) => CallPage(),
        //         ),
        //       );
        //     },
        //   ),
        // ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];

                  // Check who sent the message based on 'whosend'
                  bool isWhosend = message['whosend'] == senderUsername;
                  print("ooooo" + isWhosend.toString());

                  final DateTime timestamp =
                      DateTime.parse(message['timestamp']);
                  final String timeAgo =
                      timeago.format(timestamp, locale: 'en');

                  // Align the message based on the 'whosend' variable
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    alignment: isWhosend
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isWhosend
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                          decoration: BoxDecoration(
                            color: isWhosend
                                ? Colors.blueAccent
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: isWhosend
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['message'],
                                style: TextStyle(
                                  color:
                                      isWhosend ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  color: isWhosend
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter message...',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    sendMessage();
                  },
                  color: Colors.blueAccent,
                  iconSize: 30,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
