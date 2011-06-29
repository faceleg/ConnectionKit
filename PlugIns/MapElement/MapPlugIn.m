//
//  MapPlugIn.m
//  MapElement
//
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "MapPlugIn.h"


// <http://www.smashinglabs.pl/gmap-documentation>


@interface MapPlugIn ()
@end


@implementation MapPlugIn


#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"location",
            @"showAddressBubble",
            @"showZoomControl",
            @"showPanControl",
            @"showScaleControl",
            @"showStreetViewControl",
            nil];
}

- (BOOL)requiresPageLoad
{
    return YES;
}


#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // make some initial guesses at params
    self.location = [self defaultLocation];
    self.showAddressBubble = YES;

    // defaults from gMap docs
    self.showZoomControl = YES;
    self.showPanControl = NO;
    self.showScaleControl = NO;
    self.showStreetViewControl = YES;
}

- (NSString *)defaultLocation
{
    
    NSString *result = nil;
    
    // try to find a general location in Me card
    
    // fallback to a Karelia outpost, pick a number between 1 and 3
    NSInteger min = 1;
    NSInteger max = 3;
    NSInteger adjustedMax = (max + 1) - min; // arc4random returns within the set {min, (max - 1)}
    NSInteger random = arc4random() % adjustedMax;
    NSInteger location = random + min;    
    switch ( location) 
    {
        case 1:
            result = @"Alameda, CA";
            break;
        case 2:
            result = @"Altadena, CA";
            break;
        case 3:
        default:
            result = @"Reading, England";
            break;
    }
    
    return result;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"location" ofObject:self];
    [context addDependencyForKeyPath:@"showZoomControl" ofObject:self];
    [context addDependencyForKeyPath:@"showPanControl" ofObject:self];
    [context addDependencyForKeyPath:@"showScaleControl" ofObject:self];
    [context addDependencyForKeyPath:@"showStreetViewControl" ofObject:self];
    
    // write HTML
    if ( self.location )
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
            
            // we always show a ROADMAP
            NSString *type = @"google.maps.MapTypeId.ROADMAP";

            NSString *panControl = (self.showPanControl) ? @"true" : @"false";
            NSString *scaleControl = (self.showScaleControl) ? @"true" : @"false";
            NSString *streetViewControl = (self.showStreetViewControl) ? @"true" : @"false";
            NSString *zoomControl = (self.showZoomControl) ? @"true" : @"false";
            
            NSString *address = self.location;
            
            // append gMap <script> to end body
            NSString *map = [NSString stringWithFormat:
                             @"<script type=\"text/javascript\">\n"
                             @"$(document).ready(function () {\n"
                             @"	$('#%@').gMap({\n"
                             @"	maptype: %@,\n"
                             @"	zoomControl: %@,\n"
                             @"	panControl: %@,\n"
                             @"	scaleControl: %@,\n"
                             @"	streetViewControl: %@,\n"
                             @"	address: \"%@\"\n"
                             @"})\n"
                             @"});\n"
                             @"</script>\n",
                             idName,
                             type,
                             zoomControl,
                             panControl,
                             scaleControl,
                             streetViewControl,
                             address];
            [context addMarkupToEndOfBody:map];
        }
    }
}

- (NSString *)placeholderString
{
    NSString *result = nil;
    if ( !self.location )
    {
        result = SVLocalizedString(@"Enter a location in the Inspector", "");
    }
    else if ( ![[self currentContext] liveDataFeeds] )
    {
        result = SVLocalizedString(@"This is a placeholder for a Google Map. It will appear on your published site, or view it in Sandvox by enabling 'Load data from the Internet' in Preferences.", "WebView Placeholder");

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

@synthesize location = _location;
@synthesize showAddressBubble = _showAddressBubble;
@synthesize showPanControl = _showPanControl;
@synthesize showScaleControl = _showScaleControl;
@synthesize showStreetViewControl = _showStreetViewControl;
@synthesize showZoomControl = _showZoomControl;

@end
