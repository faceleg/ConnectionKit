//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVPagelet.h"

@class SVMediaRecord;
@class SVStringAttribute;

@interface SVImage : SVPagelet

@property (nonatomic, retain) SVMediaRecord *media;

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *height;
@property(nonatomic, copy) NSNumber *constrainProportions;  // BOOL, required
- (CGSize)originalSize;

@property (nonatomic, retain) SVStringAttribute *inlineGraphic;


@end



