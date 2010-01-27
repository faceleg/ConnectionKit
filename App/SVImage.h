//
//  SVImage.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVGraphic.h"

@class SVMediaRecord;
@class SVStringAttribute;

@interface SVImage : SVGraphic

@property (nonatomic, retain) SVMediaRecord *media;

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *height;

@property (nonatomic, retain) SVStringAttribute *inlineGraphic;


@end



