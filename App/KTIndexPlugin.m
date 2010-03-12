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


+ (void)populateMenuWithCollectionPresets:(NSMenu *)aMenu atIndex:(NSUInteger)index;
{
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
		
		NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetTitle"];
		NSString *presetTitle = [pluginBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
		id priorityID = [presetDict objectForKey:@"KTPluginPriority"];
		int priority = 5;
		if (nil != priorityID)
		{
			priority = [priorityID intValue];
		} 
		
		
        NSImage *image = [plugin pluginIcon];
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
            [image setSize:NSMakeSize(32.0f, 32.0f)];
            [menuItem setImage:image];
        }
        
        [menuItem setTitle:presetTitle];
		
		if (9 == priority && nil == gRegistrationString)
		{
			[[NSApp delegate] setMenuItemPro:menuItem];
		}
		
		// set target/action
		[menuItem setRepresentedObject:presetDict];
		[menuItem setAction:@selector(addCollection:)];
		
		[aMenu insertItem:menuItem atIndex:index];  index++;
	}
}


@end
