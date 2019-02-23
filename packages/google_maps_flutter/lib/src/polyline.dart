// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of google_maps_flutter;

class Polyline {
  @visibleForTesting
  Polyline(this._id, this._options);

  /// A unique identifier for this polyline.
  ///
  /// The identirifer is an arbitrary unique string.
  final String _id;

  String get id => _id;

  PolylineOptions _options;

  /// The polyline configuration options most recently applied programmatically
  /// via the map controller.
  ///
  /// The returned value does not reflect any changes made to the polyline through
  /// touch events. Add listeners to the owning map controller to track those.
  PolylineOptions get options => _options;
}

dynamic _pointsToJson(List<LatLng> points) {
  if (points == null) {
    return null;
  }
  return points.map((o) => o.toJson());
}

/// Configuration options for [Polyline] instances.
///
/// When used to change configuration, null values will be interpreted as
/// "do not change this configuration option".
class PolylineOptions {
  /// Creates a set of polyline configuration options.
  ///
  /// By default, every non-specified field is null, meaning no desire to change
  /// polyline defaults or current configuration.
  const PolylineOptions({
    this.width,
    this.color,
    this.geodesic,
    this.clickable,
    this.points,
    this.visible,
    this.zIndex,
  });

  final List<LatLng> points;

  final double width;

  final int color;

  /// True if the polyline is visible.
  final bool visible;

  /// The z-index of the polyline, used to determine relative drawing order of
  /// map overlays.
  ///
  /// Overlays are drawn in order of z-index, so that lower values means drawn
  /// earlier, and thus appearing to be closer to the surface of the Earth.
  final double zIndex;

  final bool geodesic;

  final bool clickable;

  /// Default polyline options.
  static const PolylineOptions defaultOptions = PolylineOptions(
      points: [LatLng(0.0, 0.0)],
      width: 0.0,
      color: 0,
      visible: true,
      zIndex: 0.0,
      geodesic: false,
      clickable: false);

  /// Creates a new options object whose values are the same as this instance,
  /// unless overwritten by the specified [changes].
  ///
  /// Returns this instance, if [changes] is null.
  PolylineOptions copyWith(PolylineOptions changes) {
    if (changes == null) {
      return this;
    }
    return PolylineOptions(
        points: changes.points ?? points,
        width: changes.width ?? width,
        color: changes.color ?? color,
        visible: changes.visible ?? visible,
        zIndex: changes.zIndex ?? zIndex,
        geodesic: changes.geodesic ?? geodesic,
        clickable: changes.clickable ?? clickable);
  }

  dynamic _toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent("points", _pointsToJson(points));
    addIfPresent('width', width);
    addIfPresent('color', color);
    addIfPresent('visible', visible);
    addIfPresent('zIndex', zIndex);
    addIfPresent('geodesic', geodesic);
    addIfPresent('clickable', clickable);
    return json;
  }
}
