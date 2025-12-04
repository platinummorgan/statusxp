import 'package:flutter/material.dart';

/// Abstract base class for Display Case themes
/// 
/// Supports multiple platform aesthetics: PlayStation, Xbox, Steam
/// Each theme defines colors, textures, and visual styling
abstract class DisplayCaseTheme {
  /// Theme identifier
  String get id;
  
  /// Display name for settings
  String get name;
  
  /// Primary background color
  Color get backgroundColor;
  
  /// Shelf glass color
  Color get shelfColor;
  
  /// Shelf accent/border color
  Color get shelfAccentColor;
  
  /// Primary accent color for highlights
  Color get primaryAccent;
  
  /// Secondary accent color
  Color get secondaryAccent;
  
  /// Text color for labels
  Color get textColor;
  
  /// Background gradient (optional)
  LinearGradient? get backgroundGradient;
  
  /// Shelf shadow color
  Color get shelfShadowColor;
  
  /// Grid slot highlight color when dragging
  Color get slotHighlightColor;
  
  /// Trophy icon border color by tier
  Color getTierColor(String tier);
  
  /// Background decoration for the entire display case
  BoxDecoration getBackgroundDecoration();
  
  /// Glass shelf decoration
  BoxDecoration getShelfDecoration();
  
  /// Neon glow effect for text
  List<Shadow> textGlow({Color? color, double blurRadius = 6});
}
