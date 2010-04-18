// 
//  SVAuxilaryPageletText.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAuxilaryPageletText.h"

#import "SVIntroAndCaptionGraphic.h"

@implementation SVAuxilaryPageletText 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:@"<p></p>" forKey:@"string"];
}

@dynamic hidden;

@end
