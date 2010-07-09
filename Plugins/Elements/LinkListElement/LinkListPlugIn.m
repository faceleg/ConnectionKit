//
//  LinkListPlugIn.m
//  Sandvox SDK
//
//  Copyright 2005-2010 Karelia Software. All rights reserved.
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
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "LinkListPlugIn.h"
#import <SVWebLocation.h>

// LocalizedStringInThisBundle(@"(Add links via Details Inspector)", "String_On_Page_Template")

@implementation LinkListPlugIn

+ (NSMutableDictionary *)displayableLinkFromLocation:(id<SVWebLocation>)location
{
    NSURL *URL = [location URL];
    if ( !URL ) return nil;
    
    // If passed NSNull as a title it means none could be found. We want to use the hostname in such cases
    NSString *title = [location title];
    if (!title) title = [URL host];
        
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [URL absoluteString], @"url",
                                   title, @"title",
                                   nil];
    return result;
}

- (void)dealloc
{
    self.linkList = nil;
	[super dealloc]; 
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    self.linkList = [NSMutableArray arrayWithCapacity:5];
    
    // see if we can start with the frontmost URL in the default browser
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    if ( location )
    {
        NSMutableDictionary *link = [LinkListPlugIn displayableLinkFromLocation:location];
        if ( link ) 
        {
            NSMutableArray *array = [self mutableArrayValueForKey:@"linkList"];
            [array addObject:link];
        }
    }
}


#pragma mark -
#pragma mark SVPlugIn

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:
            @"linkList", 
            @"layout", 
            @"openInNewWindow", nil];
}


#pragma mark -
#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    if ( self.openLinksInNewWindow )
    {
        // target=_blank requires Transitional doc type
        [context limitToMaxDocType:KTXHTMLTransitionalDocType];
    }
    [super writeHTML:context];
}


#pragma mark -
#pragma mark SVPlugInPasteboardReading

// returns an array of UTI strings of data types the receiver can read from the pasteboard and be initialized from. (required)
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

// returns options for reading data of a specified type from a given pasteboard. (required)
+ (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type 
                                               pasteboard:(NSPasteboard *)pasteboard
{
    return SVPlugInPasteboardReadingAsWebLocation;
}

+ (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type
{
    id <SVWebLocation> location = contents;
    if ( [location conformsToProtocol:@protocol(SVWebLocation)] )
    {
        NSURL *URL = [location URL];
        if ( URL )
        {
            return KTSourcePriorityReasonable;
        }
    }
    
	return KTSourcePriorityNone;
}

// returns an object initialized using the data in propertyList. (required since we're not using keyed archiving)
- (void)awakeFromPasteboardContents:(id)propertyList ofType:(NSString *)type
{
    id <SVWebLocation> location = propertyList;
    if ( [location conformsToProtocol:@protocol(SVWebLocation)] )
    {
        NSMutableDictionary *link = [LinkListPlugIn displayableLinkFromLocation:location];
        if ( link ) 
        {
            NSMutableArray *array = [self mutableArrayValueForKey:@"linkList"];
            [array addObject:link];
        }
    }
}


#pragma mark -
#pragma mark Properties

@synthesize linkList = _linkList;
@synthesize layout = _layout;
@synthesize openLinksInNewWindow = _openInNewWindow;
@end
