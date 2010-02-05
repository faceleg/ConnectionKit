//
//  SVGraphic.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyElement.h"


typedef enum {
    SVGraphicWrapNone,
    SVGraphicWrapFloatLeft,
    SVGraphicWrapFloatRight,
    SVGraphicWrapBlockLeft,
    SVGraphicWrapBlockCenter,
    SVGraphicWrapBlockRight,
} SVGraphicWrap;


#define SVContentObjectWrapNone [NSNumber numberWithInteger:SVGraphicWrapNone]
#define SVContentObjectWrapFloatLeft [NSNumber numberWithInteger:SVGraphicWrapFloatLeft]
#define SVContentObjectWrapFloatRight [NSNumber numberWithInteger:SVGraphicWrapFloatRight]
#define SVContentObjectWrapBlockLeft [NSNumber numberWithInteger:SVGraphicWrapBlockLeft]
#define SVContentObjectWrapBlockCenter [NSNumber numberWithInteger:SVGraphicWrapBlockCenter]
#define SVContentObjectWrapBlockRight [NSNumber numberWithInteger:SVGraphicWrapBlockRight]
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


