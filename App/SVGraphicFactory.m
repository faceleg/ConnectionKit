//
//  SVGraphicFactory.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphicFactory.h"

#import "KTDataSourceProtocol.h"
#import "KTElementPlugInWrapper.h"
#import "SVImage.h"
#import "SVMediaRecord.h"
#import "SVVideo.h"
#import "SVAudio.h"
#import "SVFlash.h"
#import "SVMediaGraphic.h"
#import "SVPlugIn.h"
#import "SVRawHTMLGraphic.h"
#import "SVTextBox.h"
#import "KTToolbars.h"
#import "NSString+KTExtensions.h"

#import "KSSortedMutableArray.h"
#import "KSWebLocationPasteboardUtilities.h"

#import "NSArray+Karelia.h"
#import "NSMenuItem+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSImage+Karelia.h"

#import "KSURLUtilities.h"

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

- (NSString *)graphicDescription { return NSLocalizedString(@"Write text in a separate box", @"name of object to insert"); }

- (NSImage *)icon
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
    SVMediaGraphic *result = [SVMediaGraphic insertNewGraphicInManagedObjectContext:context];
    [result setTitle:NSLocalizedString(@"Photo", "pagelet title")];
    [result setIsMediaPlaceholder:[NSNumber numberWithBool:YES]];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Media Placeholder", @"name of object to insert"); }

- (NSString *)graphicDescription { return NSLocalizedString(@"Replace with your own image, movie, sound", @"name of object to insert"); }

- (NSImage *)icon
{
    return [NSImage imageNamed:@"toolbar_image"];
}

- (NSString *)identifier { return @"sandvox.ImageElement"; }

- (Class)plugInClass { return [SVImage class]; }

- (NSUInteger)priority; { return 1; }

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

- (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    // Try to figure type
    NSURL *URL = [item URL];
    NSString *type = nil;
    
    if ([URL isFileURL])
    {
        NSString *path = [[item URL] path];
        type = [[NSWorkspace sharedWorkspace] typeOfFile:path error:NULL];
        if (!type) type = [[NSWorkspace sharedWorkspace] ks_typeForFilenameExtension:[URL ks_pathExtension]];
        
        if (type)
        {
            if ([[NSWorkspace sharedWorkspace] ks_type:type conformsToOneOfTypes:[SVMediaGraphic allowedTypes]])
            {
                return SVPasteboardPriorityTypical;
            }
         }
    }
    
    return SVPasteboardPriorityNone;
}

@end


#pragma mark -


@interface SVVideoFactory : SVImageFactory
@end


@implementation SVVideoFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [super insertNewGraphicInManagedObjectContext:context];
    [result setWidth:[NSNumber numberWithInt:200]];
    [result setHeight:[NSNumber numberWithInt:150]];	// typical TV aspect ratio
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Video", @"name of object to insert"); }

- (NSImage *)icon
{
    return [NSImage imageNamed:@"toolbar_video"];
}

- (NSString *)identifier { return @"sandvox.VideoElement"; }

- (Class)plugInClass { return [SVVideo class]; }

@end


#pragma mark -


@interface SVAudioFactory : SVImageFactory
@end


@implementation SVAudioFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [super insertNewGraphicInManagedObjectContext:context];
    [result setWidth:[NSNumber numberWithInt:200]];
    [result setHeight:[NSNumber numberWithInt:25]];		// height of audio tag
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Audio", @"name of object to insert"); }

- (NSImage *)icon
{
    return [NSImage imageNamed:@"toolbar_audio"];
}

- (NSString *)identifier { return @"com.karelia.sandvox.SVAudio"; }

- (Class)plugInClass { return [SVAudio class]; }

@end


#pragma mark -

@interface SVFlashFactory : SVImageFactory
@end


@implementation SVFlashFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [super insertNewGraphicInManagedObjectContext:context];
    [result setWidth:[NSNumber numberWithInt:200]];
    [result setHeight:[NSNumber numberWithInt:200]];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Flash", @"name of object to insert"); }

- (NSImage *)icon
{
    return [NSImage imageNamed:@"toolbar_flash"];
}

- (NSString *)identifier { return @"com.karelia.sandvox.SVFlash"; }

- (Class)plugInClass { return [SVFlash class]; }

@end


#pragma mark -



@interface SVRawHTMLFactory : SVGraphicFactory
@end


@implementation SVRawHTMLFactory

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVRawHTMLGraphic *result = [NSEntityDescription insertNewObjectForEntityForName:@"RawHTMLGraphic" inManagedObjectContext:context];
    
    [result setHTMLString:@"<span>[[RAW HTML]]</span>"];
    [result makeOriginalSize];
    
    return result;
}

