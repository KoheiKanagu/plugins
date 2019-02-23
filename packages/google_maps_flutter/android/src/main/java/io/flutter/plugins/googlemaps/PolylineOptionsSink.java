// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import com.google.android.gms.maps.model.LatLng;

import java.util.List;

/**
 * Receiver of Polyline configuration options.
 */
interface PolylineOptionsSink {

  void setPoints(List<LatLng> points);

  void setWidth(float width);

  void setColor(int color);

  void setZIndex(float zIndex);

  void setVisible(boolean visible);

  void setGeodesic(boolean geodesic);

  void setClickable(boolean clickable);
}
