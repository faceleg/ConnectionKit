//
//  KTNamedSettingsScaledImageContainer.m
//  Marvel
//
//  Created by Mike on 11/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTNamedSettingsScaledImageContainer.h"

#import "KTDesign.h"
#import "KTImageScalingSettings.h"
#import "KTMaster+Internal.h"
#import "KTPage.h"

#import "NSManagedObjectContext+KTExtensions.h"
#import "NSThread+Karelia.h"


@implementation KTNamedSettingsScaledImageContainer

+ (id)imageWithScalingSettingsNamed:(NSString *)settingsName
						  forPlugin:(KTAbstractPage *)plugin
						sourceMedia:(KTMediaContainer *)sourceMedia
{
	// Create the media container first
	id result = [NSEntityDescription insertNewObjectForEntityForName:@"NamedScaledImageContainer"
											  inManagedObjectContext:[sourceMedia managedObjectContext]];
	
	[result setValue:sourceMedia forKey:@"sourceMedia"];
	[result setValue:settingsName forKey:@"scalingSettingsName"];
	[result setValue:[plugin uniqueID] forKey:@"pluginID"];
	
	// Finish
	return result;
}

- (NSDictionary *)latestProperties
{
	KTDocument *document = [[self mediaManager] document];
	
	// Find the plugin, and thereby its design.
    KTAbstractElement *plugin = nil;
    
	NSString *pluginID = [self valueForKey:@"pluginID"];
    if (pluginID)
    {
        plugin = [[document managedObjectContext] pluginWithUniqueID:pluginID];
    }
    
    if (!plugin) return nil;
    
    
    // Locate the settings
	KTPage *page = [plugin page];
	KTDesign *design = [[page master] design];
	
	NSString *settingsName = [self valueForKey:@"scalingSettingsName"];
	NSDictionary *result = [design imageScalingPropertiesForUse:settingsName];
	
	return result;
}

@end
