import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final Function(String)? onHashtagTap;

  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.hashtagStyle,
    this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> children = [];
    final RegExp hashtagPattern = RegExp(r"#[a-zA-Z0-9_]+");

    text.splitMapJoin(
      hashtagPattern,
      onMatch: (Match match) {
        final String tag = match[0]!;
        children.add(
          TextSpan(
            text: tag,
            style: hashtagStyle ?? const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onHashtagTap != null) {
                  onHashtagTap!(tag);
                }
              },
          ),
        );
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return RichText(
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: children,
      ),
    );
  }
}