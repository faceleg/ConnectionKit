//
//  SVPageletPlugIn.m
//  SVPageletPlugIn
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
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

#import "IMStatusPlugIn.h"
#import "IMStatusService.h"

#import "ABPerson+IMStatus.h"
#import <AddressBook/AddressBook.h>


NSString *IMServiceKey = @"service";
NSString *IMHTMLKey = @"html"; 
NSString *IMOnlineImageKey = @"online";
NSString *IMOfflineImageKey = @"offline";
NSString *IMWantBorderKey = @"wantBorder";


@interface IMStatusPlugIn (Private)
- (NSString *)onlineImagePath;
- (NSString *)offlineImagePath;
- (NSImage *)imageWithBaseImage:(NSImage *)aBaseImage 
                       headline:(NSString *)aHeadline 
                         status:(NSString *)aStatus;
@end


@implementation IMStatusPlugIn

- (void)dealloc
{
    self.username = nil;
    self.headlineText = nil;
    self.offlineText = nil;
    self.onlineText = nil;
	[super dealloc];
}

- (void)awakeFromNew;
{
    [super awakeFromNew];

    self.headlineText = LocalizedStringInThisBundle(@"Chat with me", @"Short headline for badge inviting website viewer to iChat/Skype chat with the owner of the website");
    self.offlineText = LocalizedStringInThisBundle(@"offline", @"status indicator of chat; offline or unavailable");
    self.onlineText = LocalizedStringInThisBundle(@"online", @"status indicator of chat; online or available");
    
    // Try to set the username and service from the user's address book
    ABPerson *card = [[ABAddressBook sharedAddressBook] me];
    
    NSUInteger serviceIndex = IMServiceSkype;
    NSString *serviceUsername = [card firstAIMUsername];
    if ( serviceUsername ) 
    {
        serviceIndex = IMServiceIChat;
    }
    else
    {
        serviceUsername = [card firstYahooUsername];
        if ( serviceUsername ) 
        {
            serviceIndex = IMServiceYahoo;
        }
    }
    
    self.selectedServiceIndex = serviceIndex;
    self.username = serviceUsername;
}


#pragma mark -
#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"username", 
            @"selectedServiceIndex",
            @"headlineText",
            @"offlineText",
            @"onlineText",
            nil];
}


#pragma mark -
#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    NSDictionary *divAttrs = [NSDictionary dictionaryWithObject:@"" forKey:@"style"];
    [[context HTMLWriter] startElement:@"div" attributes:divAttrs];
    
    [context addDependencyForKeyPath:@"username" ofObject:self];

    if ( self.username )
    {
        // add our dependent keys
        [context addDependencyForKeyPath:@"selectedServiceIndex" ofObject:self];
        
        //if ( self.selectedServiceIsIChat )
        //{
            [context addDependencyForKeyPath:@"headlineText" ofObject:self];
            [context addDependencyForKeyPath:@"offlineText" ofObject:self];
            [context addDependencyForKeyPath:@"onlineText" ofObject:self];
       // }
        
        // Get the appropriate code for the publishing mode
        IMStatusService *service = [self selectedService];
        
        NSString *serviceHTMLCode = nil;
        if ( [context isForPublishing] ) 
        {
            serviceHTMLCode = [service publishingHTMLCode];
        }
        else if ( [context liveDataFeeds] ) 
        {
            serviceHTMLCode = [service livePreviewHTMLCode];
        }
        else 
        {
            serviceHTMLCode = [service nonLivePreviewHTMLCode];
        }
        
        // Parse the code to get the finished HTML

        NSMutableString *writeableHTMLCode = [NSMutableString stringWithString:serviceHTMLCode];
        
        [writeableHTMLCode replaceOccurrencesOfString:@"#USER#" 
                                           withString:[self.username stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]
                                              options:NSLiteralSearch 
                                                range:NSMakeRange(0, [writeableHTMLCode length])];
        
        NSString *onlineImagePath = [self onlineImagePath];
        if ( onlineImagePath )
        {
            // add resource to context
            NSURL *onlineImageURL = [NSURL fileURLWithPath:onlineImagePath];
            NSURL *contextURL = [context addResourceWithURL:onlineImageURL];
            
            // generate relative string
            onlineImagePath = [context relativeURLStringOfURL:contextURL];    

            // fix up HTML
            [writeableHTMLCode replaceOccurrencesOfString:@"#ONLINE#" 
                                               withString:[onlineImagePath stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]
                                                  options:NSLiteralSearch 
                                                    range:NSMakeRange(0,[writeableHTMLCode length])];
        }
        
        NSString *offlineImagePath = [self offlineImagePath];
        if ( offlineImagePath )
        {
            // add resource to context
            NSURL *offlineImageURL = [NSURL fileURLWithPath:offlineImagePath];
            NSURL *contextURL = [context addResourceWithURL:offlineImageURL];
            
            // generate relative string
            onlineImagePath = [context relativeURLStringOfURL:contextURL];    
            
            // fix up HTML
            [writeableHTMLCode replaceOccurrencesOfString:@"#OFFLINE#" 
                                               withString:[offlineImagePath stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES] 
                                                  options:NSLiteralSearch 
                                                    range:NSMakeRange(0,[writeableHTMLCode length])];
        }
        
        if ( self.headlineText )
        {
            [writeableHTMLCode replaceOccurrencesOfString:@"#HEADLINE#" 
                                               withString:[self.headlineText stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES] 
                                                  options:NSLiteralSearch 
                                                    range:NSMakeRange(0, [writeableHTMLCode length])];
        }
        
        [[context HTMLWriter] writeHTMLString:writeableHTMLCode];
    }
    else
    {
        NSString *noIDMessage = LocalizedStringInThisBundle(@"(Please set your ID using the object inspector)", @"");
        [[context HTMLWriter] writeText:noIDMessage];
    }

    [[context HTMLWriter] endElement]; // </div>
}


