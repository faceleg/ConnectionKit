//
//  KTAbstractIndex.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/23/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTAbstractIndex.h"
#import "KTPage+Internal.h"
#import "SVHTMLTemplateParser.h"
#import "KTAbstractHTMLPlugin.h"

#import "KTWebViewComponentProtocol.h"


@interface KTAbstractIndex () <KTWebViewComponent>
@end


@implementation KTAbstractIndex

- (id)initWithPage:(KTPage *)aPage plugin:(KTAbstractHTMLPlugin *)plugin;
{
	if (self = [super init])
	{
		[self setPage:aPage];
		[self setPlugin:plugin];
	}
	return self;
}

- (void)dealloc
{
    [self setPage:nil];
	[myPlugin release];
	
	[super dealloc];
}


- (KTAbstractHTMLPlugin *)plugin { return myPlugin; }

- (void)setPlugin:(KTAbstractHTMLPlugin *)plugin
{
    [plugin retain];
    [myPlugin release];
    myPlugin = plugin;
}

- (KTPage *)page
{
    return myPage; 
}

- (void)setPage:(KTPage *)aPage
{
    [aPage retain];
    [myPage release];
    myPage = aPage;
}

/*!	Most of the context for an index comes from its page.  So chain requests to page
*/
- (id)valueForUndefinedKey:(NSString *)aKey
{
	NSLog(@"Attempt to access page property '%@' from index", aKey);
	
	id result = [myPage valueForKey:aKey];
	return result;
}

- (NSString *)cssClassName
{
	return [[self plugin] pluginPropertyForKey:@"KTCSSClassName"];
}

- (NSString *)templateHTML
{
	NSString *result = [[self plugin] templateHTMLAsString];
	return result;
}

- (NSString *)uniqueWebViewID
{
	NSString *result = [NSString stringWithFormat:@"svxindex-%@", [[self page] uniqueID]];
	return result;
}

- (KTNavigationArrowsStyle)navigationArrowsStyle
{
	return [[[self plugin] pluginPropertyForKey:@"KTIndexNavigationArrowsStyle"] intValue];
}

/*!	For gathering up of resources and such.  We don't have any special
	methods defined that allow you to just specify something in an info.plist, so if
	you want your index to do something, you need to implement the method.
*/

#pragma mark -
#pragma mark Perform selector

- (void)makeComponentsPerformSelector:(SEL)selector withObject:(void *)anObject withPage:(KTPage *)page
{
	if ([[self page] isDeleted] || [page isDeleted])
	{
		return;
	}
	
	// If possible, perform the selector on ourself
	if ([self respondsToSelector:selector])
	{
		[self performSelector:selector withObject:(id)anObject withObject:page];
	}
	
	// If a summary index, also cover our child pages
	// Technically we only need to cover the page itself and any callouts - the sidebar can be ignored
	if ([[self className] isEqualToString:@"GeneralIndex"])
	{
		NSArray *children = [[self page] sortedChildren];
		unsigned i;
		for (i = 0; i < [children count]; i++)
		{
			KTPage *page = [children objectAtIndex:i];
			[page makeComponentsPerformSelector:selector withObject:anObject withPage:page recursive:NO];
		}
	}
}

/*	It's up to subclasses to override these
 */
- (NSSet *)requiredMediaIdentifiers { return nil; }

- (void)addCSSFilePathToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSBundle *bundle = [[self plugin] bundle];
	
	if ( nil == bundle ) return;
	
	NSString *resourcePath = [bundle resourcePath];
	NSArray *cssFilesNeeded = [[self plugin] pluginPropertyForKey:@"KTPluginCSSFilesNeeded"];
	NSEnumerator *theEnum = [cssFilesNeeded objectEnumerator];
	NSString *fileName;
	
	while (nil != (fileName = [theEnum nextObject]) )
	{
		NSString *path = [resourcePath stringByAppendingPathComponent:fileName];
        //		LOG((@"%@ adding css file:%@", [self class], path));
        OBASSERT(path);
		[aSet addObject:path];
	}
}

@end
