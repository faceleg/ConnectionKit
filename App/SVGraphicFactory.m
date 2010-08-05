//
//  SVGraphicFactory.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicFactory.h"

#import "KTElementPlugInWrapper.h"
#import "SVImage.h"
#import "SVMediaRecord.h"
#import "SVMovie.h"
#import "SVPlugIn.h"
#import "SVRawHTMLGraphic.h"
#import "SVTextBox.h"
#import "KTToolbars.h"

#import "KSSortedMutableArray.h"
#import "KSWebLocation.h"

#import "NSArray+Karelia.h"
#import "NSMenuItem+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSImage+Karelia.h"

#import "Registration.h"


@interface SVTextBoxFactory : SVGraphicFactory
@end


@implementation SVTextBoxFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    OBPRECONDITION(context);
	
	
    // Create the pagelet
	SVTextBox *result = [NSEntityDescription insertNewObjectForEntityForName:@"TextBox"
													  inManagedObjectContext:context];
	OBASSERT(result);
    
    
    // Give title & text
    [result setTitle:NSLocalizedString(@"Untitled Text", "Text Box title")];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"loremipsum2" ofType:@"html"];
    [[result body] setString:[NSString stringWithContentsOfFile:path
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL]];
	
    
	return result;
}

- (NSString *)name { return TOOLBAR_INSERT_TEXT_BOX; }	// from a localized string macro

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"toolbar_text"];
}

- (NSUInteger)priority; { return 1; }

@end


#pragma mark -


@interface SVImageFactory : SVGraphicFactory
@end


@implementation SVImageFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVImage *result = [SVImage insertNewImageInManagedObjectContext:context];
    [result setTitle:NSLocalizedString(@"Photo", "pagelet title")];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Photo", @"name of object to insert"); }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"toolbar_image"];
}

- (NSUInteger)priority; { return 1; }

- (NSArray *)readablePasteboardTypes;
{
    NSArray *result = [KSWebLocation webLocationPasteboardTypes];
    result = [result arrayByAddingObjectsFromArray:[NSImage imagePasteboardTypes]];
    return result;
}

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;
{
    SVPlugInPasteboardReadingOptions result = SVPlugInPasteboardReadingAsData;
    
    if ([[KSWebLocation webLocationPasteboardTypes] containsObject:type])
    {
        result = SVPlugInPasteboardReadingAsWebLocation;
    }
    
    return result;
}

- (SVGraphic *)graphicWithPasteboardContents:(id)contents
                                      ofType:(NSString *)type
              insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    if ([[KSWebLocation webLocationPasteboardTypes] containsObject:type])
    {
        SVMediaRecord *media = [SVMediaRecord mediaWithURL:[contents URL]
                                                entityName:@"GraphicMedia"
                            insertIntoManagedObjectContext:context
                                                     error:NULL];
        
        if (media)
        {
            SVImage *result = [SVImage insertNewImageWithMedia:media];
            return result;
        }
    }
    else if ([[NSImage imagePasteboardTypes] containsObject:type])
    {
        SVMediaRecord *media = [SVMediaRecord mediaWithFileContents:contents
                                                        URLResponse:nil
                                                         entityName:@"GraphicMedia"
                                     insertIntoManagedObjectContext:context];
        
        if (media)
        {
            SVImage *result = [SVImage insertNewImageWithMedia:media];
            return result;
        }
    }
    
    return nil;
}

@end


#pragma mark -


@interface SVVideoFactory : SVGraphicFactory
@end


@implementation SVVideoFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMovie *result = [SVMovie insertNewMovieInManagedObjectContext:context];
    [result setWidth:[NSNumber numberWithUnsignedInt:200]];
    [result setHeight:[NSNumber numberWithUnsignedInt:200]];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Video", @"name of object to insert"); }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"toolbar_video"];
}

@end


#pragma mark -


@interface SVAudioFactory : SVGraphicFactory
@end


@implementation SVAudioFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMovie *result = [SVMovie insertNewMovieInManagedObjectContext:context];			// SHOULD BE SVAUDIO
    [result setWidth:[NSNumber numberWithUnsignedInt:200]];
    [result setHeight:[NSNumber numberWithUnsignedInt:200]];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Audio", @"name of object to insert"); }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"toolbar_audio"];
}

