//
//  MapPlugIn.h
//  MapElement
//
//  Created by Terrence Talbot on 2/12/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Sandvox.h>


// uses gMap <http://www.smashinglabs.pl/gmap-intro>

@interface MapPlugIn : SVPlugIn
{
    NSArray *_locations;
    NSUInteger _mapType;
    NSUInteger _zoom;
    BOOL _showMapTypeControl;
    BOOL _showZoomControl;
    BOOL _showPanControl;
    BOOL _showScaleControl;
    BOOL _showStreetViewControl;
}

// array of dictionaries, keys are location, title, details 
@property (nonatomic, retain) NSArray *locations;

// options
@property (nonatomic) NSUInteger mapType;
@property (nonatomic) NSUInteger zoom;
@property (nonatomic) BOOL showMapTypeControl;
@property (nonatomic) BOOL showZoomControl;
@property (nonatomic) BOOL showPanControl;
@property (nonatomic) BOOL showScaleControl;
@property (nonatomic) BOOL showStreetViewControl;

// starting point
@property (nonatomic, readonly) NSMutableDictionary *defaultLocation;

@end
