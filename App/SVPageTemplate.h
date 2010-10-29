//
//  SVPageTemplate.h
//  Sandvox
//
//  Created by Mike on 28/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVPageTemplate : NSObject
{
  @private
    NSString        *_title;
    NSImage         *_icon;
    NSDictionary    *_collectionPreset;
    NSString        *_graphicIdentifier;
}

+ (NSArray *)pageTemplates;

- (id)initWithCollectionPreset:(NSDictionary *)presetDict;

@property(nonatomic, copy) NSString *title;
@property(nonatomic, retain) NSImage *icon;
@property(nonatomic, copy) NSDictionary *collectionPreset;
@property(nonatomic, copy) NSString *graphicIdentifier;

- (NSMenuItem *)makeMenuItem;
+ (void)populateMenu:(NSMenu *)menu withPageTemplates:(NSArray *)templates index:(NSUInteger)index;

@end