@end


#pragma mark -


@interface SVRawHTMLFactory : SVGraphicFactory
@end


@implementation SVRawHTMLFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVRawHTMLGraphic *result = [NSEntityDescription insertNewObjectForEntityForName:@"RawHTMLGraphic" inManagedObjectContext:context];
    
    [result setHTMLString:@"<span>[[RAW HTML]]</span>"];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Raw HTML", @"name of object to insert"); }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"toolbar_html_element"];
}

@end


#pragma mark -


@implementation SVGraphicFactory

#pragma mark Factory Registration

static NSPointerArray   *sFactories;

+ (NSArray *)registeredFactories;
{
    return [sFactories allObjects];
}

+ (id <SVGraphicFactory>)graphicFactoryForTag:(NSInteger)tag;
{
    return [sFactories pointerAtIndex:tag];
}

+ (NSInteger)tagForFactory:(id <SVGraphicFactory>)factory;
{
    // Have to hunt through for index/tag of factory
    NSInteger result = 0;
    for (id <SVGraphicFactory> aFactory in sFactories)
    {
        if (aFactory == factory) break;
        result++;
    }
    
    // This would happen if factory wasn't found
    if (result >= [sFactories count]) result = 0;
    
    return result;
}

+ (void)registerFactory:(id <SVGraphicFactory>)factory;
{
    OBPRECONDITION(factory);
    [sFactories addPointer:factory];
}

#pragma mark Shared Objects

static id <SVGraphicFactory> sSharedTextBoxFactory;
static id <SVGraphicFactory> sImageFactory;
static id <SVGraphicFactory> sVideoFactory;
static id <SVGraphicFactory> sAudioFactory;
static KSSortedMutableArray *sIndexFactories;
static KSSortedMutableArray *sBadgeFactories;
static KSSortedMutableArray *sEmbeddedFactories;
static KSSortedMutableArray *sSocialFactories;
static KSSortedMutableArray *sMoreFactories;
static id <SVGraphicFactory> sRawHTMLFactory;

+ (void)initialize
{
    if (!sFactories) sFactories = [[NSPointerArray pointerArrayWithStrongObjects] retain];
    
    
    // Special factories!
    if (!sSharedTextBoxFactory)
    {
        sSharedTextBoxFactory = [[SVTextBoxFactory alloc] init];
        [self registerFactory:sSharedTextBoxFactory];
    }
    
    if (!sImageFactory)
    {
        sImageFactory = [[SVImageFactory alloc] init];
        [self registerFactory:sImageFactory];
    }
    
    if (!sVideoFactory)
    {
        sVideoFactory = [[SVVideoFactory alloc] init];
        [self registerFactory:sVideoFactory];
    }
	if (!sAudioFactory)
    {
        sAudioFactory = [[SVAudioFactory alloc] init];
        [self registerFactory:sAudioFactory];
    }
	
    if (!sRawHTMLFactory)
    {
        sRawHTMLFactory = [[SVRawHTMLFactory alloc] init];
        [self registerFactory:sRawHTMLFactory];
    }
    
    
    
    // Create standard groups of factories
    if (!sIndexFactories &&
        !sBadgeFactories &&
        !sEmbeddedFactories &&
        !sSocialFactories &&
        !sMoreFactories)
    {
        // Order plug-ins first by priority, then by name
        NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
                                                                     ascending:YES];
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                      initWithKey:@"name"
                                      ascending:YES
                                      selector:@selector(caseInsensitiveCompare:)];
        
        NSArray *sortDescriptors = [NSArray arrayWithObjects:prioritySort, nameSort, nil];
        [prioritySort release];
        [nameSort release];
        
        
        // Iterate the pagelets filing them away
        sIndexFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sBadgeFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sEmbeddedFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sSocialFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sMoreFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        
        
        for (KTHTMLPlugInWrapper *aFactory in [KTElementPlugInWrapper pageletPlugins])
        {
            switch ([aFactory category])
            {
                case KTPluginCategoryIndex:
                    [sIndexFactories addObject:aFactory];
                    break;
                /*case KTPluginCategoryBadge:
                    [sBadgeFactories addObject:aFactory];
                    break;
                case KTPluginCategoryEmbedded:
                    [sEmbeddedFactories addObject:aFactory];
                    break;
                case KTPluginCategorySocial:
                    [sSocialFactories addObject:aFactory];
                    break;*/
                default:
                    [sMoreFactories addObject:aFactory];
                    break;
            }
            
            [self registerFactory:aFactory];
        }
    }
}

