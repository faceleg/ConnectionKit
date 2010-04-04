//
//  KTElementPlugInWrapper.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTElementPlugInWrapper.h"
#import "KT.h"
#import "NSBundle+Karelia.h"

#import "Registration.h"

@implementation KTElementPlugInWrapper

+ (void)load
{
	[self registerPluginClass:[self class] forFileExtension:kKTElementExtension];
}

#pragma mark -
#pragma mark Properties

- (id)defaultPluginPropertyForKey:(NSString *)key;
{
	if ([key isEqualToString:@"KTElementAllowsIntroduction"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTElementSupportsPageUsage"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTElementSupportsPageletUsage"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageAllowsCallouts"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTPageShowSidebar"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageAllowsNavigation"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageDisableComments"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTPageletCanHaveTitle"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageSidebarChangeable"])
	{
		return [NSNumber numberWithBool:YES];
	}
	else if ([key isEqualToString:@"KTPageSeparateInspectorSegment"])
	{
		return [NSNumber numberWithBool:NO];
	}
	else if ([key isEqualToString:@"KTPageName"] || [key isEqualToString:@"KTPageletName"])
	{
		return [self pluginPropertyForKey:@"KTPluginName"];
	}
	else if ([key isEqualToString:@"KTPluginUntitledName"])
	{
		return @"";
	}
	else if ([key isEqualToString:@"KTPageUntitledName"] || [key isEqualToString:@"KTPageletUntitledName"])
	{
		return [self pluginPropertyForKey:@"KTPluginUntitledName"];
	}
	else if ([key isEqualToString:@"KTPluginDescription"])
	{
		return @"";
	}
	else if ([key isEqualToString:@"KTPageDescription"] || [key isEqualToString:@"KTPageletDescription"])
	{
		return [self pluginPropertyForKey:@"KTPluginDescription"];
	}
	else if ([key isEqualToString:@"KTPageNibFile"])
	{
		return [self pluginPropertyForKey:@"KTPluginNibFile"];
	}
	else
	{
		return [super defaultPluginPropertyForKey:key];
	}
}

- (NSString *)pageCSSClassName
{
	NSString *result = [[self CSSClassName] stringByAppendingString:@"-page"];
	return result;
}

- (NSString *)pageletCSSClassName
{
	NSString *result = [[self CSSClassName] stringByAppendingString:@"-pagelet"];
	return result;
}

/*
 
 Maybe if I override this, I can easily get a list sorted by priority
 
- (NSComparisonResult)compareTitles:(KSPlugInWrapper *)aPlugin;
{
	return [[self title] caseInsensitiveCompare:[aPlugin title]];
}
*/

#pragma mark -
#pragma mark Plugins List

/*	Returns all registered plugins that are either:
 *		A) Of the svxPage plugin type
 *		B) Of the svxElement plugin type and support page usage
 */
+ (NSSet *)pagePlugins
{
	NSDictionary *pluginDict = [KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[pluginDict count]];
	
	NSEnumerator *pluginsEnumerator = [pluginDict objectEnumerator];
	KSPlugInWrapper *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		if ([[aPlugin pluginPropertyForKey:@"KTElementSupportsPageUsage"] boolValue])
		{
			[buffer addObject:aPlugin];
		}
	}
	
	NSSet *result = [NSSet setWithSet:buffer];
	return result;
}

/*	Returns all registered plugins that are either:
 *		A) Of the svxPagelet plugin type
 *		B) Of the svxElement plugin type and support pagelet usage
 */
+ (NSSet *)pageletPlugins
{
	NSDictionary *pluginDict = [KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[pluginDict count]];
	
	NSEnumerator *pluginsEnumerator = [pluginDict objectEnumerator];
	KSPlugInWrapper *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		if ([[aPlugin pluginPropertyForKey:@"KTElementSupportsPageletUsage"] boolValue])
		{
			[buffer addObject:aPlugin];
		}
	}
	
	NSSet *result = [NSSet setWithSet:buffer];
	return result;
}

#pragma mark -
#pragma mark Plugin Handling

@end
