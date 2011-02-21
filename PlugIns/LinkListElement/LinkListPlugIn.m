//
//  LinkListPlugIn.m
//  Sandvox SDK
//
//  Copyright 2005-2011 Karelia Software. All rights reserved.
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

#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

@implementation LinkListPlugIn

+ (Link *)displayableLinkFromLocation:(id<SVWebLocation>)location
{
    NSURL *URL = [location URL];
    if ( !URL ) return nil;
    if ( [URL isFileURL] ) return nil;
    
    // If passed NSNull as a title it means none could be found. We want to use the hostname in such cases
    NSString *title = [location title];
    if ( !title || (title == (id)[NSNull null]) ) title = [URL host];
        
    Link *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                    URL, @"url",
                    title, @"title",
                    nil];
    return result;
}

- (id)init
{
    self = [super init];
    if ( self )
    {
        self.linkList = [NSArray array];
    }
    return self;
}

- (void)dealloc
{
    self.linkList = nil;
	[super dealloc]; 
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // set initial properties
    self.layout = 0;
    self.openLinksInNewWindow = NO;
    
    // see if we can start with the frontmost URL in the default browser
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    if ( location )
    {
        Link *link = [LinkListPlugIn displayableLinkFromLocation:location];
        if ( link ) [self addLink:link];
    }
}


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"linkList", 
            @"layout", 
            @"openInNewWindow", nil];
}


#pragma mark HTML Generation


- (void)writePlaceholder
{
    id <SVPlugInContext> context = [self currentContext];
    [context writePlaceholderWithText:LocalizedStringInThisBundle(@"Add links via Inspector", "String_On_Page_Template")];
}


#pragma mark Pasteboard

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

+ (SVPasteboardPriority)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( URL )
    {
        if ( [URL isFileURL ] )
        {
            return SVPasteboardPriorityNone;
        }
        else
        {
            return SVPasteboardPriorityReasonable;
        }

    }
    return [super priorityForPasteboardItem:item];
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    BOOL didAwakeAtLeastOneItem = NO;
    
    if ( items && [items count] )
    {        
        for ( id <SVPasteboardItem>item in items )
        {
            Link *link = [LinkListPlugIn displayableLinkFromLocation:(id <SVWebLocation>)item];  //lie for now
            if ( link ) 
            {
                [self addLink:link];
                didAwakeAtLeastOneItem = YES;
            }

        }
    }
    
    return didAwakeAtLeastOneItem;    
}

- (void)addLink:(Link *)link
{
    NSMutableArray *links = [NSMutableArray arrayWithArray:self.linkList];
    [links addObject:link];
    self.linkList = [NSArray arrayWithArray:links];
}

+ (BOOL)supportsMultiplePasteboardItems; { return YES; }


#pragma mark Migration

- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
    if ( [properties objectForKey:@"layout"] )
    {
        self.layout = [[properties objectForKey:@"layout"] integerValue];
    }
    if ( [properties objectForKey:@"openInNewWindow"] )
    {
        self.openLinksInNewWindow = [[properties objectForKey:@"openInNewWindow"] boolValue];
    }
    if ( [properties objectForKey:@"linkList"] )
    {
        for ( NSDictionary *oldLink in [properties objectForKey:@"linkList"] )
        {
            NSString *title = [oldLink objectForKey:@"titleHTML"];
            NSURL *url = [NSURL URLWithString:[oldLink objectForKey:@"url"]];
            Link *newLink = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             title, @"title",
                             url, @"url",
                             nil];
            [self addLink:newLink];
        }
        
    }
}

#pragma mark Properties

@synthesize linkList = _linkList;
@synthesize layout = _layout;
@synthesize openLinksInNewWindow = _openInNewWindow;
@end
