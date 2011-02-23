//
//  SVPlugIn.m
//  SVPlugIn
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
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "IMStatusPlugIn.h"

#import "IMStatusService.h"
#import "IMStatusImageURLProtocol.h"

#import "ABPerson+IMStatus.h"
#import <AddressBook/AddressBook.h>

#import "NSString+IMStatus.h"


@implementation IMStatusPlugIn

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
    
    self.headlineText = SVLocalizedString(@"Chat with me", @"Short headline for badge inviting website viewer to iChat/Skype chat with the owner of the website");
    self.offlineText = SVLocalizedString(@"offline", @"status indicator of chat; offline or unavailable");
    self.onlineText = SVLocalizedString(@"online", @"status indicator of chat; online or available");
    
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
#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    NSMutableDictionary *divAttrs = [NSMutableDictionary dictionaryWithObject:@"text-align:center; padding:15px 0; margin:0;" 
                                                                       forKey:@"style"];
//    if ( ![context liveDataFeeds] )
//    {
//        [divAttrs setObject:@"svx-placeholder" forKey:@"class"];
//    }
    [context startElement:@"div" attributes:divAttrs];
    
    [context addDependencyForKeyPath:@"username" ofObject:self];
    [context addDependencyForKeyPath:@"selectedServiceIndex" ofObject:self];

    if ( self.username )
    {
        // add our dependent keys
        if ( self.selectedServiceIsIChat )
        {
            [context addDependencyForKeyPath:@"headlineText" ofObject:self];
            [context addDependencyForKeyPath:@"offlineText" ofObject:self];
            [context addDependencyForKeyPath:@"onlineText" ofObject:self];
        }
        
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
                                           withString:[self.username im_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]
                                              options:NSLiteralSearch 
                                                range:NSMakeRange(0, [writeableHTMLCode length])];
        
        NSURL *onlineImageURL = [[service serviceIdentifier] isEqualToString:@"aim"] 
            ? [IMStatusImageURLProtocol URLWithBaseImageURL:[IMStatusImageURLProtocol baseOnlineImageURL] 
                                                   headline:[self headlineText] 
                                                     status:[self onlineText]]
            : [NSURL fileURLWithPath:[service onlineImagePath]];
        if (onlineImageURL)
        {
            // add resource to context
            NSURL *contextURL = [context addResourceWithURL:onlineImageURL];
            
            // generate relative string
            NSString *onlineImagePath = [context relativeStringFromURL:contextURL];    
            onlineImagePath = NSMakeCollectable(CFXMLCreateStringByEscapingEntities(NULL,
                                                                                    (CFStringRef)onlineImagePath,
                                                                                    NULL));
            
            // fix up HTML
            [writeableHTMLCode replaceOccurrencesOfString:@"#ONLINE#" 
                                               withString:onlineImagePath
                                                  options:NSLiteralSearch 
                                                    range:NSMakeRange(0,[writeableHTMLCode length])];
             [onlineImagePath release];
        }
        
        NSURL *offlineImageURL = [[service serviceIdentifier] isEqualToString:@"aim"] 
        ? [IMStatusImageURLProtocol URLWithBaseImageURL:[IMStatusImageURLProtocol baseOfflineImageURL] 
                                               headline:[self headlineText] 
                                                 status:[self offlineText]]
        : [NSURL fileURLWithPath:[service offlineImagePath]];
        
        if ( offlineImageURL )
        {
            // add resource to context
            NSURL *contextURL = [context addResourceWithURL:offlineImageURL];
            
            // generate relative string
            NSString *offlineImagePath = [context relativeStringFromURL:contextURL];    
            offlineImagePath = NSMakeCollectable(CFXMLCreateStringByEscapingEntities(NULL,
                                                                                     (CFStringRef)offlineImagePath,
                                                                                     NULL));
            
            // fix up HTML
            [writeableHTMLCode replaceOccurrencesOfString:@"#OFFLINE#" 
                                               withString:offlineImagePath 
                                                  options:NSLiteralSearch 
                                                    range:NSMakeRange(0,[writeableHTMLCode length])];
            [offlineImagePath release];
        }
        
        if ( self.headlineText )
        {
            [writeableHTMLCode replaceOccurrencesOfString:@"#HEADLINE#" 
                                               withString:[self.headlineText im_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES] 
                                                  options:NSLiteralSearch 
                                                    range:NSMakeRange(0, [writeableHTMLCode length])];
        }
        [context writeHTMLString:writeableHTMLCode];
    }
    else
    {
        NSString *noIDMessage = SVLocalizedString(@"(Please enter your IM username in the Inspector)", @"");
        [context writeCharacters:noIDMessage];
    }

    [context endElement]; // </div>
}

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