- (NSString *)name { return NSLocalizedString(@"Raw HTML", @"name of object to insert"); }

- (NSString *)graphicDescription { return NSLocalizedString(@"Paste or edit your own HTML code", @"name of object to insert"); }

- (NSImage *)icon
{
    return [NSImage imageNamed:@"toolbar_html_element"];
}

- (NSString *)identifier { return @"com.karelia.sandvox.RawHTML"; }

@end


#pragma mark -


@implementation SVGraphicFactory

#pragma mark Init 

static NSPointerArray       *sFactories;
static NSMutableDictionary  *sFactoriesByIdentifier;

static SVGraphicFactory *sSharedTextBoxFactory;
static SVGraphicFactory *sImageFactory;
static SVGraphicFactory *sVideoFactory;
static SVGraphicFactory *sAudioFactory;
static SVGraphicFactory *sFlashFactory;
static KSSortedMutableArray *sIndexFactories;
static KSSortedMutableArray *sBadgeFactories;
static KSSortedMutableArray *sEmbeddedFactories;
static KSSortedMutableArray *sSocialFactories;
static KSSortedMutableArray *sMoreFactories;
static SVGraphicFactory *sRawHTMLFactory;

+ (void)initialize
{
    if (!sFactories) sFactories = [[NSPointerArray pointerArrayWithStrongObjects] retain];
    if (!sFactoriesByIdentifier) sFactoriesByIdentifier = [[NSMutableDictionary alloc] init];
    
    
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
	if (!sFlashFactory)
    {
        sFlashFactory = [[SVFlashFactory alloc] init];
        [self registerFactory:sFlashFactory];
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
        //      I've turned off priority support for now to try a pure alphabetical approach - Mike
        //NSSortDescriptor *prioritySort = [[NSSortDescriptor alloc] initWithKey:@"priority"
        //                                                             ascending:YES];
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc]
                                      initWithKey:@"name"
                                      ascending:YES
                                      selector:@selector(caseInsensitiveCompare:)];
        
        NSArray *sortDescriptors = [NSArray arrayWithObjects:/*prioritySort, */nameSort, nil];
        //[prioritySort release];
        [nameSort release];
        
        
        // Iterate the pagelets filing them away
        sIndexFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sBadgeFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sEmbeddedFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sSocialFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        sMoreFactories = [[KSSortedMutableArray alloc] initWithSortDescriptors:sortDescriptors];
        
        
        for (KTElementPlugInWrapper *aWrapper in [KTElementPlugInWrapper pageletPlugins])
        {
            /*
            switch ([aWrapper category])
            {
                case KTPluginCategoryIndex:
                    [sIndexFactories addObject:[aWrapper graphicFactory]];
                    break;
                    case KTPluginCategoryBadge:
                     [sBadgeFactories addObject:[aWrapper graphicFactory]];
                     break;
                     case KTPluginCategoryEmbedded:
                     [sEmbeddedFactories addObject:[aWrapper graphicFactory]];
                     break;
                     case KTPluginCategorySocial:
                     [sSocialFactories addObject:[aWrapper graphicFactory]];
                     break;
                default:
                    [sMoreFactories addObject:[aWrapper graphicFactory]];
                    break;
            }
            */
            
            if ( [[aWrapper pluginPropertyForKey:@"SVPlugInIsIndex"] boolValue] )
            {
                [sIndexFactories addObject:[aWrapper graphicFactory]];
            }
            else
            {
                [sMoreFactories addObject:[aWrapper graphicFactory]];
            }
            
            [self registerFactory:[aWrapper graphicFactory]];
        }
    }
}

#pragma mark Factory Registration

+ (NSArray *)registeredFactories;
{
    return [sFactories allObjects];
}

+ (SVGraphicFactory *)factoryWithIdentifier:(NSString *)identifier;
{
    SVGraphicFactory *result = [sFactoriesByIdentifier objectForKey:identifier];
    return result;
}

+ (SVGraphicFactory *)graphicFactoryForTag:(NSInteger)tag;
{
    return [sFactories pointerAtIndex:tag];
}

+ (NSInteger)tagForFactory:(SVGraphicFactory *)factory;
{
    // Have to hunt through for index/tag of factory
    NSInteger result = 0;
    for (SVGraphicFactory *aFactory in sFactories)
    {
        if (aFactory == factory) break;
        result++;
    }
    
    // This would happen if factory wasn't found
    if (result >= [sFactories count]) result = 0;
    
    return result;
}

