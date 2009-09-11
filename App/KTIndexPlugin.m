//
//  KTIndexPlugin.m
//  Marvel
//
//  Created by Mike on 14/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTIndexPlugin.h"
#import "KT.h"
#import "NSBundle+Karelia.h"
#import "KTAppDelegate.h"

#import "Registration.h"

@implementation KTIndexPlugin

+ (void)load
{
	[self registerPluginClass:[self class] forFileExtension:kKTIndexExtension];
}

- (id)defaultPluginPropertyForKey:(NSString *)key
{
	if ([key isEqualToString:@"KTIndexNavigationArrowsStyle"])
	{
		return [NSNumber numberWithInt:0];
	}
	else
	{
		return [super defaultPluginPropertyForKey:key];
	}
}


// Special version of above, but it looks for KTPresets and adds those items to the menu

+ (void)addPresetPluginsToMenu:(NSMenu *)aMenu
						target:(id)aTarget
						action:(SEL)anAction
					 pullsDown:(BOOL)isPullDown
					 showIcons:(BOOL)showIcons
					smallIcons:(BOOL)smallIcons
					 smallText:(BOOL)smallText
			 allowNewPageTypes:(BOOL)allowNewPageTypes
{
    if ( isPullDown ) {
        // if it's a pulldown, we need to add an empty menu item at the top of the menu
        [aMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];
    }
	
	// First go through and get the localized names of each bundle, and put into a dict keyed by name
	NSMutableDictionary *dictOfPresets = [NSMutableDictionary dictionary];
	
    NSDictionary *plugins = [KSPlugin pluginsWithFileExtension:kKTIndexExtension];
    NSEnumerator *enumerator = [plugins objectEnumerator];	// go through each plugin.
    KTAbstractHTMLPlugin *plugin;
    
	while (plugin = [enumerator nextObject])
	{
		NSBundle *bundle = [plugin bundle];
		
		NSArray *presets = [bundle objectForInfoDictionaryKey:@"KTPresets"];
		NSEnumerator *presetEnum = [presets objectEnumerator];
		NSDictionary *presetDict;
		
		while (nil != (presetDict = [presetEnum nextObject]) )
		{
			if (allowNewPageTypes || nil == [presetDict objectForKey:@"KTPreferredPageBundleIdentifier"])	// do not add presets that specify a preset bundle identifier to this list, like the Raw HTML index
			{
				int priority = 5;		// default if unspecified (RichText=1, Photo=2, other=5, Advanced HTML = 9
				id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
				if (nil != priorityID)
				{
					priority = [priorityID intValue];
				} 
				if (priority > 0	// don't add zero-priority items to menu!
					&& (priority < 9 || (nil == gRegistrationString) || gIsPro) )	// only if non-advanced or advanced allowed.
				{
					NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetTitle"];
					NSString *presetTitle = [bundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
					
					NSMutableDictionary *newPreset = [NSMutableDictionary dictionaryWithDictionary:presetDict];
					[newPreset setObject:[bundle bundleIdentifier] forKey:@"KTPresetIndexBundleIdentifier"];
					
					[dictOfPresets setObject:[NSDictionary dictionaryWithDictionary:newPreset]
									  forKey:[NSString stringWithFormat:@"%d %@", priority, presetTitle]];
				}
			}
		}
	}
	
	// Now add the sorted arrays
	NSArray *sortedPriorityNames = [[dictOfPresets allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator *sortedEnum = [sortedPriorityNames objectEnumerator];
	NSString *priorityAndName;
	
	while (nil != (priorityAndName = [sortedEnum nextObject]) )
	{
		NSDictionary *presetDict = [dictOfPresets objectForKey:priorityAndName];
		NSString *bundleIdentifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
		
		KTIndexPlugin *plugin = [KTIndexPlugin pluginWithIdentifier:bundleIdentifier];
		NSBundle *pluginBundle = [plugin bundle];
		
        if ( ![pluginBundle isLoaded] && (Nil != [pluginBundle principalClassIncludingOtherLoadedBundles:YES]) ) {
            [pluginBundle load];
        }
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
		
		NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetTitle"];
		NSString *presetTitle = [pluginBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
		id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
		int priority = 5;
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		} 
		
		
		// set up the image
		if (showIcons)
		{
			NSImage *image = [plugin pluginIcon];
			float imageHeight = image ? [image size].height : 0.0;
#ifdef DEBUG
			if (nil == image)
			{
				NSLog(@"nil pluginIcon for %@", presetTitle);
			}
#endif
			if (image)
			{
				
				[image setDataRetained:YES];	// allow image to be scaled.
				[image setScalesWhenResized:YES];
				// FIXME: it would be better to pre-scale images in the same family rather than scale here, larger than 32 might be warranted in some cases, too
				[image setSize:smallIcons ? NSMakeSize(16.0, 16.0) : NSMakeSize(32.0, 32.0)];
                // hacky fix for menu height problem: if we change the image size, above, we need to change the imageHeight, too
                imageHeight = [image size].height;
				[menuItem setImage:image];
				[style setMinimumLineHeight:imageHeight];
			}
			NSFont *titleFont = [NSFont menuFontOfSize:(smallText ? [NSFont smallSystemFontSize] : [NSFont systemFontSize])];
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
										titleFont, NSFontAttributeName,
										style, NSParagraphStyleAttributeName,
										[NSNumber numberWithFloat:(((imageHeight-[NSFont smallSystemFontSize])/2.0)+2.0)], NSBaselineOffsetAttributeName,
										nil];
			NSAttributedString *titleString = [[[NSAttributedString alloc] initWithString:presetTitle attributes:attributes] autorelease];
			[menuItem setAttributedTitle:titleString];
		}
		else
		{
			[menuItem setTitle:presetTitle];
		}
		
		if (9 == priority && nil == gRegistrationString)
		{
			[[NSApp delegate] setMenuItemPro:menuItem];
		}
		
		// set target/action
		[menuItem setRepresentedObject:presetDict];
		[menuItem setAction:anAction];
		[menuItem setTarget:aTarget];
		
		[aMenu addItem:menuItem];
	}
}


@end
