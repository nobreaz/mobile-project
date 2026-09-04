import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double dividerY;
  final String assetPath;
  final double width;
  final double height;

  const AppLogo({
    super.key,
    required this.dividerY,
    this.assetPath = 'assets/images/logo.png',
    this.width = 178.65,
    this.height = 119.10,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: dividerY - (height / 2),
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: ShapeDecoration(
            image: DecorationImage(image: AssetImage(assetPath), fit: BoxFit.fill),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
        ),
      ),
    );
  }
}