//
//  KTIndexPluginWrapper.m
//  Marvel
//
//  Created by Mike on 14/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTIndexPlugInWrapper.h"
#import "KT.h"
#import "NSBundle+Karelia.h"

#import "Registration.h"

@implementation KTIndexPlugInWrapper

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

+ (NSDictionary *)emptyCollectionPreset;
{
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                            NSLocalizedString(@"Empty Collection", "toolbar menu"), @"KTPresetTitle",
                            [NSNumber numberWithInt:0], @"KTPluginPriority",
                            nil];
    
    return result;
}

+ (void)populateMenuWithCollectionPresets:(NSMenu *)aMenu atIndex:(NSUInteger)index;
{
    NSMutableDictionary *dictOfPresets = [NSMutableDictionary dictionary];
    [dictOfPresets setObject:[self emptyCollectionPreset] forKey:@"0"];
	
    
    // Go through and get the localized names of each bundle, and put into a dict keyed by name
    NSDictionary *plugins = [KSPlugInWrapper pluginsWithFileExtension:kKTIndexExtension];
    NSEnumerator *enumerator = [plugins objectEnumerator];	// go through each plugin.
    KTHTMLPlugInWrapper *plugin;
    
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
			NSLog(@"DJW TO HANDLE THIS LOGIC");
            if (priority > 0	// don't add zero-priority items to menu!
                && (priority < 9 || gIsPro || (nil == gRegistrationString)) )	// only if non-advanced or advanced allowed.
            {
                NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetTitle"];
                NSString *presetTitle = [bundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
                
                NSMutableDictionary *newPreset = [presetDict mutableCopy];
                [newPreset setObject:[bundle bundleIdentifier] forKey:@"KTPresetIndexBundleIdentifier"];
                
                [dictOfPresets setObject:newPreset
                                  forKey:[NSString stringWithFormat:@"%d %@", priority, presetTitle]];
                
                [newPreset release];
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
		
		KTIndexPlugInWrapper *plugin = (bundleIdentifier ?
                                        [KTIndexPlugInWrapper pluginWithIdentifier:bundleIdentifier] :
                                        nil);
		
        NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		
		NSString *presetTitle = [presetDict objectForKey:@"KTPresetTitle"];
        if (plugin) presetTitle = [[plugin bundle] localizedStringForKey:presetTitle
                                                                   value:presetTitle
                                                                   table:nil];
        
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
			// [menuItem setPro:YES];
			// TODO: deal with notification
		}
		NSLog(@"DJW to del with pro/registration issues once this is going again");
		
		// set target/action
		[menuItem setRepresentedObject:presetDict];
		[menuItem setAction:@selector(addCollection:)];
		
		[aMenu insertItem:menuItem atIndex:index];  index++;
	}
}


@end
