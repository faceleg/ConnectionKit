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
#import "KTHTMLPlugInWrapper.h"

#import "KTWebViewComponentProtocol.h"


@interface KTAbstractIndex () <KTWebViewComponent>
@end


@implementation KTAbstractIndex

- (id)initWithPage:(KTPage *)aPage plugin:(KTHTMLPlugInWrapper *)plugin;
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
	[_plugin release];
	
	[super dealloc];
}


- (KTHTMLPlugInWrapper *)plugin { return _plugin; }

- (void)setPlugin:(KTHTMLPlugInWrapper *)plugin
{
    [plugin retain];
    [_plugin release];
    _plugin = plugin;
}

- (KTPage *)page
{
    return _page; 
}

- (void)setPage:(KTPage *)aPage
{
    [aPage retain];
    [_page release];
    _page = aPage;
}

/*!	Most of the context for an index comes from its page.  So chain requests to page
*/
- (id)valueForUndefinedKey:(NSString *)aKey
{
	NSLog(@"Attempt to access page property '%@' from index", aKey);
	
	id result = [_page valueForKey:aKey];
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
