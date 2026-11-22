import 'package:flutter/foundation.dart';

enum CleanupRisk { review, potentiallyImportant }

@immutable
class CleanupCandidate {
  const CleanupCandidate({
    required this.path,
    required this.category,
    required this.note,
    required this.logicalBytes,
    required this.risk,
    this.projectMarker,
    this.locationSource,
  });

  final String path;
  final String category;
  final String note;
  final int logicalBytes;
  final CleanupRisk risk;
  final String? projectMarker;
  final String? locationSource;
}

/// An in-memory snapshot for review. It cannot perform file operations.
@immutable
class CleanupPlan {
  CleanupPlan({
    required this.scope,
    required this.partial,
    required List<CleanupCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);

  final String scope;
  final bool partial;
  final List<CleanupCandidate> candidates;
}
