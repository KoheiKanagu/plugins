// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "GoogleMapController.h"

#pragma mark - Conversion of JSON-like values sent via platform channels. Forward declarations.

static id positionToJson(GMSCameraPosition* position);
static double toDouble(id json);
static CLLocationCoordinate2D toLocation(id json);
static NSArray* toLocations(id json);
static GMSCameraPosition* toOptionalCameraPosition(id json);
static GMSCoordinateBounds* toOptionalBounds(id json);
static GMSCameraUpdate* toCameraUpdate(id json);
static void interpretMapOptions(id json, id<FLTGoogleMapOptionsSink> sink);
static void interpretMarkerOptions(id json, id<FLTGoogleMapMarkerOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar);
static void interpretPolylineOptions(id json, id<FLTGoogleMapPolylineOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar);

@implementation FLTGoogleMapFactory {
  NSObject<FlutterPluginRegistrar>* _registrar;
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  self = [super init];
  if (self) {
    _registrar = registrar;
  }
  return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  return [[FLTGoogleMapController alloc] initWithFrame:frame
                                        viewIdentifier:viewId
                                             arguments:args
                                             registrar:_registrar];
}
@end

@implementation FLTGoogleMapController {
  GMSMapView* _mapView;
  int64_t _viewId;
  NSMutableDictionary* _markers;
  NSMutableDictionary* _polylines;
  FlutterMethodChannel* _channel;
  BOOL _trackCameraPosition;
  NSObject<FlutterPluginRegistrar>* _registrar;
  // Used for the temporary workaround for a bug that the camera is not properly positioned at
  // initialization. https://github.com/flutter/flutter/issues/24806
  // TODO(cyanglaz): Remove this temporary fix once the Maps SDK issue is resolved.
  // https://github.com/flutter/flutter/issues/27550
  BOOL _cameraDidInitialSetup;
    
    GMSGroundOverlay *overlay;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if ([super init]) {
    _viewId = viewId;

    GMSCameraPosition* camera = toOptionalCameraPosition(args[@"initialCameraPosition"]);
    _mapView = [GMSMapView mapWithFrame:frame camera:camera];
      
    _markers = [NSMutableDictionary dictionaryWithCapacity:1];
    _polylines = [NSMutableDictionary dictionaryWithCapacity:1];
    _trackCameraPosition = NO;
    interpretMapOptions(args[@"options"], self);
    NSString* channelName =
        [NSString stringWithFormat:@"plugins.flutter.io/google_maps_%lld", viewId];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                           binaryMessenger:registrar.messenger];
    __weak __typeof__(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
      if (weakSelf) {
        [weakSelf onMethodCall:call result:result];
      }
    }];
    _mapView.delegate = weakSelf;
    _mapView.indoorDisplay.delegate = self;
    _registrar = registrar;
    _cameraDidInitialSetup = NO;
      
      CLLocationCoordinate2D southWest = CLLocationCoordinate2DMake(34.70173790754115,135.5004928261042);
      CLLocationCoordinate2D northEast = CLLocationCoordinate2DMake(34.702899444157914,135.50268150866032);
      GMSCoordinateBounds *overlayBounds = [[GMSCoordinateBounds alloc] initWithCoordinate:southWest
                                                                                coordinate:northEast];
      UIImage *icon = [UIImage imageNamed:@"new_whity_20191205"];

      overlay =    [GMSGroundOverlay groundOverlayWithBounds:overlayBounds icon:icon];
      overlay.map = nil;
  }
  return self;
}

