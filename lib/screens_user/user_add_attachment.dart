import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../models/user_transaction.dart';
import '../../transmittal_screens/uploader_menu.dart';
import '../../widgets/navBar.dart';
// import '../reprocessing/uploader_send_reprocessed.dart';
import 'user_menu.dart';
import 'user_send_attachment.dart';
import 'user_upload.dart';

class UserAddAttachment extends StatefulWidget {
  final Transaction transaction;
  final List<String> selectedDetails;
  final bool isReprocessing;

  const UserAddAttachment({
    Key? key,
    required this.transaction,
    required this.selectedDetails,
    this.isReprocessing = false,
  }) : super(key: key);

  @override
  _UserAddAttachmentState createState() => _UserAddAttachmentState();
}

String sanitizeFileName(String fileName) {
  final RegExp regExp = RegExp(r'[^a-zA-Z0-9.]');
  return fileName.replaceAll(regExp, '');
}

class _UserAddAttachmentState extends State<UserAddAttachment> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> attachments = [];
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const UserMenuWindow()),
        // );
        break;
    }
  }

  Future<void> _pickFile() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a file source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_album),
                title: const Text('Images'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Local Storage'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromLocalStorage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List> _compressImage(Uint8List imageData) async {
    img.Image? image = img.decodeImage(imageData);
    if (image != null) {
      img.Image resizedImage = img.copyResize(image, width: 800);
      return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));
    }
    return imageData;
  }

  Future<void> _pickFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      String fileName = sanitizeFileName(photo.name);
      Uint8List imageData = await photo.readAsBytes();
      Uint8List compressedImageData = await _compressImage(imageData);

      setState(() {
        attachments.add({
          'name': fileName,
          'status': 'Selected',
          'bytes': compressedImageData,
          'size': compressedImageData.length,
          'isLoading': true, // Start loading state
          'isUploading': false,
          'uploadProgress': 0.0,
        });
      });

      // Simulate loading time for demo purposes
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          attachments[attachments.length - 1]['isLoading'] =
              false; // End loading state
        });
      });

      developer.log('File picked from camera: $fileName');
    } else {
      developer.log('Camera picking cancelled');
    }
  }

  Future<void> _pickFromImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      for (var image in images) {
        String fileName = sanitizeFileName(image.name);
        Uint8List imageData = await image.readAsBytes();
        Uint8List compressedImageData = await _compressImage(imageData);

        setState(() {
          attachments.add({
            'name': fileName,
            'status': 'Selected',
            'bytes': compressedImageData,
            'size': compressedImageData.length,
            'isLoading': true, // Start loading state
            'isUploading': false,
            'uploadProgress': 0.0,
          });
        });

        // Simulate loading time for demo purposes
        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            attachments[attachments.length - 1]['isLoading'] =
                false; // End loading state
          });
        });

        developer.log('File picked from images: $fileName');
      }
    } else {
      developer.log('Image picking cancelled');
    }
  }

  Future<void> _pickFromLocalStorage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null && result.files.isNotEmpty) {
      for (var file in result.files) {
        String fileName = sanitizeFileName(file.name ?? 'Unknown');
        Uint8List? fileBytes = file.bytes;
        if (fileBytes != null) {
          Uint8List compressedImageData = await _compressImage(fileBytes);

          setState(() {
            attachments.add({
              'name': fileName,
              'status': 'Selected',
              'bytes': compressedImageData,
              'size': compressedImageData.length,
              'isLoading': true, // Start loading state
              'isUploading': false,
              'uploadProgress': 0.0,
            });
          });

          // Simulate loading time for demo purposes
          Future.delayed(Duration(seconds: 1), () {
            setState(() {
              attachments[attachments.length - 1]['isLoading'] =
                  false; // End loading state
            });
          });

          developer.log('File picked: $fileName');
        }
      }
    } else {
      developer.log('File picking cancelled');
    }
  }

  Future<void> _uploadFile(PlatformFile pickedFile) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://192.168.131.94/localconnect/UserUploadUpdate/upload_asset.php'),
      );

      // Add the 'doc_type', 'doc_no', and 'date_trans' fields to the request
      request.fields['doc_type'] = widget.transaction.docType.toString();
      request.fields['doc_no'] = widget.transaction.docNo.toString();
      request.fields['date_trans'] = widget.transaction.dateTrans.toString();

      // Sanitize the filename
      String sanitizedFileName = sanitizeFileName(pickedFile.name);

      // Add the file to the request
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          pickedFile.bytes!,
          filename: sanitizedFileName,
        ),
      );

      developer.log('Uploading file: ${pickedFile.name}');
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        developer.log('Upload response: $responseBody');

        try {
          var result = jsonDecode(responseBody);
          if (result['status'] == 'success') {
            setState(() {
              attachments.removeWhere(
                  (element) => element['name'] == sanitizedFileName);
              attachments
                  .add({'name': sanitizedFileName, 'status': 'Uploaded'});
              developer.log('Attachments array after uploading: $attachments');
            });

            // Show success dialog or handle success scenario
          } else {
            _showDialog(
              context,
              'Error',
              'File upload failed: ${result['message']}',
            );
            developer.log('File upload failed: ${result['message']}');
          }
        } catch (e) {
          _showDialog(
            context,
            'Error',
            'Error uploading file. Please try again later.',
          );
          developer.log('Error parsing upload response: $e');
        }
      } else {
        _showDialog(
          context,
          'Error',
          'File upload failed with status: ${response.statusCode}',
        );
        developer.log('File upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error uploading file: $e');
      _showDialog(
        context,
        'Error',
        'Error uploading file. Please try again later.',
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(Uint8List imageBytes, Map<String, dynamic> attachment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('File Name: ${attachment['name']}'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9, // Adjust the width
            height:
                MediaQuery.of(context).size.height * 0.7, // Adjust the height
            child: InteractiveViewer(
              child: Image.memory(imageBytes),
              boundaryMargin: EdgeInsets.zero,
              minScale: 0.1,
              maxScale: 3.0,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 79, 128, 189),
        toolbarHeight: 77,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 60,
                  height: 55,
                ),
                const SizedBox(width: 8),
                const Text(
                  'For Uploading',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Tahoma',
                    color: Color.fromARGB(255, 233, 227, 227),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: EdgeInsets.only(right: screenSize.width * 0.02),
                  child: IconButton(
                    onPressed: () {
                      // Handle notifications button tap
                    },
                    icon: const Icon(
                      Icons.notifications,
                      size: 24,
                      color: Color.fromARGB(255, 233, 227, 227),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UploaderMenuWindow()),
                    );
                  },
                  icon: const Icon(
                    Icons.person,
                    size: 24,
                    color: Color.fromARGB(255, 233, 227, 227),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 10,
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.all(24.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            onPressed: _pickFile,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Click to upload',
                    style: TextStyle(
                      fontSize: 20.0,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  Text(
                    'Max. File Size: 5Mb',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.0),
          Expanded(
            child: ListView.builder(
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                var attachment = attachments[index];
                int sizeInBytes =
                    (attachment['bytes'] as Uint8List).lengthInBytes;
                String sizeString;

                if (sizeInBytes >= 1048576) {
                  // Size in MB
                  double sizeInMB = sizeInBytes / 1048576;
                  sizeString = '${sizeInMB.toStringAsFixed(2)} MB';
                } else if (sizeInBytes >= 1024) {
                  // Size in KB
                  double sizeInKB = sizeInBytes / 1024;
                  sizeString = '${sizeInKB.toStringAsFixed(2)} KB';
                } else {
                  // Size in bytes
                  sizeString = '$sizeInBytes bytes';
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    // Rounded corners
                    side: BorderSide(color: Colors.blue, width: 2), // Border
                  ),
                  child: ListTile(
                    leading: attachment['isLoading']
                        ? const CircularProgressIndicator()
                        : Image.memory(
                            attachment['bytes'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                    title: Text(attachment['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Size: $sizeString'),
                        if (attachment['isUploading'])
                          LinearProgressIndicator(
                            value: attachment['uploadProgress'] / 100,
                            minHeight: 5,
                            color: Colors.green,
                            backgroundColor: Colors.grey[200],
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_in),
                          onPressed: () {
                            _showImageDialog(attachment['bytes'], attachment);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              attachments.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!attachment['isUploading'] &&
                          !attachment['isLoading']) {
                        _showImageDialog(attachment['bytes'], attachment);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      attachments.clear();
                    });
                    Navigator.pop(context);
                    developer.log('Discard button pressed');
                  },
                  child: const Text('Discard'),
                ),
                ElevatedButton(
                  onPressed: () {
                    List<Map<String, String>> attachmentsString = attachments
                        .map((attachment) => attachment.map(
                              (key, value) => MapEntry(key, value.toString()),
                            ))
                        .toList();

                    for (var attachment in attachmentsString) {
                      if (attachment['name'] == null ||
                          attachment['name']!.isEmpty) {
                        developer
                            .log('Error: attachment name is null or empty');
                        return;
                      }

                      if (attachment['bytes'] == null) {
                        developer.log('Error: attachment bytes are null');
                        return;
                      }

                      if (attachment['size'] == null ||
                          attachment['size']!.isEmpty ||
                          int.parse(attachment['size']!) <= 0) {
                        developer
                            .log('Error: attachment size is null or invalid');
                        return;
                      }
                    }
                    for (var attachment in attachments) {
                      _uploadFile(PlatformFile(
                        name: attachment['name'],
                        size: attachment['size'],
                        bytes: attachment['bytes'],
                      ));
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserSendAttachment(
                          transaction: widget.transaction,
                          selectedDetails: [],
                          attachments: attachmentsString,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 79, 129, 189),
                  ),
                  child: const Text('Attach File'),
                ),
              ],
            ),
          ),
          if (_isLoading) // Show loading indicator when uploading
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}