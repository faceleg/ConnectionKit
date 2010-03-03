//
//  KTElementPlugin.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTElementPlugin.h"
#import "KT.h"
#import "NSBundle+Karelia.h"

#import "Registration.h"

@implementation KTElementPlugin

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
 
- (NSComparisonResult)compareTitles:(KSPlugin *)aPlugin;
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
	NSDictionary *pluginDict = [KSPlugin pluginsWithFileExtension:kKTElementExtension];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[pluginDict count]];
	
	NSEnumerator *pluginsEnumerator = [pluginDict objectEnumerator];
	KSPlugin *aPlugin;
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
	NSDictionary *pluginDict = [KSPlugin pluginsWithFileExtension:kKTElementExtension];
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[pluginDict count]];
	
	NSEnumerator *pluginsEnumerator = [pluginDict objectEnumerator];
	KSPlugin *aPlugin;
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

// nil targeted actions will be sent to firstResponder (the active document)
// representedObject is the bundle of the plugin
+ (void)addPlugins:(NSSet *)plugins
		    toMenu:(NSMenu *)aMenu
		    target:(id)aTarget
		    action:(SEL)anAction
	     pullsDown:(BOOL)isPullDown
	     showIcons:(BOOL)showIcons
		smallIcons:(BOOL)smallIcons
		 smallText:(BOOL)smallText
{
    if ( isPullDown ) {
        // if it's a pulldown, we need to add an empty menu item at the top of the menu
        [aMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];
    }
	
	// First go through and get the localized names of each bundle, and put into a dict keyed by name
	NSMutableDictionary *dictOfPlugins = [NSMutableDictionary dictionary];
	
		// go through each plugin.
    KTAbstractHTMLPlugin *plugin;
	
	for (plugin in plugins)
	{
		int priority = 5;		// default if unspecified (RichText=1, Photo=2, other=5, Advanced HTML = 9
		id priorityID = [plugin pluginPropertyForKey:@"KTPluginPriority"];
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		}
		if (priority > 0	// don't add zero-priority items to menu!
			&& (priority < 9 || (nil == gRegistrationString) || gIsPro) )	// only if non-advanced or advanced allowed.
		{
			NSString *pluginName = nil;
			if (anAction == @selector(addPage:) || anAction == nil) {
				pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
			}
			else if (anAction == @selector(addPagelet:)) {
				pluginName = [plugin pluginPropertyForKey:@"KTPageletName"];
			}
			if (!pluginName)
			{
				pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
			}
			
			[dictOfPlugins setObject:plugin
							  forKey:[NSString stringWithFormat:@"%d %@", priority, pluginName]];
		}
	}
	
	// Now add the sorted arrays
	NSArray *sortedPriorityNames = [[dictOfPlugins allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator *sortedEnum = [sortedPriorityNames objectEnumerator];
	NSString *priorityAndName;
	
	while (nil != (priorityAndName = [sortedEnum nextObject]) )
	{
		KTAbstractHTMLPlugin *plugin = [dictOfPlugins objectForKey:priorityAndName];
		NSBundle *bundle = [plugin bundle];
		
        if ( ![bundle isLoaded] && (Nil != [bundle principalClassIncludingOtherLoadedBundles:YES]) ) {
            [bundle load];
        }
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
		
		NSString *pluginName = nil;
		if (anAction == @selector(addPage:) || anAction == nil) {
			pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
		}
		else if (anAction == @selector(addPagelet:)) {
			pluginName = [plugin pluginPropertyForKey:@"KTPageletName"];
		}
		if (!pluginName)
		{
			pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
		}
		
		
		id priorityID = [plugin pluginPropertyForKey:@"KTPluginPriority"];
		int priority = 5;
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		}
		
		
		if (!pluginName || [pluginName isEqualToString:@""])
		{
			NSLog(@"empty plugin name for %@", plugin);
			pluginName = @"";
		}
		
		// set up the image
		if (showIcons)
		{
			NSImage *image = [plugin pluginIcon];
#ifdef DEBUG
			if (nil == image)
			{
				NSLog(@"nil pluginIcon for %@", pluginName);
			}
#endif
			
			[image setDataRetained:YES];	// allow image to be scaled.
			[image setScalesWhenResized:YES];
			// FIXME: it would be better to pre-scale images in the same family rather than scale here, larger than 32 might be warranted in some cases, too
			[image setSize:smallIcons ? NSMakeSize(16.0, 16.0) : NSMakeSize(32.0, 32.0)];
			[menuItem setImage:image];
			
			float imageHeight = image ? [image size].height : 0.0;	// test for non-nil to avoid "The receiver in the message expression is 'nil' and results in the returned value (of type 'NSSize') to be garbage or otherwise undefined"

			[style setMinimumLineHeight:imageHeight];
			
			NSFont *titleFont = [NSFont menuFontOfSize:(smallText ? [NSFont smallSystemFontSize] : [NSFont systemFontSize])];
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
										titleFont, NSFontAttributeName,
										style, NSParagraphStyleAttributeName,
										[NSNumber numberWithFloat:(((imageHeight-[NSFont smallSystemFontSize])/2.0)+2.0)], NSBaselineOffsetAttributeName,
										nil];
			NSAttributedString *titleString = [[[NSAttributedString alloc] initWithString:pluginName attributes:attributes] autorelease];
			[menuItem setAttributedTitle:titleString];
			if (9 == priority && nil == gRegistrationString)
			{
				[[NSApp delegate] setMenuItemPro:menuItem];
			}
		}
		else
		{
			[menuItem setTitle:pluginName];
		}
		
		
		if ([plugin isKindOfClass:self])
		{
			[menuItem setRepresentedObject:plugin];
		}
		else
		{
			[menuItem setRepresentedObject:[[plugin bundle] bundleIdentifier]];
		}
		
		// set target/action
		[menuItem setAction:anAction];
		[menuItem setTarget:aTarget];
		
		[aMenu addItem:menuItem];
	}
}




@end
