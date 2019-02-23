// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Polyline;
import com.google.android.gms.maps.model.PolylineOptions;

import java.util.List;

class PolylineBuilder implements PolylineOptionsSink {
  private final GoogleMapController mapController;
  private final PolylineOptions polylineOptions;

  PolylineBuilder(GoogleMapController mapController) {
    this.mapController = mapController;
    this.polylineOptions = new PolylineOptions();
  }

  String build() {
    final Polyline polyline = mapController.addPolyline(polylineOptions);
    return polyline.getId();
  }

  @Override
  public void setVisible(boolean visible) {
    polylineOptions.visible(visible);
  }

  @Override
  public void setGeodesic(boolean geodesic) {
    polylineOptions.geodesic(geodesic);
  }

  @Override
  public void setClickable(boolean clickable) {
    polylineOptions.clickable(clickable);
  }

  @Override
  public void setPoints(List<LatLng> points) {
    polylineOptions.addAll(points);
  }

  @Override
  public void setWidth(float width) {
    polylineOptions.width(width);
  }

  @Override
  public void setColor(int color) {
    polylineOptions.color(color);
  }

  @Override
  public void setZIndex(float zIndex) {
    polylineOptions.zIndex(zIndex);
  }
}
