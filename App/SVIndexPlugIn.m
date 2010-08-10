//
//  SVIndexPlugIn.m
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIndexPlugIn.h"


@implementation SVIndexPlugIn

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // Indexes should generally fill full width
    [[self container] setContainerWidth:nil];
}

@end
