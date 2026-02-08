import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/post_service.dart';

class PostScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;
  const PostScreen({super.key, this.onPostSuccess});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _captionController = HashtagEditingController();
  File? _imageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  Position? _currentPosition;
  String? _locationName;
  bool _gettingLocation = false;
  
  List<String> _allHashtags = [];
  List<String> _filteredHashtags = [];

  @override
  void initState() {
    super.initState();
    _loadHashtags();
  }

  Future<void> _loadHashtags() async {
    List<String> tags = await PostService().fetchHashtags();
    if (tags.isEmpty) {
      // Fallback to default tags if Firestore is empty
      tags = [
        '#nature', '#sea', '#travel', '#photography', '#beach', 
        '#sunset', '#love', '#instagood', '#photooftheday', '#beautiful'
      ];
    }
    if (mounted) {
      setState(() => _allHashtags = tags);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compress image quality to 70%
      maxWidth: 1080,   // Resize image to a maximum width of 1080px
    );

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _imageFile = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location permissions are permanently denied. Please enable them in settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String? placeName;
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        placeName = "${place.locality}, ${place.country}";
      }

      setState(() {
        _currentPosition = position;
        _locationName = placeName;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  void _onCaptionChanged(String text) {
    final selection = _captionController.selection;
    if (selection.baseOffset < 0) {
      setState(() => _filteredHashtags = []);
      return;
    }

    // Find the start of the word currently being typed
    int start = selection.baseOffset - 1;
    while (start >= 0 && text[start] != ' ' && text[start] != '\n') {
      start--;
    }

    // Extract the word
    String currentWord = text.substring(start + 1, selection.baseOffset);

    if (currentWord.startsWith('#')) {
      String query = currentWord.substring(1).toLowerCase();
      setState(() {
        _filteredHashtags = _allHashtags
            .where((tag) => tag.toLowerCase().contains(query))
            .toList();
      });
    } else {
      setState(() => _filteredHashtags = []);
    }
  }

  void _addHashtag(String tag) {
    final text = _captionController.text;
    final selection = _captionController.selection;

    int start = selection.baseOffset - 1;
    while (start >= 0 && text[start] != ' ' && text[start] != '\n') {
      start--;
    }

    String textBefore = text.substring(0, start + 1);
    String textAfter = text.substring(selection.baseOffset);
    
    String newText = '$textBefore$tag $textAfter';
    
    _captionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: textBefore.length + tag.length + 1),
    );
    
    setState(() => _filteredHashtags = []);
  }

  Future<void> _uploadPost() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a caption')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await PostService().uploadPost(
        uid: user.uid,
        userName: user.displayName ?? 'Anonymous',
        imageFile: _imageFile!,
        caption: _captionController.text.trim(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        locationName: _locationName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post uploaded successfully!')),
        );
        // Reset form
        setState(() {
          _imageFile = null;
          _captionController.clear();
          _currentPosition = null;
          _locationName = null;
          _filteredHashtags = [];
        });
        
        // Pindah ke tab Feed secara otomatis
        widget.onPostSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageFile == null
                    ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: 500,
              onChanged: _onCaptionChanged,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Text(
                  '$currentLength / $maxLength characters',
                  style: TextStyle(color: isFocused ? Colors.blue : Colors.grey, fontSize: 12),
                );
              },
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_filteredHashtags.isNotEmpty)
              Container(
                height: 50,
                margin: const EdgeInsets.only(top: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredHashtags.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(_filteredHashtags[index]),
                        onPressed: () => _addHashtag(_filteredHashtags[index]),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            
            // Location Button
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _gettingLocation ? null : _getLocation,
                  icon: _gettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _locationName != null ? Icons.location_on : Icons.add_location_alt,
                          color: _locationName != null ? Colors.red : Colors.grey,
                        ),
                  label: Text(
                    _locationName ?? 'Add Location',
                    style: TextStyle(
                      color: _locationName != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                if (_locationName != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => setState(() {
                      _locationName = null;
                      _currentPosition = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _uploadPost,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HashtagEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    // Regex to match hashtags (e.g., #nature, #travel)
    final RegExp hashtagPattern = RegExp(r"#[a-zA-Z0-9_]+");

    text.splitMapJoin(
      hashtagPattern,
      onMatch: (Match match) {
        children.add(
          TextSpan(
            text: match[0],
            style: style?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        );
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