- (UIView*)view {
  return _mapView;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"map#show"]) {
    [self showAtX:toDouble(call.arguments[@"x"]) Y:toDouble(call.arguments[@"y"])];
    result(nil);
  } else if ([call.method isEqualToString:@"map#hide"]) {
    [self hide];
    result(nil);
  } else if ([call.method isEqualToString:@"camera#animate"]) {
    [self animateWithCameraUpdate:toCameraUpdate(call.arguments[@"cameraUpdate"])];
    result(nil);
  } else if ([call.method isEqualToString:@"camera#move"]) {
    [self moveWithCameraUpdate:toCameraUpdate(call.arguments[@"cameraUpdate"])];
    result(nil);
  } else if ([call.method isEqualToString:@"map#update"]) {
    interpretMapOptions(call.arguments[@"options"], self);
    result(positionToJson([self cameraPosition]));
  } else if ([call.method isEqualToString:@"map#waitForMap"]) {
    result(nil);
  } else if ([call.method isEqualToString:@"marker#add"]) {
    NSDictionary* options = call.arguments[@"options"];
    NSString* markerId = [self addMarkerWithPosition:toLocation(options[@"position"])];
    interpretMarkerOptions(options, [self markerWithId:markerId], _registrar);
    result(markerId);
  } else if ([call.method isEqualToString:@"polyline#add"]) {
      NSDictionary* options = call.arguments[@"options"];
      NSString* polylineId = [self addPolylineWithPoints:toLocations(options[@"points"])];
      interpretPolylineOptions(options, [self polylineWithId:polylineId], _registrar);
      result(polylineId);

//  } else if ([call.method isEqualToString:@"whityMap#add"]) {
//      overlay.map = _mapView;
//      result(@"result");
//
//  } else if ([call.method isEqualToString:@"whityMap#remove"]) {
//        overlay.map = nil;
//      result(@"result");
      
  } else if ([call.method isEqualToString:@"marker#update"]) {
    interpretMarkerOptions(call.arguments[@"options"],
                           [self markerWithId:call.arguments[@"marker"]], _registrar);
    result(nil);
  } else if ([call.method isEqualToString:@"polyline#update"]) {
      interpretPolylineOptions(call.arguments[@"options"],
                             [self polylineWithId:call.arguments[@"polyline"]], _registrar);
      result(nil);

  } else if ([call.method isEqualToString:@"marker#remove"]) {
    [self removeMarkerWithId:call.arguments[@"marker"]];
    result(nil);
  } else if ([call.method isEqualToString:@"polyline#remove"]) {
      [self removePolylineWithId:call.arguments[@"polyline"]];
      result(nil);

  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)showAtX:(CGFloat)x Y:(CGFloat)y {
  _mapView.frame =
      CGRectMake(x, y, CGRectGetWidth(_mapView.frame), CGRectGetHeight(_mapView.frame));
  _mapView.hidden = NO;
}

- (void)hide {
  _mapView.hidden = YES;
}

- (void)animateWithCameraUpdate:(GMSCameraUpdate*)cameraUpdate {
  [_mapView animateWithCameraUpdate:cameraUpdate];
}

- (void)moveWithCameraUpdate:(GMSCameraUpdate*)cameraUpdate {
  [_mapView moveCamera:cameraUpdate];
}

- (GMSCameraPosition*)cameraPosition {
  if (_trackCameraPosition) {
    return _mapView.camera;
  } else {
    return nil;
  }
}

- (NSString*)addMarkerWithPosition:(CLLocationCoordinate2D)position {
  FLTGoogleMapMarkerController* markerController =
      [[FLTGoogleMapMarkerController alloc] initWithPosition:position mapView:_mapView];
  _markers[markerController.markerId] = markerController;
  return markerController.markerId;
}

- (NSString *)addPolylineWithPoints:(NSArray *)points {
    FLTGoogleMapPolylineController* polylineController =
    [[FLTGoogleMapPolylineController alloc] initWithPoints:points mapView:_mapView];

    _polylines[polylineController.polylineId] = polylineController;
    return polylineController.polylineId;
}

- (FLTGoogleMapMarkerController*)markerWithId:(NSString*)markerId {
  return _markers[markerId];
}

- (FLTGoogleMapPolylineController *)polylineWithId:(NSString *)polylineId {
    return _polylines[polylineId];
}

- (void)removeMarkerWithId:(NSString*)markerId {
  FLTGoogleMapMarkerController* markerController = _markers[markerId];
  if (markerController) {
    [markerController setVisible:NO];
    [_markers removeObjectForKey:markerId];
  }
}

