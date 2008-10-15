//
//  DiggPageletDelegate.m
//  DiggPagelet
//
//  Copyright (c) 2006, Karelia Software. All rights reserved.
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

#import "TwitterElementDelegate.h"

#import "NSURL+Twitter.h"


// LocalizedStringInThisBundle(@"This is a placeholder for a Twitter pagelet. It will appear here once published or if you enable live data feeds in the preferences.", "WebView Placeholder")
// LocalizedStringInThisBundle(@"Please enter your Twitter username or", "WebView prompt fragment")
// LocalizedStringInThisBundle(@"sign up", "WebView prompt fragment")
// LocalizedStringInThisBundle(@"for a Twitter account", "WebView prompt fragment")



@implementation TwitterElementDelegate

#pragma mark -
#pragma mark Class Methods

+ (NSString *)scriptTemplate
{
	static NSString *result;
	
	if (!result)
	{
		NSString *path = [[NSBundle bundleForClass:self] pathForResource:@"scripttemplate" ofType:@"html"];
		OBASSERT(path);
		
		result = [[NSString alloc] initWithContentsOfFile:path usedEncoding:NULL error:NULL];
	}
	
	return result;
}

#pragma mark -
#pragma mark Init

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	// Look for a YouTube URL
	NSString *URLString = [aDataSourceDictionary valueForKey:kKTDataSourceURLString];
	if (URLString)
	{
		NSURL *URL = [NSURL URLWithString:URLString];
		NSString *username = [URL twitterUsername];
        if (username)
		{
			[[self delegateOwner] setValue:username forKey:@"username"];
		}
	}
}

#pragma mark -
#pragma mark Other

- (IBAction)openTwitter:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://twitter.com"]];
}

- (NSString *)twitterCallbackScriptPath
{
	NSString *result = [[self bundle] pathForResource:@"twittercallback" ofType:@"js"];
	return result;
}

- (void)addLevelTextToEndBody:(NSMutableString *)ioString forPage:(KTPage *)aPage
{
	if ([[self delegateOwner] valueForKey:@"username"])
	{
		NSString *template = [[self class] scriptTemplate];
		KTHTMLParser *parser = [[KTHTMLParser alloc] initWithTemplate:template component:[self delegateOwner]];
		[parser setCurrentPage:aPage];
		
		NSString *script = [parser parseTemplate];
		if (script)
		{
			// Only append the script if it's not already there (e.g. if there's > 1 element)
			if ([ioString rangeOfString:script].location == NSNotFound) {
				[ioString appendString:script];
			}
		}
		
		[parser release];
	}
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedDragTypes
{
	return [NSURL KTComponentsSupportedURLPasteboardTypes];
}

+ (unsigned)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)sender
{
    return 1;
}

+ (KTSourcePriority)priorityForDrag:(id <NSDraggingInfo>)draggingInfo atIndex:(unsigned)dragIndex
{
	KTSourcePriority result = KTSourcePriorityNone;
    
	NSArray *URLs = nil;
	
	[NSURL getURLs:&URLs
		 andTitles:NULL
	fromPasteboard:[draggingInfo draggingPasteboard]
   readWeblocFiles:YES
	ignoreFileURLs:YES];
	
	if (URLs && [URLs count] > dragIndex)
	{
		NSURL *URL = [URLs objectAtIndex:dragIndex];
		if ([URL twitterUsername])
		{
			result = KTSourcePrioritySpecialized;
		}
	}
	
	return result;
}

+ (BOOL)populateDragDictionary:(NSMutableDictionary *)aDictionary
              fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
                       atIndex:(unsigned)dragIndex;
{
	BOOL result = NO;
    
    NSArray *URLs = nil;
	NSArray *titles = nil;
	
	[NSURL getURLs:&URLs
		 andTitles:&titles
	fromPasteboard:[draggingInfo draggingPasteboard]
   readWeblocFiles:YES
	ignoreFileURLs:YES];
	
	if (URLs && [URLs count] > dragIndex && [titles count] > dragIndex)
	{
		NSURL *URL = [URLs objectAtIndex:dragIndex];
		NSString *title = [titles objectAtIndex:dragIndex];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (!KSISNULL(title))
		{
			[aDictionary setObject:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}

@end
