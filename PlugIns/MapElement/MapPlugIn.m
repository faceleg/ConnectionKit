//
//  MapPlugIn.m
//  MapElement
//
//  Created by Terrence Talbot on 2/12/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "MapPlugIn.h"


// <http://www.smashinglabs.pl/gmap-documentation>


@interface MapPlugIn ()
- (NSString *)stringForLocation:(NSDictionary *)location;
@end


@implementation MapPlugIn

#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"locations",
            @"mapType",
            @"zoom",
            @"showMapTypeControl",
            @"showZoomControl",
            @"showPanControl",
            @"showScaleControl",
            @"showStreetViewControl",
            nil];
}


#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // make some initial guesses at params
    self.locations = [NSArray arrayWithObject:self.defaultLocation];
    self.mapType = 0;
    self.zoom = 10;
    
    // defaults from gMap docs
    self.showMapTypeControl = YES;
    self.showZoomControl = YES;
    self.showPanControl = NO;
    self.showScaleControl = NO;
    self.showStreetViewControl = YES;
}

- (NSMutableDictionary *)defaultLocation
{
    // pick a number between 1 and 3
    NSInteger min = 1;
    NSInteger max = 3;
    NSInteger adjustedMax = (max + 1) - min; // arc4random returns within the set {min, (max - 1)}
    NSInteger random = arc4random() % adjustedMax;
    NSInteger location = random + min;
    
    NSMutableDictionary *result = nil;
    switch ( location) 
    {
        case 1:
            result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"Alameda, CA", @"location",
                      @"Karelia Software HQ", @"title",
                      @"Where it all began...", @"details",
                      nil];
            
            break;
        case 2:
            result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"Altadena, CA", @"location",
                      @"Karelia Software SoCal", @"title",
                      @"Where the builds happen...", @"details",
                      nil];
            
            break;
        case 3:
        default:
            result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @"Reading, England", @"location",
                      @"Karelia Software Europe", @"title",
                      @"Code + Band + Pubs = Rock Solid Surfaces", @"details",
                      nil];
            
            break;
    }
    
    return result;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"locations" ofObject:self];
    [context addDependencyForKeyPath:@"mapType" ofObject:self];
    [context addDependencyForKeyPath:@"zoom" ofObject:self];
    [context addDependencyForKeyPath:@"showMapTypeControl" ofObject:self];
    [context addDependencyForKeyPath:@"showZoomControl" ofObject:self];
    [context addDependencyForKeyPath:@"showPanControl" ofObject:self];
    [context addDependencyForKeyPath:@"showScaleControl" ofObject:self];
    [context addDependencyForKeyPath:@"showStreetViewControl" ofObject:self];
    
    // write HTML
    if ( self.locations )
    {
        if ( [context liveDataFeeds] )
        {
            // bind size
            NSString *idName = [context startResizableElement:@"div"
                                                       plugIn:self
                                                      options:0
                                              preferredIdName:@"googlemap"
                                                   attributes:nil];
            [context endElement]; // </div>
            
            
            // append Google Maps API functions to end body
            // sensor=false means "we are not using a GPS device to get this map"
            NSString *script = @"<script type=\"text/javascript\" src=\"http://maps.google.com/maps/api/js?sensor=false\"></script>\n";
            [context addMarkupToEndOfBody:script];
            
            
            // append gMap jquery functions to end body (assumes jquery is already loaded)
            NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"jquery.gmap.min" ofType:@"js"];
            NSURL *URL = [context addResourceAtURL:[NSURL fileURLWithPath:path] destination:SVDestinationResourcesDirectory options:0];
            script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", [context relativeStringFromURL:URL]];
            [context addMarkupToEndOfBody:script];

            
            // prepare parameters, JSON-style
            NSString *panControl = (self.showPanControl) ? @"true" : @"false";
            NSString *scaleControl = (self.showScaleControl) ? @"true" : @"false";
            
            NSString *type = @"google.maps.MapTypeId.ROADMAP";
            switch ( self.mapType )
            {
                case 0:
                    type = @"google.maps.MapTypeId.ROADMAP";
                    break;                    
                case 1:
                    type = @"google.maps.MapTypeId.SATELLITE";
                    break;
                case 2:
                    type = @"google.maps.MapTypeId.HYBRID";
                    break;
                case 3:
                    type = @"google.maps.MapTypeId.TERRAIN";
                    break;
                default:
                    break;
            }
            
            NSMutableString *mapMarkers = [NSMutableString stringWithString:@"["];
            for ( NSDictionary *location in self.locations )
            {
                if ( [location objectForKey:@"location"] )
                {
                    [mapMarkers appendString:[self stringForLocation:location]];
                    [mapMarkers appendString:@","];
                }
            }
            [mapMarkers appendString:@"]"];
            
            
            // append gMap <script> to end body
            NSString *map = [NSString stringWithFormat:
                             @"<script type=\"text/javascript\">\n"
                             @"$(document).ready(function () {\n"
                             @"	$('#%@').gMap({\n"
                             @"	maptype: %@,\n"
                             @"	zoom: %@,\n"
                             @"	panControl: %@,\n"
                             @"	scaleControl: %@,\n"
                             @"	markers: %@\n"
                             @"})\n"
                             @"});\n"
                             @"</script>\n",
                             idName,
                             type,
                             [[NSNumber numberWithUnsignedInt:self.zoom] stringValue],
                             panControl,
                             scaleControl,
                             mapMarkers];
            [context addMarkupToEndOfBody:map];
        }
    }
}

- (NSString *)placeholderString
{
    NSString *result = nil;
    if ( !self.locations )
    {
        result = SVLocalizedString(@"Enter a location in the Inspector", "");
    }
    else if ( ![[self currentContext] liveDataFeeds] )
    {
        result = SVLocalizedString(@"This is a placeholder for a Google Map. It will appear on your published site, or view it in Sandvox by enabling 'Load data from the Internet' in Preferences.", "WebView Placeholder");

    }
    return result;
}

- (NSString *)stringForLocation:(NSDictionary *)location
{
    // return JSON-style dictionary
    return [NSString stringWithFormat:@"{ address: \"%@\", title: \"%@\", html: \"%@\"}",
            [location objectForKey:@"location"],
            [location objectForKey:@"title"],
            [location objectForKey:@"details"]];
}

#pragma mark Metrics

- (NSNumber *)minWidth { return [NSNumber numberWithInt:100]; }
- (NSNumber *)minHeight { return [NSNumber numberWithInt:100]; }

- (void)makeOriginalSize;
{
    // pick an artibrary, yet visible, size to start with
    [self setWidth:[NSNumber numberWithInt:400] height:[NSNumber numberWithInt:400]];
}


#pragma mark Properties

@synthesize locations = _locations;
@synthesize mapType = _mapType;
@synthesize zoom = _zoom;
@synthesize showMapTypeControl = _showMapTypeControl;
@synthesize showZoomControl = _showZoomControl;
@synthesize showScaleControl = _showScaleControl;
@synthesize showPanControl = _showPanControl;
@synthesize showStreetViewControl = _showStreetViewControl;

@end