+ (NSArray *)indexFactories; { return [[sIndexFactories copy] autorelease]; }
+ (NSArray *)badgeFactories; { return [[sBadgeFactories copy] autorelease]; }
+ (NSArray *)embeddedFactories; { return [[sEmbeddedFactories copy] autorelease]; }
+ (NSArray *)socialFactories; { return [[sSocialFactories copy] autorelease]; }
+ (NSArray *)moreGraphicFactories; { return [[sMoreFactories copy] autorelease]; }

+ (id <SVGraphicFactory>)textBoxFactory; { return sSharedTextBoxFactory; }
+ (id <SVGraphicFactory>)imageFactory; { return sImageFactory; }
+ (id <SVGraphicFactory>)videoFactory; { return sVideoFactory; }
+ (id <SVGraphicFactory>)audioFactory; { return sAudioFactory; }
+ (id <SVGraphicFactory>)rawHTMLFactory; { return sRawHTMLFactory; }

#pragma mark Menu

// nil targeted actions will be sent to firstResponder (the active document)
// representedObject is the factory
+ (void)insertItemsWithGraphicFactories:(NSArray *)factories
                                 inMenu:(NSMenu *)menu
                                atIndex:(NSUInteger)index;
{	
    for (id <SVGraphicFactory> factory in factories)
	{
		NSMenuItem *menuItem = [self menuItemWithGraphicFactory:factory];
		[menu insertItem:menuItem atIndex:index];   index++;
	}
}

+ (NSMenuItem *)menuItemWithGraphicFactory:(id <SVGraphicFactory>)factory;
{
    NSMenuItem *result = [[[NSMenuItem alloc] init] autorelease];
    
    
    // Tag
    [result setTag:[self tagForFactory:factory]];
    
    
    // Name
    NSString *pluginName = [factory name];
    if (![pluginName length])
    {
        NSLog(@"empty plugin name for %@", factory);
        pluginName = @"";
    }
    [result setTitle:pluginName];
    
    
    // Icon
    NSImage *image = [[factory pluginIcon] copy];
#ifdef DEBUG
    if (!image) NSLog(@"nil pluginIcon for %@", pluginName);
#endif
    
    [image setSize:NSMakeSize(32.0f, 32.0f)];
    [result setImage:image];
    [image release];
    
    
    // Pro status
    if (9 == [factory priority] && nil == gRegistrationString)
    {
        [result setPro:YES];
    }
    
    
    
    [result setRepresentedObject:factory];
    
    
    // set target/action
    [result setAction:@selector(insertPagelet:)];
    
    
    return result;
}

+ (SVGraphic *)graphicWithActionSender:(id <NSValidatedUserInterfaceItem>)sender
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    id <SVGraphicFactory> factory = [self graphicFactoryForTag:[sender tag]];
    SVGraphic *result = [factory insertNewGraphicInManagedObjectContext:context];
    
    [result setShowsTitle:YES]; // default is NO in the mom to account for inline images
    return result;
}

#pragma mark Pasteboard

+ (NSArray *)graphicsFomPasteboard:(NSPasteboard *)pasteboard
    insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *graphic = [self graphicFromPasteboard:pasteboard
                      insertIntoManagedObjectContext:context];
    
    NSArray *result = (graphic) ? [NSArray arrayWithObject:graphic] : nil;
    return result;
}