- (void)removePolylineWithId:(NSString *)polylineId {
    FLTGoogleMapPolylineController* polylineController = _polylines[polylineId];
    if (polylineController) {
        [polylineController setVisible:NO];
        [_polylines removeObjectForKey:polylineId];
    }
}

#pragma mark - FLTGoogleMapOptionsSink methods

- (void)setCamera:(GMSCameraPosition*)camera {
  _mapView.camera = camera;
}

- (void)setCameraTargetBounds:(GMSCoordinateBounds*)bounds {
  _mapView.cameraTargetBounds = bounds;
}

- (void)setCompassEnabled:(BOOL)enabled {
  _mapView.settings.compassButton = enabled;
}

- (void)setMapType:(GMSMapViewType)mapType {
  _mapView.mapType = mapType;
}

- (void)setMinZoom:(float)minZoom maxZoom:(float)maxZoom {
  [_mapView setMinZoom:minZoom maxZoom:maxZoom];
}

- (void)setRotateGesturesEnabled:(BOOL)enabled {
  _mapView.settings.rotateGestures = enabled;
}

- (void)setScrollGesturesEnabled:(BOOL)enabled {
  _mapView.settings.scrollGestures = enabled;
}

- (void)setTiltGesturesEnabled:(BOOL)enabled {
  _mapView.settings.tiltGestures = enabled;
}

- (void)setTrackCameraPosition:(BOOL)enabled {
  _trackCameraPosition = enabled;
}

- (void)setZoomGesturesEnabled:(BOOL)enabled {
  _mapView.settings.zoomGestures = enabled;
}

- (void)setMyLocationEnabled:(BOOL)enabled {
  _mapView.myLocationEnabled = enabled;
  _mapView.settings.myLocationButton = enabled;
}

#pragma mark - GMSMapViewDelegate methods

- (void)mapView:(GMSMapView*)mapView willMove:(BOOL)gesture {
  [_channel invokeMethod:@"camera#onMoveStarted" arguments:@{@"isGesture" : @(gesture)}];
}

- (void)mapView:(GMSMapView*)mapView didChangeCameraPosition:(GMSCameraPosition*)position {
  if (!_cameraDidInitialSetup) {
    // We suspected a bug in the iOS Google Maps SDK caused the camera is not properly positioned at
    // initialization. https://github.com/flutter/flutter/issues/24806
    // This temporary workaround fix is provided while the actual fix in the Google Maps SDK is
    // still being investigated.
    // TODO(cyanglaz): Remove this temporary fix once the Maps SDK issue is resolved.
    // https://github.com/flutter/flutter/issues/27550
    _cameraDidInitialSetup = YES;
    [mapView moveCamera:[GMSCameraUpdate setCamera:_mapView.camera]];
  }
  if (_trackCameraPosition) {
    [_channel invokeMethod:@"camera#onMove" arguments:@{@"position" : positionToJson(position)}];
  }
}

- (void)mapView:(GMSMapView*)mapView idleAtCameraPosition:(GMSCameraPosition*)position {
  [_channel invokeMethod:@"camera#onIdle" arguments:@{}];
}

- (BOOL)mapView:(GMSMapView*)mapView didTapMarker:(GMSMarker*)marker {
  NSString* markerId = marker.userData[0];
  [_channel invokeMethod:@"marker#onTap" arguments:@{@"marker" : markerId}];
  return [marker.userData[1] boolValue];
}

- (void)mapView:(GMSMapView *)mapView didLongPressAtCoordinate:(CLLocationCoordinate2D)coordinate {
    [_channel invokeMethod:@"map#onMapLongClicked" arguments:@{@"latitude": @(coordinate.latitude), @"longitude": @(coordinate.longitude)}];
}

- (void)mapView:(GMSMapView *)mapView didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
    [_channel invokeMethod:@"map#onMapClicked" arguments:@{@"latitude": @(coordinate.latitude), @"longitude": @(coordinate.longitude)}];
}

