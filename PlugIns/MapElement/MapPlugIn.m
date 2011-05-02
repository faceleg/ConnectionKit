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


@implementation MapPlugIn

#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"locations",
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
    
    // pick a number between 1 and 3
    NSInteger min = 1;
    NSInteger max = 3;
    NSInteger adjustedMax = (max + 1) - min; // arc4random returns within the set {min, (max - 1)}
    NSInteger random = arc4random() % adjustedMax;
    NSInteger location = random + min;
    
    NSMutableDictionary *defaultLocation = nil;
    switch ( location) 
    {
        case 1:
            defaultLocation = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               @"Alameda, CA", @"location",
                               @"Karelia Software HQ", @"title",
                               @"Where it all began...", @"details",
                               nil];
            
            break;
        case 2:
            defaultLocation = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               @"Altadena, CA", @"location",
                               @"Karelia Software SoCal", @"title",
                               @"Where the builds happen...", @"details",
                               nil];
            
            break;
        case 3:
        default:
            defaultLocation = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               @"Reading, England", @"location",
                               @"Karelia Software Europe", @"title",
                               @"Code + Band + Pubs = Rock Solid Surfaces", @"details",
                               nil];
            
            break;
    }
    self.locations = [NSArray arrayWithObject:defaultLocation];
    
    self.type = 0;
    self.zoom = 10;
    self.clickable = YES;
    self.tooltip = YES;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"locations" ofObject:self];
    [context addDependencyForKeyPath:@"type" ofObject:self];
    [context addDependencyForKeyPath:@"zoom" ofObject:self];
    [context addDependencyForKeyPath:@"clickable" ofObject:self];
    [context addDependencyForKeyPath:@"tooltip" ofObject:self];
    
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

            // append zGoogleMap jquery functions to end body (assumes jquery is already loaded)
            NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"jquery.zgooglemap.min" ofType:@"js"];
            NSURL *URL = [context addResourceAtURL:[NSURL fileURLWithPath:path] destination:SVDestinationResourcesDirectory options:0];
            script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", [context relativeStringFromURL:URL]];
            [context addMarkupToEndOfBody:script];
            
            // prepare parameters
            NSString *pin = (self.clickable) ? @"true" : @"false"; // clicking pin shows details pop-up
            NSString *more = (self.tooltip) ? @"true" : @"false"; // display tooltip of title on pin
                        
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSString *language = [[context page] language];
            NSString *suffix = [bundle localizedStringForString:@"\' (click for details)\'" language:language fallback:SVLocalizedString(@"\' (click for details)\'", @"tooltip suffix")];
            
            
            NSString *theLocations = @"";
            NSString *theTitles = @"";
            NSString *theDetails = @"";
            
            for ( NSDictionary *location in self.locations )
            {
                if ( [location objectForKey:@"location"] )
                {
                    theLocations = [theLocations stringByAppendingFormat:@"\'%@\', ", [location objectForKey:@"location"]];
                }
                else 
                {
                    theLocations = [theLocations stringByAppendingString:@"\'\', "];
                }

                if ( [location objectForKey:@"title"] )
                {
                    theTitles = [theTitles stringByAppendingFormat:@"\'%@\', ", [location objectForKey:@"title"]];
                }
                else 
                {
                    theTitles = [theTitles stringByAppendingString:@"\'\', "];
                }

                if ( [location objectForKey:@"details"] )
                {
                    theDetails = [theDetails stringByAppendingFormat:@"\'%@\', ", [location objectForKey:@"details"]];
                }
                else 
                {
                    theDetails = [theDetails stringByAppendingString:@"\'\', "];
                }
            }
                        
            // append zGoogleMap <script> to end body
            NSString *map = [NSString stringWithFormat:
                             @"<script type=\"text/javascript\">\n"
                             "  var aLocations = new Array();\n"
                             "  var aTitles = new Array();\n"
                             "  var aDetails = new Array();\n"
                             "\n"
                             "  aLocations = [%@];\n"
                             "  aTitles = [%@];\n"
                             "  aDetails = [%@];\n"
                             "\n"
                             @"$(document).ready(function () {\n"
                             @"	$('#%@').GoogleMap(aLocations, aTitles, aDetails, {type:%@, zoom:%@, clickable:%@, tooltip:%@, tipsuffix:%@, width:'%@px', height:'%@px'});\n"
                             @"});\n"
                             @"</script>\n",
                             theLocations,
                             theTitles,
                             theDetails,
                             idName,
                             [[NSNumber numberWithUnsignedInt:self.type] stringValue],
                             [[NSNumber numberWithUnsignedInt:self.zoom] stringValue],
                             pin,
                             more,
                             suffix,
                             [self.width stringValue],
                             [self.height stringValue]];
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
        result = SVLocalizedString(@"Google Map", "placeholder");
    }
    return result;
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
@synthesize type = _type;
@synthesize zoom = _zoom;
@synthesize clickable = _clickable;
@synthesize tooltip = _tooltip;

@end
