// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Polyline;

import java.util.List;

/**
 * Controller of a single Polyline on the map.
 */
class PolylineController implements PolylineOptionsSink {
  private final Polyline polyline;
  private final OnPolylineTappedListener onPolylineClickListener;

  PolylineController(
          Polyline polyline, OnPolylineTappedListener onPolylineTappedListener) {
    this.polyline = polyline;
    this.onPolylineClickListener = onPolylineTappedListener;
  }

  void onTap() {
    if (onPolylineClickListener != null) {
      onPolylineClickListener.onPolylineTapped(polyline);
    }
  }

  void remove() {
    polyline.remove();
  }

  @Override
  public void setVisible(boolean visible) {
    polyline.setVisible(visible);
  }

  @Override
  public void setGeodesic(boolean geodesic) {
    polyline.setGeodesic(geodesic);
  }

  @Override
  public void setClickable(boolean clickable) {
    polyline.setClickable(clickable);
  }

  @Override
  public void setPoints(List<LatLng> points) {
    polyline.setPoints(points);
  }

  @Override
  public void setWidth(float width) {
    polyline.setWidth(width);
  }

  @Override
  public void setColor(int color) {
    polyline.setColor(color);
  }

  @Override
  public void setZIndex(float zIndex) {
    polyline.setZIndex(zIndex);
  }
}
