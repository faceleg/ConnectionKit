//
//  HTMLElementDelegate.m
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

#import "HTMLElementDelegate.h"


@interface HTMLElementDelegate ()
- (void)validateHTML;
@end


@implementation HTMLElementDelegate

#pragma mark awake

/// THIS METHOD SHOULD TRACK WHAT IS IN HTMLPAGEDELEGATE
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];
	
    NSString *filePath = [aDictionary valueForKey:kKTDataSourceFilePath];
	if ( nil != filePath )
	{
		NSData *data = [NSData dataWithContentsOfFile:filePath];
		NSString *string = [NSString stringWithHTMLData:data];
		if (nil == string)
		{
			NSLog(@"Unable to set HTML from file at %@", filePath);
		}
		else
		{
			[[self delegateOwner] setObject:string forKey:@"html"];
		}
	}
	else
	{
		NSString *string = [aDictionary valueForKey:kKTDataSourceString];
		[[self delegateOwner] setObject:string forKey:@"html"];
	}
	
	[[self undoManager] setActionName:LocalizedStringInThisBundle(@"Insert Raw HTML", "adding raw html via d-n-d")];
}

#pragma mark media management

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet set];
	
	// scan for svxmedia:// URLs, returning set of media identifiers
	NSString *svxString = @"<img src=\"svxmedia://";
	
	NSString *html = [[self delegateOwner] valueForKey:@"html"];
	OFF((@"scanning block for identifiers: \n%@", html));
	if ( [html length] > [svxString length] )
	{
		NSScanner *scanner = [NSScanner scannerWithString:html];
		while ( ![scanner isAtEnd] )
		{
			if ( [scanner scanUpToRealString:svxString intoString:NULL] )
			{
				if ( [scanner scanRealString:svxString intoString:NULL] )
				{
					NSString *mediaPath = nil;
					if ( [scanner scanUpToString:@"\"" intoString:&mediaPath] )
					{
						NSString *mediaIdentifier = [mediaPath lastPathComponent];
						[result addObject:mediaIdentifier];
					}
				}
			}
		}
	}
	
	return result;
}

#pragma mark KVO/bindings

- (NSString *)htmlWithDelay
{
    return [self html];	// just read from the actual HTML?  For bindings.
}

- (void)setHtmlWithDelay:(NSString *)anHtmlWithDelay
{
    [anHtmlWithDelay retain];
    [myHtmlWithDelay release];
    myHtmlWithDelay = anHtmlWithDelay;
	
	// Then set up a set of the real HTML key after a delay
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setHTMLPropertyFromDelayedHTML) object:nil];
	[self performSelector:@selector(setHTMLPropertyFromDelayedHTML) withObject:nil afterDelay:1.5];
}

- (void)setHTMLPropertyFromDelayedHTML
{
	DJW((@"Copying delayed HTML to the property: %@", myHtmlWithDelay));
	[self setHtml:myHtmlWithDelay];
}

- (NSString *)html
{
    return [[self delegateOwner] objectForKey:@"html"]; 
}

- (void)setHtml:(NSString *)inHTML
{
	[[self delegateOwner] setObject:inHTML forKey:@"html"];
		
	// it would be better to coalesce this last bit, if possible
	// right now, we're updating the display (and the undo stack)
	// after every keypress!
	[[[self delegateOwner] managedObjectContext] processPendingChanges];
	[[self undoManager] setActionName:LocalizedStringInThisBundle(@"Edit Raw HTML", "editing raw html")];
}

#pragma mark -
#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"html"; }

- (BOOL)summaryHTMLIsEditable { return NO; }

#pragma mark Page support

// THIS METHOD IS CALLED via recursiveComponentPerformSelector

/*!	Downgrade to transitional unless "strict" XHTML is known
*/
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	int htmlType = [[self delegateOwner] integerForKey:@"htmlType"]; // [self delegateOwner] or [self pluginProperties] or ???
	
	if (htmlType < *docType)
	{
		*docType = htmlType;	// downgrade;
	}
}

#pragma mark -
#pragma mark Data Migrator

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    KTAbstractElement *element = [self delegateOwner];
    
    // Import normal properties
    [element setValuesForKeysWithDictionary:oldPluginProperties];
    
    // Import full-pageness
    if ([element isKindOfClass:[KTPage class]])
    {
        [(KTPage *)element setPluginHTMLIsFullPage:
         [[oldPlugin valueForKeyPath:@"container.pluginProperties.fillEntirePage"] boolValue]];
    }
    
    return YES;
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            NSFilenamesPboardType,			// We'll take a file that's HTML type
            NSStringPboardType,				// We'll take plain text with HTML contents
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)sender { return 1; }

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    [pboard types];
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:dragIndex];
            
			// check to see if it's an rich text file
			NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible
			if ([NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeHTML] )
			{
				return KTSourcePriorityIdeal;
			}
		}
    }
	else
	{
		NSString *string = [pboard stringForType:NSStringPboardType];
		// Do some scanning to see if it looks like HTML by trying to find some basic types
		NSScanner *scanner = [NSScanner scannerWithString:string];
		int confidence = 0;
		BOOL keepGoing = YES;
		while (keepGoing)
		{
			(void) [scanner scanUpToString:@"<" intoString:nil];
			keepGoing = [scanner scanString:@"<" intoString:nil];	// see if we are at a <
			if (keepGoing)
			{
				static NSArray *sTagPatterns = nil;
				
				// Quick & dirty pattern matching.
				if (nil == sTagPatterns) sTagPatterns = [[NSArray alloc] initWithObjects:
                                                         @"html>", @"b>", @"i>", @"br>", @"br />", @"p>", @"p />", @"a href=", @"span ", @"div ",
                                                         @"/html>", @"/b>", @"/i>", @"/p>", @"/a>", @"/span>", @"/div>",
                                                         @"img src=", nil];
				NSEnumerator *theEnum = [sTagPatterns objectEnumerator];
				NSString *pattern;
                
				while (nil != (pattern = [theEnum nextObject]) )
				{
					BOOL foundPattern = [scanner scanRealString:pattern intoString:nil];
					if (foundPattern)
					{
						confidence++;	// increment confidence factor
						break;			// no need to keep scanning this tag
					}
				}
				if (confidence >= 3)
				{
					return KTSourcePriorityReasonable;	// OK, I'm convinced.   This is HTML.  (Ideal?)
					// (Perhaps some more specialized data source will scan for more specific patterns.)
				}
			}
		}
	}
    return KTSourcePriorityNone;	// one of our other types -- string, rich text ... sounds good to me!
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    NSString *filePath = nil;
    
    NSArray *orderedTypes = [self supportedPasteboardTypesForCreatingPagelet:isCreatingPagelet];
    
    
    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
    if ( [bestType isEqualToString:NSFilenamesPboardType] )
    {
		NSArray *filePaths = [pasteboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [filePaths count])
		{
			filePath = [filePaths objectAtIndex:dragIndex];
			if ( nil != filePath )
			{
				[aDictionary setValue:[[NSFileManager defaultManager] resolvedAliasPath:filePath]
							   forKey:kKTDataSourceFilePath];
				[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
				result = YES;
			}
		}
    }
	else
	{
		NSString *string = [pasteboard stringForType:NSStringPboardType];
		[aDictionary setValue:string forKey:kKTDataSourceString];
		result = YES;
	}
    
    return result;
}

@end