+ (NSUInteger)priorityForFactory:(id <SVGraphicFactory>)aFactory
                      pasteboard:(NSPasteboard *)pasteboard
                            type:(NSString **)outType
                        contents:(id *)outPboardContents;
{
    NSUInteger result = 0;
    
    
    NSString *type = [pasteboard availableTypeFromArray:[aFactory readablePasteboardTypes]];
    if (type)
    {
        @try    // talking to a plug-in so might fail
        {
            // What should I read off the pasteboard?
            id propertyList;
            SVPlugInPasteboardReadingOptions readingOptions = SVPlugInPasteboardReadingAsData;
            if ([aFactory respondsToSelector:@selector(readingOptionsForType:pasteboard:)])
            {
                readingOptions = [aFactory readingOptionsForType:type pasteboard:pasteboard];
            }
            
            if (readingOptions & SVPlugInPasteboardReadingAsPropertyList)
            {
                propertyList = [pasteboard propertyListForType:type];
            }
            else if (readingOptions & SVPlugInPasteboardReadingAsString)
            {
                propertyList = [pasteboard stringForType:type];
            }
            else if (readingOptions & SVPlugInPasteboardReadingAsWebLocation)
            {
                propertyList = [[pasteboard readWebLocations] firstObjectKS];
            }
            else
            {
                propertyList = [pasteboard dataForType:type];
            }
            
            
            if (propertyList)
            {
                result = [aFactory readingPriorityForPasteboardContents:propertyList
                                                                 ofType:type];
                
                if (result)
                {
                    // Pass back out results
                    if (outType) *outType = type;
                    if (outPboardContents) *outPboardContents = propertyList;
                }
            }
        }
        @catch (NSException *exception)
        {
            // TODO: Log warning
        }
    }
    
    
    return result;
}

+ (SVGraphic *)graphicFromPasteboard:(NSPasteboard *)pasteboard
      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    id <SVGraphicFactory> factory = nil;
    id pasteboardContents;
    NSString *pasteboardType;
    NSUInteger readingPriority = 0;
    
    
    // Test plug-ins
    for (id <SVGraphicFactory> aFactory in [self registeredFactories])
    {
        NSString *type;
        id propertyList;
        NSUInteger priority = [self priorityForFactory:aFactory
                                            pasteboard:pasteboard
                                                  type:&type
                                              contents:&propertyList];
        
        if (priority > readingPriority)
        {
            factory = aFactory;
            pasteboardContents = propertyList;
            pasteboardType = type;
            readingPriority = priority;
        }
    }
    
    
    
    // Test image
    NSString *type;
    id propertyList;
    NSUInteger priority = [self priorityForFactory:[self imageFactory]
                                        pasteboard:pasteboard
                                              type:&type
                                          contents:&propertyList];
    
    if (priority > readingPriority)
    {
        factory = [self imageFactory];
        pasteboardContents = propertyList;
        pasteboardType = type;
        readingPriority = priority;
    }
    
    
    
    
    
    // Try to create plug-in from pasteboard contents
    if (factory)
    {        
        SVGraphic *result = [factory graphicWithPasteboardContents:pasteboardContents
                                                            ofType:pasteboardType
                                    insertIntoManagedObjectContext:context];
        
        return result;
    }
    
    
    
    return nil;
}

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSArray *)graphicPasteboardTypes;
{
    static NSMutableArray *result;
	
    if (!result)
    {
        result = [[NSMutableArray alloc] init];
        
        for (id <SVGraphicFactory> aFactory in [self registeredFactories])
        {
            NSArray *acceptedTypes = [aFactory readablePasteboardTypes];
            for (NSString *aType in acceptedTypes)
            {
                if (![result containsObject:aType]) [result addObject:aType];
            }
        }
	}
    
    return result;
}

#pragma mark SVGraphicFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    return nil;
}

- (NSString *)name { return nil; }
- (NSImage *)pluginIcon { return nil; }
- (NSUInteger)priority; { return 5; }

- (BOOL)isIndex; { return NO; }

- (NSArray *)readablePasteboardTypes; { return nil; }

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;
{
    return 0;
}

- (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type;
{ return 5; }

- (SVGraphic *)graphicWithPasteboardContents:(id)contents
                                      ofType:(NSString *)type
              insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    return nil;
}

@end