+ (void)registerFactory:(SVGraphicFactory *)factory;
{
    OBPRECONDITION(factory);
    [sFactories addPointer:factory];
    if ([factory identifier]) [sFactoriesByIdentifier setObject:factory forKey:[factory identifier]];
}

#pragma mark Shared Objects

+ (NSArray *)indexFactories; { return [[sIndexFactories copy] autorelease]; }
+ (NSArray *)badgeFactories; { return [[sBadgeFactories copy] autorelease]; }
+ (NSArray *)embeddedFactories; { return [[sEmbeddedFactories copy] autorelease]; }
+ (NSArray *)socialFactories; { return [[sSocialFactories copy] autorelease]; }
+ (NSArray *)moreGraphicFactories; { return [[sMoreFactories copy] autorelease]; }

+ (SVGraphicFactory *)textBoxFactory; { return sSharedTextBoxFactory; }

+ (SVGraphicFactory *)mediaPlaceholderFactory; { return sImageFactory; }
+ (SVGraphicFactory *)videoFactory; { return sVideoFactory; }
+ (SVGraphicFactory *)audioFactory; { return sAudioFactory; }
+ (SVGraphicFactory *)flashFactory; { return sFlashFactory; }

+ (NSArray *)mediaFactories;
{
    return [NSArray arrayWithObjects:
            [self mediaPlaceholderFactory],
            [self videoFactory],
            [self audioFactory],
            [self flashFactory], nil];
}

+ (SVGraphicFactory *)rawHTMLFactory; { return sRawHTMLFactory; }

#pragma mark Menu

// nil targeted actions will be sent to firstResponder (the active document)
// representedObject is the factory
+ (void)insertItemsWithGraphicFactories:(NSArray *)factories
                                 inMenu:(NSMenu *)menu
                                atIndex:(NSUInteger)index
						withDescription:(BOOL)aWantDescription;
{	
    for (SVGraphicFactory *factory in factories)
	{
		NSMenuItem *menuItem = [factory makeMenuItemWithDescription:aWantDescription];
		[menu insertItem:menuItem atIndex:index];   index++;
	}
}

- (NSMenuItem *)makeMenuItemWithDescription:(BOOL)aWantDescription;
{
    NSMenuItem *result = [[[NSMenuItem alloc] init] autorelease];
    
    
    // Tag
    [result setTag:[SVGraphicFactory tagForFactory:self]];
    
    
    // Name
    NSString *pluginName = [self name];
    if (![pluginName length])
    {
        NSLog(@"empty plugin name for %@", self);
        pluginName = @"";
    }

	if (aWantDescription)
	{
		NSAttributedString *attributedTitle = [NSAttributedString attributedMenuTitle:pluginName subtitle:[self graphicDescription]];
		[result setAttributedTitle:attributedTitle];
	}
	else
	{
		[result setTitle:pluginName];
	}
    
    // Icon
    //if (image)
    {
        NSImage *icon = [[self icon] copy];
#ifdef DEBUG
        if (!icon) NSLog(@"nil pluginIcon for %@", pluginName);
#endif
        
        [icon setSize:NSMakeSize(32.0f, 32.0f)];
        [result setImage:icon];
        [icon release];
    }

    [result setRepresentedObject:self];
    
    
    // set target/action
    [result setAction:@selector(insertPagelet:)];
    
    
    return result;
}

+ (NSMenuItem *)menuItemWithGraphicFactories:(NSArray *)factories
									   title:(NSString *)title
							 withDescription:(BOOL)aWantDescription;
{
    NSMenuItem *result = [[NSMenuItem alloc] initWithTitle:title
													action:nil
											 keyEquivalent:@""];
    
    NSMenu *submenu = [[NSMenu alloc] initWithTitle:title];
    
    [SVGraphicFactory insertItemsWithGraphicFactories:factories
                                               inMenu:submenu
                                              atIndex:0
									  withDescription:aWantDescription];
	[result setSubmenu:submenu];
    [submenu release];
    
    return [result autorelease];
}

+ (SVGraphic *)graphicWithActionSender:(id <NSValidatedUserInterfaceItem>)sender
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphicFactory *factory = [self graphicFactoryForTag:[sender tag]];
    SVGraphic *result = [factory insertNewGraphicInManagedObjectContext:context];
    
    [result setShowsTitle:YES]; // default is NO in the mom to account for inline images
    return result;
}

#pragma mark Pasteboard

- (SVGraphic *)graphicWithPasteboardItems:(NSArray *)items
           insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *result = [self insertNewGraphicInManagedObjectContext:context];
    [result makeOriginalSize];  // e.g. so Gists created by dragging are correct size
    [result awakeFromPasteboardItems:items];
    
    // Set title to match. #94380
    NSString *title = [[items lastObject] title];
    if (!title) title = [[[[items lastObject] URL] ks_lastPathComponent] stringByDeletingPathExtension];
    if (title) [result setTitle:title];
    
    return result;
}