- (void)mapView:(GMSMapView*)mapView didTapInfoWindowOfMarker:(GMSMarker*)marker {
  NSString* markerId = marker.userData[0];
  [_channel invokeMethod:@"infoWindow#onTap" arguments:@{@"marker" : markerId}];
}

- (void)didChangeActiveBuilding:(GMSIndoorBuilding *)building {
    [self indoorBuildingActivated:building];
}

- (void)didChangeActiveLevel:(GMSIndoorLevel *)level {
    [self indoorLevelActivated:level];
}

- (void)indoorBuildingActivated:(GMSIndoorBuilding *)indoorBuilding {
    NSDictionary *arg = nil;
    if (indoorBuilding != nil) {
        arg = @{@"underground": @(indoorBuilding.underground),
                @"defaultLevelIndex": @(indoorBuilding.defaultLevelIndex),
                @"levels": [self mappingIndoorLevels:indoorBuilding.levels]};
    }
    [_channel invokeMethod:@"map#onIndoorBuildingActivated" arguments:arg];
}

- (void)indoorLevelActivated:(GMSIndoorLevel *)indoorLevel {
    NSDictionary *arg = nil;
    if (indoorLevel != nil) {
        arg =  [self mappingIndoorLevel:indoorLevel];
        if ([indoorLevel.name  isEqual: @"B1"]) {
            overlay.map = _mapView;
        } else {
            overlay.map = nil;
        }
    } else {
        if (overlay != nil) {
            overlay.map = nil;
        }
    }
    
    [_channel invokeMethod:@"map#onIndoorLevelActivated" arguments:arg];
}

- (NSArray<NSDictionary *> *)mappingIndoorLevels:(NSArray<GMSIndoorLevel *> *)levels {
    if (levels == nil) {
        return nil;
    }
    NSMutableArray* array = [NSMutableArray array];
    for (GMSIndoorLevel *level in levels) {
        [array addObject: [self mappingIndoorLevel:level]];
    }
    return array;
}

- (NSDictionary *)mappingIndoorLevel:(GMSIndoorLevel *)level {
    return @{@"name": [NSString stringWithString:level.name],
             @"shortName": [NSString stringWithString:level.shortName]};
}
@end

#pragma mark - Implementations of JSON conversion functions.

static id locationToJson(CLLocationCoordinate2D position) {
  return @[ @(position.latitude), @(position.longitude) ];
}

static id positionToJson(GMSCameraPosition* position) {
  if (!position) {
    return nil;
  }
  return @{
    @"target" : locationToJson([position target]),
    @"zoom" : @([position zoom]),
    @"bearing" : @([position bearing]),
    @"tilt" : @([position viewingAngle]),
  };
}

static bool toBool(id json) {
  NSNumber* data = json;
  return data.boolValue;
}

static int toInt(id json) {
  NSNumber* data = json;
  return data.intValue;
}

static double toDouble(id json) {
  NSNumber* data = json;
  return data.doubleValue;
}

static float toFloat(id json) {
  NSNumber* data = json;
  return data.floatValue;
}

static CLLocationCoordinate2D toLocation(id json) {
  NSArray* data = json;
  return CLLocationCoordinate2DMake(toDouble(data[0]), toDouble(data[1]));
}

static NSArray* toLocations(id json) {
    NSMutableArray *result = [NSMutableArray array];
    NSArray* data = json;
    for (id v in data) {
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:toDouble(v[0]) longitude:toDouble(v[1])];
        [result addObject:loc];
    }
    return result;
}

static CGPoint toPoint(id json) {
  NSArray* data = json;
  return CGPointMake(toDouble(data[0]), toDouble(data[1]));
}

static GMSCameraPosition* toCameraPosition(id json) {
  NSDictionary* data = json;
  return [GMSCameraPosition cameraWithTarget:toLocation(data[@"target"])
                                        zoom:toFloat(data[@"zoom"])
                                     bearing:toDouble(data[@"bearing"])
                                viewingAngle:toDouble(data[@"tilt"])];
}

static GMSCameraPosition* toOptionalCameraPosition(id json) {
  return json ? toCameraPosition(json) : nil;
}

