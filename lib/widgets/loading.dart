import 'package:flutter/material.dart';
import 'panel_dropdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// 1. The Widget configuration class (Immutable)
class Loading extends StatefulWidget {
  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {

  @override
  Widget build(BuildContext context) {
  return Positioned.fill(
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: const Center(
        child: SpinKitRipple(
          color: Colors.greenAccent,
          size: 60,
        ),
      ),
    ),
  );
}
}