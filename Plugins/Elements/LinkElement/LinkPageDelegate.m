//
//  LinkPageDelegate.m
//  Sandvox SDK
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

//	LocalizedStringInThisBundle(@"“Live” page loading is disabled from the preferences", "placeholder message")
//	LocalizedStringInThisBundle(@"No URL specified", "placeholder message")
//	LocalizedStringInThisBundle(@"Use the Inspector to set the URL and title of this page.", "placeholder message")


#import "LinkPageDelegate.h"

#import "SandvoxPlugin.h"
//#import <ThirdParty.h>


@implementation LinkPageDelegate

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	// Register our custom value transformer
	NSValueTransformer *transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:kIframeLink]];
	[NSValueTransformer setValueTransformer:transformer forName:@"ExternalPageLinkTypeIsPageWithinPage"];
	[transformer release];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if ( isNewObject )
	{
		// Attempt to automatically grab the URL from the user's browser
		NSURL *theURL = nil;
		NSString *theTitle = nil;
		[NSAppleScript getWebBrowserURL:&theURL title:&theTitle source:nil];
		
		if (nil != theURL)
		{
			[[self delegateOwner] setObject:[theURL absoluteString] forKey:@"linkURL"];
		}
		if (nil != theTitle)
		{
			[[self delegateOwner] setTitleText:theTitle];
		}
		
		// Set our "show border" checkbox from the defaults
		[[self delegateOwner] setBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"iFramePageIsBordered"]
							   forKey:@"iFrameIsBordered"];
		
		// Make full page as appropriate
		int linkType = [[self delegateOwner] integerForKey:@"linkType"];
		if (linkType == kPlainLink || linkType == kNewWindowLink) {
			[[self delegateOwner] setPluginHTMLIsFullPage:YES];
		}
		else {
			[[self delegateOwner] setPluginHTMLIsFullPage:NO];
		}
	}
	
	KTPage *page = [self delegateOwner];
	int linkType = [page integerForKey:@"linkType"];
	BOOL linkTypeIsPageWithinPage = (linkType != kPlainLink && linkType != kNewWindowLink);
	[page setDisableComments:!linkTypeIsPageWithinPage];
	[page setSidebarChangeable:linkTypeIsPageWithinPage];
	[page setFileExtensionIsEditable:linkTypeIsPageWithinPage];
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];
	
	NSString *urlString = [aDictionary valueForKey:kKTDataSourceURLString];
	[[self delegateOwner] setValue:urlString forKey:@"linkURL"];
}

#pragma mark -
#pragma mark Plugin

- (void)setDelegateOwner:(KTPage *)plugin
{
	[[self delegateOwner] removeObserver:self forKeyPath:@"iFrameIsBordered"];
	[super setDelegateOwner:plugin];
	[[self delegateOwner] addObserver:self forKeyPath:@"iFrameIsBordered" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [self delegateOwner] && ![object isFault])
	{
		if ([keyPath isEqualToString:@"iFrameIsBordered"])
		{
			NSNumber *newValue = [change objectForKey:NSKeyValueChangeNewKey];
			if ([newValue isKindOfClass:[NSNumber class]])
			{
				[[NSUserDefaults standardUserDefaults] setBool:[newValue boolValue] forKey:@"iFramePageIsBordered"];
			}
		}
	}
}

/*	Keeps various page properties up-to-date with the plugin.
 */
- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;
{
	if ([key isEqualToString:@"linkType"])
	{
		LinkPageType linkType = [value intValue];
		BOOL linkTypeIsPageWithinPage = (linkType != kPlainLink && linkType != kNewWindowLink);
		
		[[self delegateOwner] setPluginHTMLIsFullPage:!linkTypeIsPageWithinPage];
		[[self delegateOwner] setDisableComments:!linkTypeIsPageWithinPage];
		[[self delegateOwner] setSidebarChangeable:linkTypeIsPageWithinPage];
		[(KTPage *)plugin setFileExtensionIsEditable:linkTypeIsPageWithinPage];
		
		NSString *customPath = nil;
		if (!linkTypeIsPageWithinPage) customPath = [plugin valueForKey:@"linkURL"];
		[(KTPage *)plugin setCustomPathRelativeToSite:customPath];
	}
	else if ([key isEqualToString:@"linkURL"])
	{
		LinkPageType linkType = [plugin integerForKey:@"linkType"];
		if (linkType == kPlainLink || linkType == kNewWindowLink)
		{
			[(KTPage *)plugin setCustomPathRelativeToSite:value];
		}
	}
}

- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError
{
	BOOL result = YES;
	
	if ([inKeyPath isEqualToString:@"linkURL"])
	{
		// Replace an empty entry with http://
		if (*ioValue == nil || [*ioValue isEqualToString:@""]) {
			*ioValue = @"http://";
		}
		
		*ioValue = [*ioValue stringWithValidURLScheme];
	}
	else if ([inKeyPath isEqualToString:@"iFrameWidth"])
	{
		if (*ioValue == nil || [*ioValue isEqual:@""]) {
			*ioValue = [NSNumber numberWithFloat:0.0];
		}
	}
	else
	{
		result = [super validatePluginValue:ioValue forKeyPath:inKeyPath error:outError];
	}
	
	return result;
}


#pragma mark Page methods

/*!	Cut a strict down to size
*/
// Called via recursiveComponentPerformSelector
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	
	if (*docType > KTXHTMLTransitionalDocType)
	{
		*docType = KTXHTMLTransitionalDocType;
	}
}

#pragma mark -
#pragma mark Summary

/*	Should be a class method really, but Tiger doesn't support that for KVC.
 */
- (NSString *)iFrameTemplateHTML
{
	static NSString *result;
	
	if (!result)
	{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSString *templatePath = [bundle pathForResource:@"IFrameTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

- (NSString *)summary   // Only called for page-within-page
{
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[self iFrameTemplateHTML]
														component:[self delegateOwner]];
	
	NSString *result = [parser parseTemplate];
	[parser release];
	
	return result;
}

/*	Summary differs if using page-witin-page
 */
- (NSString *)summaryHTMLKeyPath
{
	NSString *result = nil;
	
	if ([[self delegateOwner] integerForKey:@"linkType"] == kIframeLink)
	{
		result = @"delegate.summary";
	}
    
	return result;
}

- (BOOL)summaryHTMLIsEditable
{
    BOOL result = ([[self delegateOwner] integerForKey:@"linkType"] != kIframeLink);
    return result;
}

#pragma mark -
#pragma mark Support

/*	We are overriding KTPage's default behaviour to force links to be in a new target */
- (BOOL)openInNewWindow
{
	return (kNewWindowLink == [[self delegateOwner] integerForKey:@"linkType"]);
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            @"WebURLsWithTitlesPboardType",
            @"BookmarkDictionaryListPboardType",
            NSURLPboardType,	// Apple URL pasteboard type
            NSStringPboardType,
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)pboard
{
	NSArray *theArray = nil;
	
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]]
		&& nil != (theArray = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"]) )
	{
		NSArray *urlArray = [theArray objectAtIndex:0];
		return [urlArray count];
	}
	return 1;	// can't find any multiplicity
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    int result = KTSourcePriorityNone;
    
    NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > 0)
	{
		result = KTSourcePriorityReasonable;
	}
	
	return result;
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    
    NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pasteboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > 0)
	{
		NSURL *URL = [[webLocations objectAtIndex:0] URL]; 
		NSString *title = [[webLocations objectAtIndex:0] title];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (title && (id)title != [NSNull null])
		{
			[aDictionary setValue:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}

@end
