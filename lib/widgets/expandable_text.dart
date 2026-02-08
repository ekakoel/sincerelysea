import 'package:flutter/material.dart';
import 'package:sincerelysea/widgets/hashtag_text.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLength;

  const ExpandableText({
    super.key,
    required this.text,
    this.trimLength = 150,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLongText = widget.text.length > widget.trimLength;

    final String displayedText =
        isLongText && !_isExpanded
            ? widget.text.substring(0, widget.trimLength)
            : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HashtagText(
          text: displayedText,
        ),
        if (isLongText)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? 'read less' : 'read more...',
                style: const TextStyle(
                  color: Color.fromARGB(255, 150, 150, 150),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
