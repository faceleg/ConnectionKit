//
//  SVGraphic.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyElement.h"


#define SVContentObjectWrapNone [NSNumber numberWithInteger:0]
#define SVContentObjectWrapFloatLeft [NSNumber numberWithInteger:1]
#define SVContentObjectWrapFloatRight [NSNumber numberWithInteger:3]
#define SVContentObjectWrapBlockLeft [NSNumber numberWithInteger:4]
#define SVContentObjectWrapBlockCenter [NSNumber numberWithInteger:5]
#define SVContentObjectWrapBlockRight [NSNumber numberWithInteger:6]
//typedef NSNumber SVContentObjectWrap;
#define SVContentObjectWrap NSNumber

#pragma mark -


//  Have decided to use the term "graphic" in the same way that Pages does through its scripting API (and probably in its class hierarchy). That is, a graphic is anything on the page that can be selected and isn't text. e.g. pagelets, images, plug-ins.

//  I'm declaring a protocol for graphics first to keep things nice and pure. (Also, it means I can make some things @optional so that Core Data will still generate accessors when the superclass chooses not to implement the method)

@protocol SVGraphic
- (NSString *)elementID;
@optional
@end


#pragma mark -


@class SVBody, KTElementPlugin;


@interface SVGraphic : SVBodyElement <SVGraphic>


#pragma mark Placement
@property(nonatomic, copy) SVContentObjectWrap *wrap;
@property(nonatomic, copy) NSNumber *wrapIsFloatOrBlock;    // setter picks best wrap type
@property(nonatomic) BOOL wrapIsFloatLeft;
@property(nonatomic) BOOL wrapIsFloatRight;
@property(nonatomic) BOOL wrapIsBlockLeft;
@property(nonatomic) BOOL wrapIsBlockCenter;
@property(nonatomic) BOOL wrapIsBlockRight;


#pragma mark HTML
@property(nonatomic, retain, readonly) NSString *elementID;
- (NSString *)className;

@end


