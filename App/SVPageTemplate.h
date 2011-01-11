//
//  SVPageTemplate.h
//  Sandvox
//
//  Created by Mike on 28/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVGraphicFactory;


@interface SVPageTemplate : NSObject <NSCoding>
{
  @private
    NSString            *_identifier;
    NSString            *_title;
    NSString            *_subtitle;
    NSImage             *_icon;
    NSDictionary        *_properties;
    SVGraphicFactory    *_graphicFactory;
}

+ (NSArray *)pageTemplates;

- (id)initWithCollectionPreset:(NSDictionary *)presetDict;
- (id)initWithGraphicFactory:(SVGraphicFactory *)factory;

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title; // title of template, not created pages
@property(nonatomic, copy) NSString *subtitle; // additional information about the menu
@property(nonatomic, retain) NSImage *icon;
@property(nonatomic, copy) NSDictionary *pageProperties;

// When inserting a page using this template, you should generally stick a graphic on it produced using this factory
@property(nonatomic, retain, readonly) SVGraphicFactory *graphicFactory;

- (NSMenuItem *)makeMenuItemWithIcon:(BOOL)includeIcon;
+ (void)populateMenu:(NSMenu *)menu withPageTemplates:(NSArray *)templates index:(NSUInteger)index includeIcons:(BOOL)include;

@end
