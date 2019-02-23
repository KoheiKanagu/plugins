// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "GoogleMapMarkerController.h"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
static uint64_t _nextPolylineId = 0;
static uint64_t _nextMarkerId = 0;

@implementation FLTGoogleMapMarkerController {
  GMSMarker* _marker;
  GMSMapView* _mapView;
}
- (instancetype)initWithPosition:(CLLocationCoordinate2D)position mapView:(GMSMapView*)mapView {
  self = [super init];
  if (self) {
    _marker = [GMSMarker markerWithPosition:position];
    _mapView = mapView;
    _markerId = [NSString stringWithFormat:@"%lld", _nextMarkerId++];
    _marker.userData = @[ _markerId, @(NO) ];
  }
  return self;
}

#pragma mark - FLTGoogleMapMarkerOptionsSink methods

- (void)setAlpha:(float)alpha {
  _marker.opacity = alpha;
}
- (void)setAnchor:(CGPoint)anchor {
  _marker.groundAnchor = anchor;
}
- (void)setConsumeTapEvents:(BOOL)consumes {
  _marker.userData[1] = @(consumes);
}
- (void)setDraggable:(BOOL)draggable {
  _marker.draggable = draggable;
}
- (void)setFlat:(BOOL)flat {
  _marker.flat = flat;
}
- (void)setIcon:(UIImage*)icon {
  _marker.icon = icon;
}
- (void)setInfoWindowAnchor:(CGPoint)anchor {
  _marker.infoWindowAnchor = anchor;
}
- (void)setInfoWindowTitle:(NSString*)title snippet:(NSString*)snippet {
  _marker.title = title;
  _marker.snippet = snippet;
}
- (void)setPosition:(CLLocationCoordinate2D)position {
  _marker.position = position;
}
- (void)setRotation:(CLLocationDegrees)rotation {
  _marker.rotation = rotation;
}
- (void)setVisible:(BOOL)visible {
  _marker.map = visible ? _mapView : nil;
}
- (void)setZIndex:(int)zIndex {
  _marker.zIndex = zIndex;
}
@end

@implementation FLTGoogleMapPolylineController {
    GMSPolyline* _polyline;
    GMSMapView* _mapView;
}
- (instancetype)initWithPoints:(NSArray *)points mapView:(GMSMapView *)mapView {
    self = [super init];
    if (self) {
        GMSMutablePath *paths = [[GMSMutablePath alloc]init];
        for (CLLocation *v in points) {
            [paths addCoordinate:v.coordinate];
        }
        _polyline = [GMSPolyline polylineWithPath:paths];
        _mapView = mapView;
        _polylineId = [NSString stringWithFormat:@"%lld", _nextPolylineId++];
        _polyline.userData = @[ _polylineId, @(NO) ];
    }
    return self;
}

#pragma mark - FLTGoogleMapPolylineOptionsSink methods

- (void)setPoints:(NSArray *)points {
    GMSMutablePath *paths = [[GMSMutablePath alloc]init];
    for (CLLocation *v in points) {
        [paths addCoordinate:v.coordinate];
    }
    _polyline.path = paths;
}

- (void)setWidth:(float)width {
    _polyline.strokeWidth = width;
}

- (void)setColor:(int)color {
    _polyline.strokeColor = UIColorFromRGB(color);
}

- (void)setZIndex:(int)zIndex {
    _polyline.zIndex = zIndex;
}

- (void)setVisible:(BOOL)visible {
    _polyline.map = visible ? _mapView : nil;
}

- (void)setGeodesic:(BOOL)geodesic {
    _polyline.geodesic = geodesic;
}

- (void)setClickable:(BOOL)clickable {
    _polyline.tappable = clickable;
}

@end

