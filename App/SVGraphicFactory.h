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


@interface SVGraphicFactory : NSObject

#pragma mark Shared Objects
+ (SVGraphicFactory *)textBoxFactory;
+ (NSArray *)mediaFactories;
+ (SVGraphicFactory *)imageFactory;
+ (SVGraphicFactory *)videoFactory;
+ (SVGraphicFactory *)audioFactory;
+ (SVGraphicFactory *)flashFactory;
+ (NSArray *)indexFactories;
+ (NSArray *)badgeFactories;
+ (NSArray *)embeddedFactories;
+ (NSArray *)socialFactories;
+ (NSArray *)moreGraphicFactories;
+ (SVGraphicFactory *)rawHTMLFactory;


#pragma mark General

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;

- (NSString *)name;
- (NSImage *)icon;
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


#pragma mark Menus

+ (void)insertItemsWithGraphicFactories:(NSArray *)factories
                                 inMenu:(NSMenu *)menu
                                atIndex:(NSUInteger)index;

- (NSMenuItem *)makeMenuItem;
+ (NSMenuItem *)menuItemWithGraphicFactories:(NSArray *)factories title:(NSString *)title;

// Convenience method that uses the factory if non-nil. Otherwise, fall back to text box
+ (SVGraphic *)graphicWithActionSender:(id <NSValidatedUserInterfaceItem>)sender
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Pasteboard

+ (NSArray *)graphicsFomPasteboard:(NSPasteboard *)pasteboard
    insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

// Looks at just first item on pboard
+ (SVGraphic *)graphicFromPasteboard:(NSPasteboard *)pasteboard
      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)graphicPasteboardTypes;


@end