#pragma mark -
#pragma mark Badge Image Generation

+ (NSImage *)baseOnlineIChatImage
{
	static NSImage *sOnlineBaseImage;
	
	if (!sOnlineBaseImage)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"online"];
		sOnlineBaseImage = [[NSImage alloc] initWithContentsOfFile:path];
		[sOnlineBaseImage normalizeSize];
	}
	
	return sOnlineBaseImage;
}

+ (NSImage *)baseOfflineIChatImage
{
	static NSImage *sOfflineBaseImage;
	
	if (!sOfflineBaseImage)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"offline"];
		sOfflineBaseImage = [[NSImage alloc] initWithContentsOfFile:path];
		[sOfflineBaseImage normalizeSize];
	}
	
	return sOfflineBaseImage;
}

- (NSString *)onlineImagePath
{
	IMStatusService *service = [self selectedService];
	NSString *result = [service onlineImagePath];
	
	// We have to make a special exception for the ichat service
	if ([[service serviceIdentifier] isEqualToString:@"aim"])
	{
		NSImage *compositedImage = [self imageWithBaseImage:[[self class] baseOnlineIChatImage]
												   headline:self.headlineText
													 status:self.onlineText];
		
		NSData *pngRepresentation = [[compositedImage bitmap] representationUsingType:NSPNGFileType
                                                                           properties:[NSDictionary dictionary]];
		result = [NSTemporaryDirectory() stringByAppendingPathComponent:@"online.png"];
		[pngRepresentation writeToFile:result atomically:NO];
	}
	
	return result;
}

- (NSString *)offlineImagePath
{
	IMStatusService *service = [self selectedService];
	NSString *result = [service offlineImagePath];
	
	// We have to make a special exception for the ichat service
	if ([[service serviceIdentifier] isEqualToString:@"aim"])
	{
		NSImage *compositedImage = [self imageWithBaseImage:[[self class] baseOfflineIChatImage]
												   headline:self.headlineText
													 status:self.offlineText];
		
		NSData *pngRepresentation = [[compositedImage bitmap] representationUsingType:NSPNGFileType
                                                                           properties:[NSDictionary dictionary]];
		
        result = [NSTemporaryDirectory() stringByAppendingPathComponent:@"offline.png"];
		[pngRepresentation writeToFile:result atomically:NO];
	}
	
	return result;
}

- (NSImage *)imageWithBaseImage:(NSImage *)aBaseImage headline:(NSString *)aHeadline status:(NSString *)aStatus
{
	NSFont* font1 = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
	NSFont* font2 = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
	NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
	[aShadow setShadowOffset:NSMakeSize(0.5, -2.0)];
	[aShadow setShadowBlurRadius:2.0];
	[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
	
	NSMutableDictionary *attributes1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		font1, NSFontAttributeName, 
		aShadow, NSShadowAttributeName, 
		[NSColor colorWithCalibratedWhite:1.0 alpha:1.0], NSForegroundColorAttributeName,
		nil];

	NSMutableDictionary *attributes2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		font2, NSFontAttributeName, 
		aShadow, NSShadowAttributeName, 
		[NSColor colorWithCalibratedWhite:1.0 alpha:1.0], NSForegroundColorAttributeName,
		nil];
	
	NSSize textSize1 = [aHeadline sizeWithAttributes:attributes1];
	if (textSize1.width > 100)
	{
		attributes1 = attributes2;	// use the smaller size if it's going to be too large to fit well, but otherwise overflow...
	}

	NSImage *result = [[[NSImage alloc] initWithSize:[aBaseImage size]] autorelease];
	[result lockFocus];
	[aBaseImage drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0,0,[aBaseImage size].width, [aBaseImage size].height) operation:NSCompositeCopy fraction:1.0];
	
	[aHeadline drawAtPoint:NSMakePoint(19,40) withAttributes:attributes1];
	[aStatus drawAtPoint:NSMakePoint(32,12) withAttributes:attributes2];

	[result unlockFocus];
	return result;
}


#pragma mark -
#pragma mark Properties

- (NSArray *)services
{
	return [IMStatusService services];
}

- (IMStatusService *)selectedService
{
	return [[IMStatusService services] objectAtIndex:self.selectedServiceIndex];
}

- (BOOL)selectedServiceIsIChat
{
    return (IMServiceIChat == self.selectedServiceIndex);
}

@synthesize username = _username;
@synthesize selectedServiceIndex = _selectedServiceIndex;
@synthesize headlineText = _headlineText;
@synthesize offlineText = _offlineText;
@synthesize onlineText = _onlineText;

@end
