//
//  SVPlugInGraphicFactory.m
//  Sandvox
//
//  Created by Mike on 15/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPlugInGraphicFactory.h"

#import "KTDataSourceProtocol.h"
#import "KTElementPlugInWrapper.h"
#import "SVPlugInGraphic.h"

#import "NSImage+Karelia.h"


@implementation SVPlugInGraphicFactory

- (id)initWithBundle:(NSBundle *)bundle;
{
    [self init];
    _bundle = [bundle retain];
    return self;
}

- (void)dealloc;
{
    [_bundle release];
    [_class release];
    [_icon release];
	[_pageIcon release];

    [super dealloc];
}

#pragma mark Properties

- (NSArray *)identifiers;
{
    NSBundle *bundle = [self plugInBundle];
    
    // As per Dan's wishes, favour the older, existing ID for maximum compatibility. This should mean sites keep working from 2.1.4 up to whenever the doc format actually changes
    NSArray *result = [bundle objectForInfoDictionaryKey:@"SVAlternateIdentifiers"];
    result = (result ? [result arrayByAddingObject:[bundle bundleIdentifier]] : [NSArray arrayWithObject:[bundle bundleIdentifier]]);
    
    return result;
}

- (Class)plugInClass;
{
    if (!_class)
    {
        _class = [[[self plugInBundle] principalClass] retain];
    }
    return _class;
}

@synthesize plugInBundle = _bundle;

- (NSString *)name;
{
    NSString *result = [[self plugInBundle] objectForInfoDictionaryKey:@"KTPluginName"];
    if (!result) result = [[self plugInBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!result) result = [[self plugInBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
    return result;
}

// The "rule" on the SVPlugInDescription is that it should be presented as a verb that you, the website creator, do by having this in your website.
- (NSString *)graphicDescription; { return [[self plugInBundle] objectForInfoDictionaryKey:@"SVPlugInDescription"]; }

- (NSImage *)newIconWithName:(NSString *)name;
{
	NSImage *result = nil;
	// It could be a relative (to the bundle) or absolute path
	NSString *path = nil;
	if ([name isAbsolutePath])
	{
		path = name;
	}
	else
	{
		path = [[self plugInBundle] pathForImageResource:name];
		if (!path)
		{
			path = [[NSBundle mainBundle] pathForImageResource:name];
		}
	}
    
    
    // TODO: We should not be referencing absolute paths.  Instead, we should check for 'XXXX' pattern and convert that to an OSType.
	
	//	Create the icon, falling back to the broken image if necessary
	/// BUGSID:34635	Used to use -initByReferencingFile: but seems to upset Tiger and the Pages/Pagelets popups
	result = [[NSImage alloc] initWithContentsOfFile:path];
	
	
	return result;
}

- (NSImage *)icon;
{
	// The icon is cached; load it if not cached yet
	if (!_icon)
	{
		_icon = [self newIconWithName:
                  [[self plugInBundle] objectForInfoDictionaryKey:@"SVPlugInIconPath"]];
        if (!_icon) _icon = [[NSImage brokenImage] retain];
	}
	return _icon;
}

#pragma mark Factory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [SVPlugInGraphic
                         insertNewGraphicWithPlugInIdentifier:[[self identifiers] objectAtIndex:0]
                         inManagedObjectContext:context];
    
    // Guess title
    [result setTitle:[self name]];
    
    return result;
}

- (NSArray *)readablePasteboardTypes;
{
    NSArray *result = [KSWebLocation readableTypesForPasteboard:nil];
    return result;
}

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;
{
    SVPlugInPasteboardReadingOptions result = SVPlugInPasteboardReadingAsWebLocation;
    return result;
}

- (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSUInteger result = [super priorityForPasteboardItem:item];
    
    @try
    {
        result = [[self plugInClass] priorityForPasteboardItem:item];
    }
    @catch (NSException *exception)
    {
        // TODO: log
    }
    
    return result;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [self plugInClass]];
}

@end
