//
//  SVGraphicFactoryManager.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Like NSFontManager, but for pagelets. (In the sense of the contents of "Insert > Pagelet >" menu)


#import <Cocoa/Cocoa.h>


@class SVGraphic;

@protocol SVGraphicFactory <NSObject>

- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;

- (NSString *)name;
- (NSImage *)pluginIcon;
- (NSUInteger)priority; // 0-9, where 9 is Pro status

- (BOOL)isIndex;

@end


#pragma mark -


@interface SVGraphicFactoryManager : NSObject
{
  @private
    NSArray *_graphicFactories;
}

+ (SVGraphicFactoryManager *)sharedPageletManager;
+ (SVGraphicFactoryManager *)sharedIndexManager;

- (id)initWithGraphicFactories:(NSArray *)graphicFactories;

@property(nonatomic, copy, readonly) NSArray *graphicFactories;

- (void)populateMenu:(NSMenu *)menu atIndex:(NSUInteger)index;

@end
