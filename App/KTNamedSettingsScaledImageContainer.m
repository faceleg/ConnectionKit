//
//  KTNamedSettingsScaledImageContainer.m
//  Marvel
//
//  Created by Mike on 11/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTNamedSettingsScaledImageContainer.h"

#import "KTMediaFile+ScaledImages.h"
#import "KTDesign.h"
#import "KTImageScalingSettings.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "MediaFiles+Internal.h"
#import "NSManagedObjectContext+KTExtensions.h"


@implementation KTNamedSettingsScaledImageContainer

+ (id)imageWithScalingSettingsNamed:(NSString *)settingsName
						  forPlugin:(KTAbstractElement *)plugin
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
	NSString *pluginID = [self valueForKey:@"pluginID"];
	KTAbstractElement *plugin = [[document managedObjectContext] pluginWithUniqueID:pluginID];
	KTPage *page = [plugin page];
	KTDesign *design = [[page master] design];
	
	// Locate the settings
	NSString *settingsName = [self valueForKey:@"scalingSettingsName"];
	KTImageScalingSettings *settings = [design imageScalingSettingsForUse:settingsName];
	
	NSDictionary *result = [NSDictionary dictionaryWithObject:settings forKey:@"scalingBehavior"];
	return result;
}

- (void)generateMediaFile
{
	NSDictionary *properties = [self latestProperties];
	KTMediaFile *sourceFile = [[self valueForKey:@"sourceMedia"] file];
	
	KTScaledImageProperties *generatedProperties = [sourceFile scaledImageWithProperties:properties];
	[self setValue:generatedProperties forKey:@"generatedProperties"];
	[self setValue:[generatedProperties valueForKey:@"destinationFile"] forKey:@"file"];
}

@end
