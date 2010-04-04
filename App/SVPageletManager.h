//
//  SVPageletManager.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Like NSFontManager, but for pagelets. (In the sense of the contents of "Insert > Pagelet >" menu)


#import <Cocoa/Cocoa.h>


@class SVGraphic;

@protocol SVGraphicFactory
- (SVGraphic *)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
- (NSString *)name;
- (NSImage *)pluginIcon;
@end


#pragma mark -


@interface SVPageletManager : NSObject
{
    NSMutableArray  *_pageletClasses;
}

+ (SVPageletManager *)sharedPageletManager;

- (void)registerPageletClass:(Class)pageletClass
                        icon:(NSImage *)icon;

- (void)populateMenu:(NSMenu *)menu atIndex:(NSUInteger)index;

@end