static GMSCoordinateBounds* toBounds(id json) {
  NSArray* data = json;
  return [[GMSCoordinateBounds alloc] initWithCoordinate:toLocation(data[0])
                                              coordinate:toLocation(data[1])];
}

static GMSCoordinateBounds* toOptionalBounds(id json) {
  NSArray* data = json;
  return (data[0] == [NSNull null]) ? nil : toBounds(data[0]);
}

static GMSMapViewType toMapViewType(id json) {
  int value = toInt(json);
  return (GMSMapViewType)(value == 0 ? 5 : value);
}

static GMSCameraUpdate* toCameraUpdate(id json) {
  NSArray* data = json;
  NSString* update = data[0];
  if ([update isEqualToString:@"newCameraPosition"]) {
    return [GMSCameraUpdate setCamera:toCameraPosition(data[1])];
  } else if ([update isEqualToString:@"newLatLng"]) {
    return [GMSCameraUpdate setTarget:toLocation(data[1])];
  } else if ([update isEqualToString:@"newLatLngBounds"]) {
    return [GMSCameraUpdate fitBounds:toBounds(data[1]) withPadding:toDouble(data[2])];
  } else if ([update isEqualToString:@"newLatLngZoom"]) {
    return [GMSCameraUpdate setTarget:toLocation(data[1]) zoom:toFloat(data[2])];
  } else if ([update isEqualToString:@"scrollBy"]) {
    return [GMSCameraUpdate scrollByX:toDouble(data[1]) Y:toDouble(data[2])];
  } else if ([update isEqualToString:@"zoomBy"]) {
    if (data.count == 2) {
      return [GMSCameraUpdate zoomBy:toFloat(data[1])];
    } else {
      return [GMSCameraUpdate zoomBy:toFloat(data[1]) atPoint:toPoint(data[2])];
    }
  } else if ([update isEqualToString:@"zoomIn"]) {
    return [GMSCameraUpdate zoomIn];
  } else if ([update isEqualToString:@"zoomOut"]) {
    return [GMSCameraUpdate zoomOut];
  } else if ([update isEqualToString:@"zoomTo"]) {
    return [GMSCameraUpdate zoomTo:toFloat(data[1])];
  }
  return nil;
}

static void interpretMapOptions(id json, id<FLTGoogleMapOptionsSink> sink) {
  NSDictionary* data = json;
  id cameraTargetBounds = data[@"cameraTargetBounds"];
  if (cameraTargetBounds) {
    [sink setCameraTargetBounds:toOptionalBounds(cameraTargetBounds)];
  }
  id compassEnabled = data[@"compassEnabled"];
  if (compassEnabled) {
    [sink setCompassEnabled:toBool(compassEnabled)];
  }
  id mapType = data[@"mapType"];
  if (mapType) {
    [sink setMapType:toMapViewType(mapType)];
  }
  id minMaxZoomPreference = data[@"minMaxZoomPreference"];
  if (minMaxZoomPreference) {
    NSArray* zoomData = minMaxZoomPreference;
    float minZoom = (zoomData[0] == [NSNull null]) ? kGMSMinZoomLevel : toFloat(zoomData[0]);
    float maxZoom = (zoomData[1] == [NSNull null]) ? kGMSMaxZoomLevel : toFloat(zoomData[1]);
    [sink setMinZoom:minZoom maxZoom:maxZoom];
  }
  id rotateGesturesEnabled = data[@"rotateGesturesEnabled"];
  if (rotateGesturesEnabled) {
    [sink setRotateGesturesEnabled:toBool(rotateGesturesEnabled)];
  }
  id scrollGesturesEnabled = data[@"scrollGesturesEnabled"];
  if (scrollGesturesEnabled) {
    [sink setScrollGesturesEnabled:toBool(scrollGesturesEnabled)];
  }
  id tiltGesturesEnabled = data[@"tiltGesturesEnabled"];
  if (tiltGesturesEnabled) {
    [sink setTiltGesturesEnabled:toBool(tiltGesturesEnabled)];
  }
  id trackCameraPosition = data[@"trackCameraPosition"];
  if (trackCameraPosition) {
    [sink setTrackCameraPosition:toBool(trackCameraPosition)];
  }
  id zoomGesturesEnabled = data[@"zoomGesturesEnabled"];
  if (zoomGesturesEnabled) {
    [sink setZoomGesturesEnabled:toBool(zoomGesturesEnabled)];
  }
  id myLocationEnabled = data[@"myLocationEnabled"];
  if (myLocationEnabled) {
    [sink setMyLocationEnabled:toBool(myLocationEnabled)];
  }
}

