//
//  SVPageTemplate.h
//  Sandvox
//
//  Created by Mike on 28/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVGraphicFactory;


@interface SVPageTemplate : NSObject
{
  @private
    NSString            *_title;
    NSImage             *_icon;
    NSDictionary        *_collectionPreset;
    SVGraphicFactory    *_graphicFactory;
}

+ (NSArray *)pageTemplates;

- (id)initWithCollectionPreset:(NSDictionary *)presetDict;
- (id)initWithGraphicFactory:(SVGraphicFactory *)factory;

@property(nonatomic, copy) NSString *title; // title of template, not created pages
@property(nonatomic, retain) NSImage *icon;
@property(nonatomic, copy) NSDictionary *collectionPreset;

// When inserting a page using this template, you should generally stick a graphic on it produced using this factory
@property(nonatomic, retain, readonly) SVGraphicFactory *graphicFactory;

- (NSMenuItem *)makeMenuItem;
+ (void)populateMenu:(NSMenu *)menu withPageTemplates:(NSArray *)templates index:(NSUInteger)index;

@end
