import 'package:flutter/material.dart';
import 'package:photo_sync/services/api_service.dart';

class InfoPanel extends StatelessWidget {
  final ImmichAsset asset;
  final VoidCallback close;
  const InfoPanel({super.key, required this.asset, required this.close});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromRGBO(19, 19, 20, 1),
      padding: const EdgeInsets.all(8),
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              IconButton(
                onPressed: close,
                mouseCursor: SystemMouseCursors.click, 
                icon: Icon(Icons.close)
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Info',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}