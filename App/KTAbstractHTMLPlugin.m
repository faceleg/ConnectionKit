//
//  KTAbstractHTMLPlugin.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractHTMLPlugin.h"

#import "KT.h"
#import "NSImage+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"

@implementation KTAbstractHTMLPlugin

#pragma mark -
#pragma mark Init & Dealloc

+ (void)load
{
	[KTAppPlugin registerPluginClass:[KTAppPlugin class] forFileExtension:kKTDataSourceExtension];
}

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

@end
