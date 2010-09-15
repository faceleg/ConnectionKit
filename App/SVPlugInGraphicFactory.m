//
//  SVPlugInGraphicFactory.m
//  Sandvox
//
//  Created by Mike on 15/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
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
    
    [super dealloc];
}

#pragma mark Properties

- (NSString *)plugInIdentifier; { return [[self plugInBundle] bundleIdentifier]; }

- (Class)plugInClass;
{
    if (!_class)
    {
        _class = [[[self plugInBundle] principalClass] retain];
    }
    return _class;
}

@synthesize plugInBundle = _bundle;

- (NSString *)name; { return [[self plugInBundle] objectForInfoDictionaryKey:@"KTPluginName"]; }

- (NSImage *)icon;
{
	// The icon is cached; load it if not cached yet
	if (!_icon)
	{
		// It could be a relative (to the bundle) or absolute path
		NSString *filename = [[self plugInBundle] objectForInfoDictionaryKey:@"KTPluginIconName"];
		if (![filename isAbsolutePath])
		{
			filename = [[self plugInBundle] pathForImageResource:filename];
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

#pragma mark Factory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [SVPlugInGraphic
                         insertNewGraphicWithPlugInIdentifier:[self plugInIdentifier]
                         inManagedObjectContext:context];
    
    // Guess title
    [result setTitle:[self name]];
    
    return result;
}

- (NSArray *)readablePasteboardTypes;
{
    NSArray *result = nil;
    
    Class anElementClass = [self plugInClass];
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

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;
{
    SVPlugInPasteboardReadingOptions result = SVPlugInPasteboardReadingAsData;
    
    @try
    {
        Class plugInClass = [self plugInClass];
        if ([plugInClass respondsToSelector:_cmd])
        {
            result = [plugInClass readingOptionsForType:type
                                             pasteboard:pasteboard];
        }
    }
    @catch (NSException *exception)
    {
        // TODO: log
    }
    
    return result;
}

- (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type;
{
    NSUInteger result = KTSourcePriorityNone;
    
    @try
    {
        result = [[self plugInClass] readingPriorityForPasteboardContents:contents
                                                                               ofType:type];
    }
    @catch (NSException *exception)
    {
        // TODO: log
    }
    
    return result;
}

- (SVGraphic *)graphicWithPasteboardContents:(id)contents
                                      ofType:(NSString *)type
              insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPlugInGraphic *result = nil;
    
    Class plugInClass = [self plugInClass];
    if ([plugInClass conformsToProtocol:@protocol(SVPlugInPasteboardReading)])
    {
        result = (id)[self insertNewGraphicInManagedObjectContext:context];
        [(id <SVPlugInPasteboardReading>)[result plugIn] awakeFromPasteboardContents:contents
                                                                              ofType:type];
    }
    
    return result;
}

@end
