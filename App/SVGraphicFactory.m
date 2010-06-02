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
#import "SVTextBox.h"
#import "KTToolbars.h"

#import "KSWebLocation.h"

#import "NSArray+Karelia.h"
#import "NSSet+Karelia.h"

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

- (NSString *)name { return TOOLBAR_INSERT_TEXT_BOX; }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"TB_Text_Tool.tiff"];
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

- (NSString *)name { return @"Photo"; }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"photopage.icns"];
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


@interface SVMovieFactory : SVGraphicFactory
@end


@implementation SVMovieFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMovie *result = [SVMovie insertNewMovieInManagedObjectContext:context];
    [result setWidth:[NSNumber numberWithUnsignedInt:200]];
    [result setHeight:[NSNumber numberWithUnsignedInt:200]];
    
    return result;
}

- (NSString *)name { return @"Movie"; }

- (NSImage *)pluginIcon
{
    return [NSImage imageNamed:@"Video.icns"];
}

@end


#pragma mark -


@implementation SVGraphicFactory

#pragma mark Shared Objects

static NSArray *sPageletFactories;
static NSArray *sIndexFactories;
static id <SVGraphicFactory> sSharedTextBoxFactory;

+ (void)initialize
{
    if (!sSharedTextBoxFactory)
    {
        sSharedTextBoxFactory = [[SVTextBoxFactory alloc] init];
    }
    
    
    if (!sPageletFactories)
    {
        // Order plug-ins first by priority, then by name
        NSSet *factories = [KTElementPlugInWrapper pageletPlugins];
        factories = [factories setByAddingObject:[[[SVImageFactory alloc] init] autorelease]];
        factories = [factories setByAddingObject:[[[SVMovieFactory alloc] init] autorelease]];
        
        NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
                                                                     ascending:YES];
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                      initWithKey:@"name"
                                      ascending:YES
                                      selector:@selector(caseInsensitiveCompare:)];
        
        NSArray *sortDescriptors = [NSArray arrayWithObjects:prioritySort, nameSort, nil];
        [prioritySort release];
        [nameSort release];
        
        sPageletFactories = [[factories KS_sortedArrayUsingDescriptors:sortDescriptors] copy];
    }
    
    
    if (!sIndexFactories)
    {
        // Order plug-ins first by priority, then by name
        NSSet *plugins = [KTElementPlugInWrapper pageletPlugins];
        NSMutableSet *factories = [plugins mutableCopy];
        for (id <SVGraphicFactory> aFactory in plugins)
        {
            if (![aFactory isIndex])
            {
                [factories removeObject:aFactory];
            }
        }
        
        NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
                                                                     ascending:YES];
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                      initWithKey:@"name"
                                      ascending:YES
                                      selector:@selector(caseInsensitiveCompare:)];
        
        NSArray *sortDescriptors = [NSArray arrayWithObjects:prioritySort, nameSort, nil];
        [prioritySort release];
        [nameSort release];
        
        sIndexFactories = [[factories KS_sortedArrayUsingDescriptors:sortDescriptors] copy];
        [factories release];
    }
}

+ (NSArray *)pageletFactories; { return sPageletFactories; }
+ (NSArray *)indexFactories; { return sIndexFactories; }
+ (id <SVGraphicFactory>)textBoxFactory; { return sSharedTextBoxFactory; }

#pragma mark Menu

// nil targeted actions will be sent to firstResponder (the active document)
// representedObject is the factory
+ (void)insertItemsWithGraphicFactories:(NSArray *)factories
                                 inMenu:(NSMenu *)menu
                                atIndex:(NSUInteger)index;
{	
    for (id <SVGraphicFactory> factory in factories)
	{
		NSMenuItem *menuItem = [[[NSMenuItem alloc] init] autorelease];
		
        
        // Name
		NSString *pluginName = [factory name];
		if (![pluginName length])
		{
			NSLog(@"empty plugin name for %@", factory);
			pluginName = @"";
		}
		[menuItem setTitle:pluginName];
        
        
		// Icon
        NSImage *image = [[factory pluginIcon] copy];
#ifdef DEBUG
        if (!image) NSLog(@"nil pluginIcon for %@", pluginName);
#endif
        
        [image setSize:NSMakeSize(32.0f, 32.0f)];
        [menuItem setImage:image];
        [image release];
        
        
        // Pro status
        if (9 == [factory priority] && nil == gRegistrationString)
        {
            [menuItem setPro:YES];
        }
		
        
		
		[menuItem setRepresentedObject:factory];
        
		
		// set target/action
		[menuItem setAction:@selector(insertPagelet:)];
		
		[menu insertItem:menuItem atIndex:index];   index++;
	}
}

+ (SVGraphic *)graphicWithActionSender:(id)sender
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result;
    if ([sender respondsToSelector:@selector(representedObject)] && [sender representedObject])
    {
        id <SVGraphicFactory> factory = [sender representedObject];
        result = [factory insertNewGraphicInManagedObjectContext:context];
    }
    else
    {
        result = [[self textBoxFactory] insertNewGraphicInManagedObjectContext:context];
        OBASSERT(result);
    }
    
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

+ (SVGraphic *)graphicFromPasteboard:(NSPasteboard *)pasteboard
      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    id <SVGraphicFactory> factory = nil;
    id pasteboardContents;
    NSString *pasteboardType;
    NSUInteger readingPriority = 0;
    
    
    for (id <SVGraphicFactory> aFactory in [self pageletFactories])
    {
        NSArray *types = [aFactory readablePasteboardTypes];
        NSString *type = [pasteboard availableTypeFromArray:types];
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
                    propertyList = [[KSWebLocation webLocationsFromPasteboard:pasteboard] firstObjectKS];
                }
                else
                {
                    propertyList = [pasteboard dataForType:type];
                }
                
                
                if (propertyList)
                {
                    NSUInteger priority = [aFactory readingPriorityForPasteboardContents:propertyList
                                                                                 ofType:type];
                    if (priority > readingPriority)
                    {
                        factory = aFactory;
                        pasteboardContents = propertyList;
                        pasteboardType = type;
                        readingPriority = priority;
                    }
                }
            }
            @catch (NSException *exception)
            {
                // TODO: Log warning
            }
        }
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
        
        for (id <SVGraphicFactory> aFactory in [self pageletFactories])
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
