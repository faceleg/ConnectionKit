//
//  MapPlugIn.m
//  MapElement
//
//  Created by Terrence Talbot on 2/12/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "MapPlugIn.h"


// <http://www.zazar.net/developers/zgooglemap/>
// This plugin simplifies the adding Google Maps via the Google Map API (v3) and plots custom locations with pop-up descriptions. Simple and easy to use.

//Parameters
//
//Parameter Required    Description
//locations Yes         Array containing the addresses of the locations to be added.
//titles    Yes         Array containing the titles of the locations. These are used for the tooltip and pop-up heading.
//details   Yes         Array containing the details of the locations for the pop-up. This may be include HTML formatting.
//options   No          Optional settings for the plug-in (see below).
//
//
//Plug-in options
//
//Parameter	Default     Description
//type      0           The type of map: 0 - Road map, 1 - Satellite, 2 - Hybrid or 3 - Terrain.
//width     '600px'     The width of the map in any CSS format. ie px, em, %
//height    '400px'     The height of the map in any CSS format.
//zoom      10          The initial zoom level of the map.
//clickable true        If true, will enable a pop-up by clicking on the location pin.
//tooltip	true        If true, will display a tooltip for each location pin.
//tipsuffix	' (click for more)'     When enabled the tooltip text will be the same as the title. This setting adds a definable suffix.


#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

@implementation MapPlugIn

#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"location",
            @"locationTitle",
            @"type",
            @"zoom",
            @"clickable",
            @"tooltip",
            nil];
}


#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // make some initial guesses at params
    self.location = @"alameda, california";
    self.locationTitle = @"HQ";
    self.type = 2;
    self.zoom = 6;
    self.clickable = NO;
    self.tooltip = NO;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"location" ofObject:self];
    [context addDependencyForKeyPath:@"locationTitle" ofObject:self];
    [context addDependencyForKeyPath:@"type" ofObject:self];
    [context addDependencyForKeyPath:@"zoom" ofObject:self];
    [context addDependencyForKeyPath:@"clickable" ofObject:self];
    [context addDependencyForKeyPath:@"tooltip" ofObject:self];
    
    // write HTML
    if ( self.location )
    {
        if ( [context liveDataFeeds] )
        {
            // bind size
            NSString *idName = [context pushPreferredIdName:@"googlemap"];
            [context startElement:@"div"
                 bindSizeToPlugIn:self
                       attributes:nil];
            
            //FIXME: #107815 -- this writeCharacters: shouldn't be needed
            [context writeCharacters:@"If you see this sentence, hit reload..."];
            [context endElement]; // </div>
            
            // append Google Maps API functions to end body
            // sensor=false means "we are not using a GPS device to get this map"
            NSString *script = @"<script type=\"text/javascript\" src=\"http://maps.google.com/maps/api/js?sensor=false\"></script>\n";
            [context addMarkupToEndOfBody:script];

            // append zGoogleMap jquery functions to end body (assumes jquery is already loaded)
            NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"jquery.zgooglemap.min" ofType:@"js"];
            NSURL *URL = [context addResourceWithURL:[NSURL fileURLWithPath:path]];
            script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", [URL absoluteURL]];
            [context addMarkupToEndOfBody:script];
            
            // append zGoogleMap <script> to end body
            NSString *map = [NSString stringWithFormat:
                             @"<script type=\"text/javascript\">\n"
                             "  var aLocations = new Array();\n"
                             "  var aTitles = new Array();\n"
                             "  var aDetails = new Array();\n"
                             "\n"
                             "  aLocations = ['%@'];\n"
                             "  aTitles = ['%@'];\n"
                             "  aDetails = ['Some details about this address'];\n"
                             "\n"
                             @"$(document).ready(function () {\n"
                             @"	$('#%@').GoogleMap(aLocations, aTitles, aDetails, {type:%@, zoom:%@, width:'%@px', height:'%@px'});\n"
                             @"});\n"
                             @"</script>\n",
                             self.location,
                             self.locationTitle,
                             idName,
                             [[NSNumber numberWithUnsignedInt:self.type] stringValue],
                             [[NSNumber numberWithUnsignedInt:self.zoom] stringValue],
                             [self.width stringValue],
                             [self.height stringValue]];
            [context addMarkupToEndOfBody:map];
        }
        else 
        {
            [context writePlaceholderWithText:LocalizedStringInThisBundle(@"Maps only available when Live Preview is On.", "")];
        }
    }
    else 
    {
        [context writePlaceholderWithText:LocalizedStringInThisBundle(@"Enter a street address in the Inspector.", "")];
    }
}


#pragma mark Metrics

+ (BOOL)isExplicitlySized { return YES; }

- (NSNumber *)minWidth { return [NSNumber numberWithInt:100]; }
- (NSNumber *)minHeight { return [NSNumber numberWithInt:100]; }

- (void)makeOriginalSize;
{
    // pick an artibrary, yet visible, size to start with
    [self setWidth:[NSNumber numberWithInt:430] height:[NSNumber numberWithInt:286]];
}


#pragma mark Properties

@synthesize location = _location;
@synthesize locationTitle = _locationTitle;
@synthesize type = _type;
@synthesize zoom = _zoom;
@synthesize clickable = _clickable;
@synthesize tooltip = _tooltip;

@end
