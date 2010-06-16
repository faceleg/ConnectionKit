//
//  SVGraphicFactory.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Like NSFontManager, but for pagelets. (In the sense of the contents of "Insert > Pagelet >" menu)


#import <Cocoa/Cocoa.h>
#import "SVGraphic.h"

#import "SVPlugIn.h"


@protocol SVGraphicFactory <NSObject>

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;

- (NSString *)name;
- (NSImage *)pluginIcon;
- (NSUInteger)priority; // 0-9, where 9 is Pro status

- (BOOL)isIndex;


#pragma mark Pasteboard

- (NSArray *)readablePasteboardTypes;

- (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type
                                               pasteboard:(NSPasteboard *)pasteboard;

- (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type;

- (SVGraphic *)graphicWithPasteboardContents:(id)contents
                                      ofType:(NSString *)type
              insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


@end


#pragma mark -


@interface SVGraphicFactory : NSObject <SVGraphicFactory>

#pragma mark Shared Objects
+ (NSArray *)pageletFactories;  // objects conform to
+ (NSArray *)indexFactories;    // SVGraphicFactory protocol
+ (id <SVGraphicFactory>)textBoxFactory;


#pragma mark Menus

+ (void)insertItemsWithGraphicFactories:(NSArray *)factories
                                 inMenu:(NSMenu *)menu
                                atIndex:(NSUInteger)index;

+ (NSMenuItem *)menuItemWithGraphicFactory:(id <SVGraphicFactory>)factory;

// Convenience method that uses the factory if non-nil. Otherwise, fall back to text box
+ (SVGraphic *)graphicWithActionSender:(id)sender
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Pasteboard

+ (NSArray *)graphicsFomPasteboard:(NSPasteboard *)pasteboard
    insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

// Looks at just first item on pboard
+ (SVGraphic *)graphicFromPasteboard:(NSPasteboard *)pasteboard
      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)graphicPasteboardTypes;


@end
