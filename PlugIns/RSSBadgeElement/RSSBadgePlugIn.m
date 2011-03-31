//
//  RSSBadgePlugIn.m
//  RSSBadgeElement
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
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "RSSBadgePlugIn.h"


@implementation RSSBadgePlugIn


#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [[NSArray arrayWithObjects:
            @"iconPosition", 
            @"iconStyle", 
            @"label", 
            nil] arrayByAddingObjectsFromArray:[super plugInKeys]];
}


#pragma mark Initialization

- (void)awakeFromNew
{
    [super awakeFromNew];
    self.iconPosition = 1;
    self.iconStyle = 1;
    self.showsTitle = NO;
    self.enableMaxItems = YES;
    self.maxItems = 10;
}

- (void)pageDidChange:(id <SVPage>)page;
{
    id <SVPage> oldPage = [self indexedCollection];
    
    [super pageDidChange:page];
    
    if ( !self.label )
    {
        // Use an appropriately localized label
        //
        // Make the string we want get generated, but we are forcing the string to be in target language.
        //
        NSBundle *theBundle = [NSBundle bundleForClass:[self class]];
        NSString *language = [page language];   NSParameterAssert(language);
        NSString *theString = [theBundle localizedStringForString:@"Subscribe to RSS feed" 
                                                         language:language
                                                         fallback:SVLocalizedString(@"Subscribe to RSS feed", @"Prompt to subscribe to the given collection via RSS")];
        self.label = theString;
    }
    
    // Default behaviour is to hook the index up to the collection it was inserted into. If collection doesn't support RSS, undo that
    if (!oldPage && ![self.indexedCollection hasFeed])
    {
        self.indexedCollection = nil;
    }
}

- (void)dealloc
{
    self.label = nil;
    [super dealloc];
}

#pragma mark Migration

- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
    [super awakeFromSourceProperties:properties];
    if ( [properties objectForKey:@"label"] )
    {
        self.label = [properties objectForKey:@"label"];
    }
    if ( [properties objectForKey:@"iconPosition"] )
    {
        self.iconPosition = [[properties objectForKey:@"iconPosition"] intValue];
    }
    if ( [properties objectForKey:@"iconStyle"] )
    {
        self.iconStyle = [[properties objectForKey:@"iconStyle"] intValue];
    }
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"iconStyle" ofObject:self];
    [context addDependencyForKeyPath:@"iconPosition" ofObject:self];
    [context addDependencyForKeyPath:@"label" ofObject:self];
    [context addDependencyForKeyPath:@"hasFeed" ofObject:self.indexedCollection];
    
    // add resources
    NSString *path = [self feedIconResourcePath];
	if (path && ![path isEqualToString:@""]) 
    {
        NSURL *feedIconURL = [NSURL fileURLWithPath:path];
        [context addResourceAtURL:feedIconURL destination:SVDestinationResourcesDirectory options:0];
    }
    
    path = [[NSBundle bundleForClass:[self class]] pathForResource:@"rssbadge" ofType:@"css"];
    if (path && ![path isEqualToString:@""]) 
    {
        NSURL *cssURL = [NSURL fileURLWithPath:path];
        [context addResourceAtURL:cssURL destination:SVDestinationMainCSS options:0];
    } 

    // write HTML
    if ( self.indexedCollection )
    {
        [context startElement:@"div" attributes:[NSDictionary dictionaryWithObject:@"rssBadge" forKey:@"class"]];
        if ( [self useLargeIconLayout] )
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObject:@"largeRSSBadgeIcon" forKey:@"class"];
            [context startElement:@"div" attributes:attrs];
            
            if ( self.iconStyle != 0 )
            {
                NSDictionary *aAttrs = [NSDictionary dictionaryWithObject:@"imageLink" forKey:@"class"];
                if ( [context startAnchorElementWithPageRSSFeed:self.indexedCollection attributes:aAttrs] )
                {
                    NSDictionary *imgAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                              @"largeRSSBadgeIcon", @"class",
                                              [self feedIconResourcePath], @"src",
                                              @"RSS", @"alt",
                                              nil];
                    [context startElement:@"img" attributes:imgAttrs];
                    [context endElement]; // </img>
                    [context endElement]; // </a>
                }
            }
            else
            {
                [context startElement:@"p" attributes:attrs];
                if ( [context startAnchorElementWithPageRSSFeed:self.indexedCollection attributes:nil] )
                {
                    [context writeCharacters:self.label];
                    [context endElement]; // </a>
                }
                [context endElement]; // </p>                
            }
            
            [context endElement]; // </div>
        }
        else
        {
            [context startElement:@"p"];
            
            if ( self.iconStyle != 0 )
            {
                NSDictionary *aAttrs = [NSDictionary dictionaryWithObject:@"imageLink" forKey:@"class"];
                if ( [context startAnchorElementWithPageRSSFeed:self.indexedCollection attributes:aAttrs] )
                {
                    NSString *imgClass = nil;
                    if ( RSSBadgeIconPositionLeft == self.iconPosition )
                    {
                        imgClass = @"smallRSSBadgeIcon smallRSSBadgeIconLeft";
                    }
                    else
                    {
                        imgClass = @"smallRSSBadgeIcon smallRSSBadgeIconRight";
                    }
                    
                    NSDictionary *imgAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                              imgClass, @"class",
                                              [self feedIconResourcePath], @"src",
                                              @"RSS", @"alt",
                                              nil];
                    [context startElement:@"img" attributes:imgAttrs];
                    [context endElement]; // </img>
                    [context endElement]; // </a>                    
                }

            }
            else
            {
                if ( [context startAnchorElementWithPageRSSFeed:self.indexedCollection attributes:nil] )
                {
                    [context writeCharacters:self.label];
                    [context endElement]; // </a>
                }
            }

            [context endElement]; // </p>
        }
        [context endElement]; // <div>
    }
    else
    {
        NSString *text = SVLocalizedString(@"Choose collection in the Inspector", "RSSBadge");
        [context writePlaceholderWithText:text options:0];
    }
}

- (void)writePlaceholderHTML:(id <SVPlugInContext>)context
{
    ; // we'll write our own placeholder text in -writeHTML:
}

- (BOOL)useLargeIconLayout
{
	// Use the large icon layout if the large orange or grey feed icon has been chosen
	RSSBadgeIconStyle iconStyle = self.iconStyle;
	BOOL result = (iconStyle == RSSBadgeIconStyleStandardOrangeLarge 
                   || iconStyle == RSSBadgeIconStyleStandardGrayLarge);
	return result;
}


#pragma mark Resources

- (NSString *)feedIconResourcePath
{
	// The path to the RSS feed icon
	NSString *iconName = nil;
	
	switch ( self.iconStyle )
	{
		case RSSBadgeIconStyleStandardOrangeSmall:
			iconName = @"orange_small.png";
			break;
		case RSSBadgeIconStyleStandardOrangeLarge:
			iconName = @"orange_large.png";
			break;
		case RSSBadgeIconStyleStandardGraySmall:
			iconName = @"gray_small.png";
			break;
		case RSSBadgeIconStyleStandardGrayLarge:
			iconName = @"gray_large.png";
			break;
		case RSSBadgeIconStyleAppleRSS:
			iconName = @"rss_blue.png";
			break;
		case RSSBadgeIconStyleFlatXML:
			iconName = @"xml.gif";
			break;
		case RSSBadgeIconStyleFlatRSS:
			iconName = @"rss.gif";
			break;
        case RSSBadgeIconStyleNone:
        default:
            break;
	}
	
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:iconName];
	return path;
}


#pragma mark Properties

@synthesize iconStyle = _iconStyle;
@synthesize iconPosition = _iconPosition;
@synthesize label = _label;

@end
