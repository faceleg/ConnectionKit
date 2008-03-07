//
//  KTAbstractHTMLPlugin.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractHTMLPlugin.h"

#import "KT.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "Registration.h"
#import "KTAppDelegate.h"
#import "KTIndexPlugin.h"

@implementation KTAbstractHTMLPlugin

#pragma mark -
#pragma mark Init & Dealloc


- (void)dealloc
{
	[myIcon release];
	[myTemplateHTML release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

/*	Implemented for the sake of bindings
 */
- (NSString *)pluginName { return [self pluginPropertyForKey:@"KTPluginName"]; }

- (NSImage *)pluginIcon
{
	// The icon is cached; load it if not cached yet
	if (!myIcon)
	{
		// It could be a relative (to the bundle) or absolute path
		NSString *filename = [self pluginPropertyForKey:@"KTPluginIconName"];
		if (![filename hasPrefix:@"/"])
		{
			filename = [[self bundle] pathForImageResource:filename];
		}
		
		// Create the icon, falling back to the broken image if necessary
		myIcon = [[NSImage alloc] initByReferencingFile:filename];
		if (!myIcon)
		{
			myIcon = [[NSImage brokenImage] retain];
		}
	}
	
	return myIcon;
}

- (NSString *)CSSClassName
{
	// TODO: If nothing is specified, try to assemble a good guess from the plugin properties
	return [self pluginPropertyForKey:@"KTCSSClassName"];
}

- (NSString *)templateHTMLAsString
{
	if (!myTemplateHTML)
	{
		NSString *templateName = [self pluginPropertyForKey:@"KTTemplateName"];
		NSString *path = [[self bundle] overridingPathForResource:templateName ofType:@"html"];
		
		if (path)	// This actually used to use NSData and then NSString, but no-one recalls why!
		{
			myTemplateHTML = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
		}
		
		if (!myTemplateHTML)	// If the HTML can't be loaded, don't bother trying again
		{
			myTemplateHTML = [[NSNull null] retain];
		}
	}
	
	NSString *result = myTemplateHTML;
	if ([result isEqual:[NSNull null]])
	{
		result = nil;
	}
	return result;
}

#pragma mark -
#pragma mark Properties

- (id)defaultPluginPropertyForKey:(NSString *)key
{
	if ([key isEqualToString:@"KTPluginPriority"])
	{
		return [NSNumber numberWithUnsignedInt:5];
	}
	else if ([key isEqualToString:@"KTTemplateName"])
	{
		return @"template";
	}
	else
	{
		return [super defaultPluginPropertyForKey:key];
	}
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
{
    if ( isPullDown ) {
        // if it's a pulldown, we need to add an empty menu item at the top of the menu
        [aMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];
    }
	
	// First go through and get the localized names of each bundle, and put into a dict keyed by name
	NSMutableDictionary *dictOfPlugins = [NSMutableDictionary dictionary];
	
	NSEnumerator *enumerator = [plugins objectEnumerator];	// go through each plugin.
    KTAbstractHTMLPlugin *plugin;
	
	while (plugin = [enumerator nextObject])
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
			NSString *pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
			if (anAction == @selector(addPage:) || anAction == nil) {
				pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
			}
			else if (anAction == @selector(addPagelet:)) {
				pluginName = [plugin pluginPropertyForKey:@"KTPageletName"];
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
		
        if ( ![bundle isLoaded] && (Nil != [NSBundle principalClassForBundle:bundle]) ) {
            [bundle load];
        }
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
		
		NSString *pluginName = [plugin pluginPropertyForKey:@"KTPluginName"];
		if (anAction == @selector(addPage:) || anAction == nil) {
			pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
		}
		else if (anAction == @selector(addPagelet:)) {
			pluginName = [plugin pluginPropertyForKey:@"KTPageName"];
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
			[image setSize:NSMakeSize(32.0, 32.0)];
			[menuItem setImage:image];
			[style setMinimumLineHeight:[image size].height];
			
			NSFont *titleFont = [NSFont menuFontOfSize:[NSFont smallSystemFontSize]];
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
										titleFont, NSFontAttributeName,
										style, NSParagraphStyleAttributeName,
										[NSNumber numberWithFloat:((([image size].height-[NSFont smallSystemFontSize])/2.0)+2.0)], NSBaselineOffsetAttributeName,
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
		
		// set target/action
		[menuItem setRepresentedObject:plugin];
		[menuItem setAction:anAction];
		[menuItem setTarget:aTarget];
		
		[aMenu addItem:menuItem];
	}
}




@end