static void interpretMarkerOptions(id json, id<FLTGoogleMapMarkerOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar) {
  NSDictionary* data = json;
  id alpha = data[@"alpha"];
  if (alpha) {
    [sink setAlpha:toFloat(alpha)];
  }
  id anchor = data[@"anchor"];
  if (anchor) {
    [sink setAnchor:toPoint(anchor)];
  }
  id draggable = data[@"draggable"];
  if (draggable) {
    [sink setDraggable:toBool(draggable)];
  }
  id icon = data[@"icon"];
  if (icon) {
    NSArray* iconData = icon;
    UIImage* image;
    if ([iconData[0] isEqualToString:@"defaultMarker"]) {
      CGFloat hue = (iconData.count == 1) ? 0.0f : toDouble(iconData[1]);
      image = [GMSMarker markerImageWithColor:[UIColor colorWithHue:hue / 360.0
                                                         saturation:1.0
                                                         brightness:0.7
                                                              alpha:1.0]];
    } else if ([iconData[0] isEqualToString:@"fromAsset"]) {
      if (iconData.count == 2) {
        image = [UIImage imageNamed:[registrar lookupKeyForAsset:iconData[1]]];
      } else {
        image = [UIImage imageNamed:[registrar lookupKeyForAsset:iconData[1]
                                                     fromPackage:iconData[2]]];
      }
    }
    [sink setIcon:image];
  }
  id flat = data[@"flat"];
  if (flat) {
    [sink setFlat:toBool(flat)];
  }
  id infoWindowAnchor = data[@"infoWindowAnchor"];
  if (infoWindowAnchor) {
    [sink setInfoWindowAnchor:toPoint(infoWindowAnchor)];
  }
  id infoWindowText = data[@"infoWindowText"];
  if (infoWindowText) {
    NSArray* infoWindowTextData = infoWindowText;
    NSString* title = (infoWindowTextData[0] == [NSNull null]) ? nil : infoWindowTextData[0];
    NSString* snippet = (infoWindowTextData[1] == [NSNull null]) ? nil : infoWindowTextData[1];
    [sink setInfoWindowTitle:title snippet:snippet];
  }
  id position = data[@"position"];
  if (position) {
    [sink setPosition:toLocation(position)];
  }
  id rotation = data[@"rotation"];
  if (rotation) {
    [sink setRotation:toDouble(rotation)];
  }
  id visible = data[@"visible"];
  if (visible) {
    [sink setVisible:toBool(visible)];
  }
  id zIndex = data[@"zIndex"];
  if (zIndex) {
    [sink setZIndex:toInt(zIndex)];
  }
}

static void interpretPolylineOptions(id json, id<FLTGoogleMapPolylineOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar) {
    NSDictionary* data = json;
    id points = data[@"points"];
    if (points) {
        [sink setPoints:toLocations(points)];
    }
    id width = data[@"width"];
    if (width) {
        [sink setWidth:toFloat(width)];
    }
    id color = data[@"color"];
    if (color) {
        [sink setColor:toInt(color)];
    }
    id zIndex = data[@"zIndex"];
    if (zIndex) {
        [sink setZIndex:toInt(zIndex)];
    }
    id visible = data[@"visible"];
    if (visible) {
        [sink setVisible:toBool(visible)];
    }
    id geodesic = data[@"geodesic"];
    if (geodesic) {
        [sink setGeodesic:toBool(geodesic)];
    }
    id clickable = data[@"clickable"];
    if (clickable) {
        [sink setClickable:toBool(clickable)];
    }
}

