//
//  KTAbstractHTMLPlugin.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractHTMLPlugin.h"

#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"


@implementation KTAbstractHTMLPlugin

/*	We only want to load 1.5 and later plugins
 */
+ (BOOL)validateBundle:(NSBundle *)aCandidateBundle
{
	BOOL result = NO;
	
	NSString *minVersion = [aCandidateBundle minimumAppVersion];
	if (minVersion)
	{
		float floatMinVersion = [minVersion floatVersion];
		if (floatMinVersion >= 1.5)
		{
			result = YES;
		}
	}
	
	return result;
}

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
		
// TODO: We should not be referncing absolute paths.  Instead, we should check for 'XXXX' pattern and convert that to an OSType.
		
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


@end
