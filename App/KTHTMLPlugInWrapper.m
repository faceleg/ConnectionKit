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
