//
//  SVTextAttachment.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>


@class SVRichText, SVGraphic;


@interface SVTextAttachment : NSManagedObject

//  An attribute may write pretty much whatever it likes.
//  For example, an inline graphic should just ask its graphic to write. Other attributes could write some start tags, then the usual string content, then end tags.


@property(nonatomic, retain) SVRichText *body;
@property(nonatomic, retain) SVGraphic *graphic;


- (NSRange)range;               // NOT KVO-compliant
- (void)setRange:(NSRange)range;
@property(nonatomic, retain) NSNumber *length;
@property(nonatomic, retain) NSNumber *location;


#pragma mark Placement
@property(nonatomic, copy) NSNumber *placement;     // mandatory, SVGraphicPlacement


#pragma mark Wrap

@property(nonatomic, copy) NSNumber *causesWrap;    // mandatory, BOOL
@property(nonatomic, copy) NSNumber *wrap;          // mandatory, SVGraphicWrap

@property(nonatomic, copy) NSNumber *wrapIsFloatOrBlock;    // setter picks best wrap type
@property(nonatomic) BOOL wrapLeft;
@property(nonatomic) BOOL wrapRight;
@property(nonatomic) BOOL wrapLeftSplit;
@property(nonatomic) BOOL wrapCenterSplit;
@property(nonatomic) BOOL wrapRightSplit;


#pragma mark Validation
- (BOOL)validateWrapping:(NSError **)outError;


@end



