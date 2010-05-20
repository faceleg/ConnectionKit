//
//  KTHTMLPlugInWrapper.m
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTHTMLPlugInWrapper.h"

#import "SVPlugInGraphic.h"

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
	[_icon release];
	[_templateHTML release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

/*	Implemented for the sake of bindings
 */
- (NSString *)name { return [self pluginPropertyForKey:@"KTPluginName"]; }

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

- (NSString *)templateHTMLAsString
{
	if (!_templateHTML)
	{
		NSString *templateName = [self pluginPropertyForKey:@"KTTemplateName"];
		NSString *path = [[self bundle] overridingPathForResource:templateName ofType:@"html"];
		
		if (path)	// This actually used to use NSData and then NSString, but no-one recalls why!
		{
			_templateHTML = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
		}
		
		if (!_templateHTML)	// If the HTML can't be loaded, don't bother trying again
		{
			_templateHTML = [[NSNull null] retain];
		}
	}
	
	NSString *result = _templateHTML;
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

#pragma mark Factory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSString *identifier = [[self bundle] bundleIdentifier];
    
    SVGraphic *result = [SVPlugInGraphic insertNewGraphicWithPlugInIdentifier:identifier
                                                       inManagedObjectContext:context];
    
    // Guess title
    [result setTitle:[self name]];
    
    return result;
}

- (NSArray *)readablePasteboardTypes;
{
    NSArray *result = nil;
    
    Class anElementClass = [[self bundle] principalClass];
    if ([anElementClass conformsToProtocol:@protocol(SVPlugInPasteboardReading)])
    {
        @try
        {
            result = [anElementClass readableTypesForPasteboard:nil];
        }
        @catch (NSException *exception)
        {
            // TODO: log
        }
    }
    
    return result;
}

@end
