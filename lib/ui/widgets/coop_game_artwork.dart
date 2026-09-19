import 'package:flutter/material.dart';

class CoopGameArtwork extends StatelessWidget {
  const CoopGameArtwork({super.key, this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF394677), Color(0xFF153E4D)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.sports_esports_outlined,
          color: Colors.white60,
          size: 32,
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 80,
          height: 100,
          child: url == null
              ? placeholder
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  cacheWidth: 240,
                  errorBuilder: (_, _, _) => placeholder,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : placeholder,
                ),
        ),
      ),
    );
  }
}
