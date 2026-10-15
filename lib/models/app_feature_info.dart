import 'package:flutter/material.dart';

enum MockupType {
  homeScreenWidget,
  googleAssistant,
  bankStatement,
  biometricLock,
  voiceLogging,
  familySanctuary,
  upcomingRoadmap,
}

class TutorialStep {
  final int stepNumber;
  final String title;
  final String instruction;
  final String proTip;
  final MockupType mockupType;

  const TutorialStep({
    required this.stepNumber,
    required this.title,
    required this.instruction,
    required this.proTip,
    required this.mockupType,
  });
}

class AppFeature {
  final String id;
  final String title;
  final String shortTagline;
  final IconData icon;
  final String badge;
  final String category;
  final Color accentColor;
  final String userOverview;
  final List<String> keyBenefits;
  final List<TutorialStep> tutorialSteps;
  final String? actionLabel;
  final String? actionRouteId;
  final bool isFuture;

  const AppFeature({
    required this.id,
    required this.title,
    required this.shortTagline,
    required this.icon,
    required this.badge,
    required this.category,
    required this.accentColor,
    required this.userOverview,
    required this.keyBenefits,
    this.tutorialSteps = const [],
    this.actionLabel,
    this.actionRouteId,
    this.isFuture = false,
  });

  bool get hasTutorial => tutorialSteps.isNotEmpty;
}
