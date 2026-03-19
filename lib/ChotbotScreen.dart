import 'dart:convert';
import 'dart:io';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:grokchatbot/ChatService.dart';
import 'package:path_provider/path_provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  var results = "results to be shown here";
  List<Map<String, Object>> chatHistory = [];
  ChatService chatService = ChatService();
  FlutterTts flutterTts = FlutterTts();
  final ImagePicker picker = ImagePicker();
  Color bgColor = Color(0xffe3e3e3);
  Color frColor = Color(0xffffffff);
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //exploreTTS();
  }

  exploreTTS() async {
    List<dynamic> languages = await flutterTts.getLanguages;
    languages.forEach((language) {
      print("language= $language");
    });
    flutterTts.setLanguage("en-US");

    List<dynamic> voices = await flutterTts.getVoices;
    voices.forEach((voice) {
      print("voice= ${voice.toString()}");
    });
    await flutterTts.setVoice({"name": "en-us-x-sfg-local", "locale": "en-US"});
  }

  askGenAI() async {
    var inputText = textEditingController.text;
    chatHistory.add({
      "role": "user",
      "parts": [
        {"text": inputText},
      ],
    });
    messages.insert(
      0,
      ChatMessage(user: myUser, createdAt: DateTime.now(), text: inputText),
    );
    setState(() {
      messages;
    });
    textEditingController.clear();
    results = await chatService.askGenAI(chatHistory);
    chatHistory.add({
      "role": "model",
      "parts": [
        {"text": results},
      ],
    });
    messages.insert(
      0,
      ChatMessage(user: genAI, createdAt: DateTime.now(), text: results),
    );
    setState(() {
      isLoading = false;
      messages;
    });
    if (isTTS) {
      flutterTts.speak(results);
    }
  }

  generateImages() async {
    var inputText = textEditingController.text;
    messages.insert(
      0,
      ChatMessage(user: myUser, createdAt: DateTime.now(), text: inputText),
    );
    setState(() {
      messages;
    });
    textEditingController.clear();
    results = await chatService.generateImages(inputText);
    var bytes = base64Decode(results);
    var dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/gemini${DateTime.now().microsecondsSinceEpoch}.png",
    );
    file.writeAsBytes(bytes);
    messages.insert(
      0,
      ChatMessage(
        user: genAI,
        createdAt: DateTime.now(),
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "gemini.png",
            type: MediaType.image,
          ),
        ],
      ),
    );
    setState(() {
      isLoading = false;
      messages;
    });
  }

  bool isImageSelected = false;
  late File selectedFile;
  pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    isImageSelected = true;
    selectedFile = File(image.path);
    messages.insert(
      0,
      ChatMessage(
        user: myUser,
        createdAt: DateTime.now(),
        medias: [
          ChatMedia(
            url: image.path,
            fileName: "genai.png",
            type: MediaType.image,
          ),
        ],
      ),
    );
    setState(() {
      messages;
    });
  }

  TextEditingController textEditingController = TextEditingController();
  List<ChatMessage> messages = [];
  ChatUser myUser = ChatUser(id: "1", firstName: "Hamza", lastName: "Asif");
  ChatUser genAI = ChatUser(id: "2", firstName: "GenAI", lastName: "AI");
  bool isTTS = true;
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          title: Text('Grok', style: TextStyle(color: Colors.black)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                child: Icon(
                  isTTS ? Icons.record_voice_over : Icons.voice_over_off,
                  color: Colors.black,
                ),
                onTap: () {
                  if (isTTS) {
                    isTTS = false;
                    flutterTts.stop();
                  } else {
                    isTTS = true;
                  }
                  setState(() {
                    isTTS;
                  });
                },
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: DashChat(
                      currentUser: myUser,
                      onSend: (m) {},
                      messages: messages,
                      readOnly: true,
                      messageOptions: MessageOptions(
                        currentUserContainerColor: Colors.white,
                        containerColor: Colors.black,
                        textColor: Colors.black,
                        messageTextBuilder:
                            (message, previousMessage, nextMessage) {
                              // You can detect if this message is from the bot or user
                              bool isUserMessage = message.user.id == myUser.id;

                              return Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isUserMessage
                                      ? Colors.white
                                      : Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: MarkdownBody(
                                  // <- render the message.text as Markdown
                                  data: message.text ?? "",
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      fontSize: 16,
                                      color: isUserMessage
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                    h1: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    h2: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    h3: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    listBullet: TextStyle(
                                      fontSize: 16,
                                      color: Colors.lightBlue,
                                    ),
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                  ),
                ),

                Card(
                  color: frColor,
                  margin: EdgeInsets.only(
                    bottom: 15,
                    left: 15,
                    right: 15,
                    top: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 15.0,
                      right: 5,
                      top: 5,
                      bottom: 5,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            pickImagesForUnderstanding();
                          },
                          icon: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            color: bgColor,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.attach_file_rounded,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: textEditingController,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Ask here...',
                              hintStyle: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                            });
                            if (isImageSelected ||
                                textEditingController.text.startsWith(
                                  "generate image",
                                )) {
                              generateImages();
                            } else if (isImageSelectedForUnderstanding) {
                              understandFiles();
                            } else {
                              askGenAI();
                            }
                          },
                          icon: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            color: Colors.black,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.black))
                : messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 150.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("assets/grok.png", width: 150),
                          Text(
                            "Fact Checker",
                            style: TextStyle(color: Colors.black, fontSize: 30),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  bool isImageSelectedForUnderstanding = false;
  pickImagesForUnderstanding() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    isImageSelectedForUnderstanding = true;
    isImageSelected = false;
    selectedFile = File(image.path);
    messages.insert(
      0,
      ChatMessage(
        user: myUser,
        createdAt: DateTime.now(),
        medias: [
          ChatMedia(
            url: image.path,
            fileName: "genai.png",
            type: MediaType.image,
          ),
        ],
      ),
    );
    setState(() {
      messages;
    });
  }

  understandFiles() async {
    var inputText = textEditingController.text;
    messages.insert(
      0,
      ChatMessage(user: myUser, createdAt: DateTime.now(), text: inputText),
    );
    setState(() {
      messages;
    });
    textEditingController.clear();
    if (isImageSelectedForUnderstanding) {
      results = await chatService.understandImages(inputText, selectedFile);
      isImageSelectedForUnderstanding = false;
    }
    messages.insert(
      0,
      ChatMessage(user: genAI, createdAt: DateTime.now(), text: results),
    );
    setState(() {
      isLoading = false;
      messages;
    });
  }
}
