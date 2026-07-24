import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double s = 8.0;
  static const double md = 12.0;
  static const double card = 16.0;
  static const double largeCard = 20.0;
  static const double button = 12.0;

  static BorderRadius get sRadius => BorderRadius.circular(s);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get largeCardRadius => BorderRadius.circular(largeCard);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
}
