// 
//  SVAuxiliaryPageletText.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAuxiliaryPageletText.h"

#import "SVIntroAndCaptionGraphic.h"

@implementation SVAuxiliaryPageletText 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"<p><br /></p>" forKey:@"string"];
}

@dynamic hidden;

@end
