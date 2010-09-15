//
//  KTHTMLPlugInWrapper.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTHTMLPlugInWrapper.h"

#import "SVPlugInGraphic.h"
#import "SVPlugInGraphicFactory.h"

#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"


@implementation KTHTMLPlugInWrapper

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
    [_factory release];
	[_icon release];
	[_templateHTML release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (SVGraphicFactory *)graphicFactory;
{
    if (!_factory)
    {
        _factory = [[SVPlugInGraphicFactory alloc] initWithBundle:[self bundle]];
    }
    return _factory;
}

- (KTPluginCategory)category { return [[self pluginPropertyForKey:@"KTCategory"] intValue]; }

- (NSImage *)pluginIcon
{
	// The icon is cached; load it if not cached yet
	if (!_icon)
	{
		// It could be a relative (to the bundle) or absolute path
		NSString *filename = [self pluginPropertyForKey:@"KTPluginIconName"];
		if (![filename hasPrefix:@"/"])
		{
			filename = [[self bundle] pathForImageResource:filename];
		}
		
// TODO: We should not be referencing absolute paths.  Instead, we should check for 'XXXX' pattern and convert that to an OSType.
		
		//	Create the icon, falling back to the broken image if necessary
		/// BUGSID:34635	Used to use -initByReferencingFile: but seems to upset Tiger and the Pages/Pagelets popups
		_icon = [[NSImage alloc] initWithContentsOfFile:filename];
		if (!_icon)
		{
			_icon = [[NSImage brokenImage] retain];
		}
	}
	
	return _icon;
}

- (NSUInteger)priority;
{
    NSUInteger result = 5;  // default priority
    NSNumber *priority = [self pluginPropertyForKey:@"KTPluginPriority"];
    if (priority) result = [priority unsignedIntegerValue];
    return result;
}

- (BOOL)isIndex; { return [[self name] rangeOfString:@"Index"].location != NSNotFound; }

- (NSString *)CSSClassName
{
	// TODO: If nothing is specified, try to assemble a good guess from the plugin properties
	return [self pluginPropertyForKey:@"KTCSSClassName"];
}

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
