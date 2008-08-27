//
//  HTMLElementDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
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


@interface HTMLElementDelegate ( Private )
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
		NSScanner *scanner = [NSScanner scannerWithRealString:html];
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
	[[self managedObjectContext] processPendingChanges];
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

@end