+ (NSArray *)graphicsFromPasteboard:(NSPasteboard *)pboard
    insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    // Try to read in Web Locations
    NSArray *items = [pboard sv_pasteboardItems];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[items count]];
    
    SVGraphicFactory *factory = nil;
    NSArray *pendingItems = nil;
        
    for (id <SVPasteboardItem> anItem in items)
    {
        // Test plug-ins
        NSUInteger minPriority = 0;
        
        for (SVGraphicFactory *aFactory in [self registeredFactories])
        {
            NSUInteger priority = [aFactory priorityForPasteboardItem:anItem];
            if (priority > minPriority)
            {
                // Is this a different factory to the one set aside? If so, import items so far
                if ([pendingItems count] && factory && aFactory != factory)
                {
                    SVGraphic *graphic = [factory graphicWithPasteboardItems:pendingItems
                                              insertIntoManagedObjectContext:context];
                    
                    if (graphic) [result addObject:graphic];
                    pendingItems = nil;
                }
                
                factory = aFactory;
                minPriority = priority;
            }
        }
        
        
        // Create graphic, or wait until we have all the items?
        if ([[factory plugInClass] supportsMultiplePasteboardItems])
        {
            pendingItems = (pendingItems ?
                            [pendingItems arrayByAddingObject:anItem] :
                            [NSArray arrayWithObject:anItem]);
        }
        else
        {        
            SVGraphic *graphic = [factory graphicWithPasteboardItems:[NSArray arrayWithObject:anItem]
                                      insertIntoManagedObjectContext:context];
            
            if (graphic) [result addObject:graphic];
            factory = nil;
        }
    }
    
    
    // Should all items go into a single graphic?
    if (factory && pendingItems)
    {
        SVGraphic *graphic = [factory graphicWithPasteboardItems:pendingItems
                                  insertIntoManagedObjectContext:context];
        
        if (graphic) [result addObject:graphic];
    }
    
    
    return result;
}

+ (SVGraphic *)graphicFromPasteboardItem:(id <SVPasteboardItem>)pasteboardItem
                             minPriority:(NSUInteger)minPriority
          insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphicFactory *factory = nil;
    
    
    // Test plug-ins
    for (SVGraphicFactory *aFactory in [self registeredFactories])
    {
        NSUInteger priority = [aFactory priorityForPasteboardItem:pasteboardItem];
        if (priority > minPriority)
        {
            factory = aFactory;
            minPriority = priority;
        }
    }
    
    
    // Create graphic
    SVGraphic *result = nil;
    if (factory)
    {
        result = [factory graphicWithPasteboardItems:[NSArray arrayWithObject:pasteboardItem]
                     insertIntoManagedObjectContext:context];
    }
    
    return result;
}

- (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item; { return SVPasteboardPriorityNone; }

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSArray *)graphicPasteboardTypes;
{
    return [SVMediaGraphic allowedTypes];
}

#pragma mark SVGraphicFactory

- (id)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    return nil;
}

- (NSString *)name { SUBCLASSMUSTIMPLEMENT; return nil; }
- (NSString *)graphicDescription { SUBCLASSMUSTIMPLEMENT; return nil; }
- (NSImage *)icon { return nil; }
- (NSImage *)pageIcon { return nil; }
- (NSUInteger)priority; { return 5; }

- (BOOL)isIndex; { return NO; }

- (NSString *)identifier { return nil; }
- (Class)plugInClass; { return nil; }

#pragma mark Pasteboard

- (NSArray *)readablePasteboardTypes; { return nil; }

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;
{
    return 0;
}

- (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type;
{
    return SVPasteboardPriorityIdeal;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    return [self init];
    // TODO: Implement this properly if possible. At the moment it's only for the benefit of #103192
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:[self name] forKey:@"name"];
    [aCoder encodeObject:[self graphicDescription] forKey:@"graphicDescription"];
    [aCoder encodeObject:[self icon] forKey:@"icon"];
    [aCoder encodeObject:[self pageIcon] forKey:@"pageIcon"];
    [aCoder encodeInteger:[self priority] forKey:@"priority"];
    [aCoder encodeBool:[self isIndex] forKey:@"isIndex"];
    [aCoder encodeObject:[self identifier] forKey:@"identifier"];
    [aCoder encodeObject:NSStringFromClass([self class]) forKey:@"plugInClass"];
}

@end

