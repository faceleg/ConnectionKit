//
//  SVTemplateContext.m
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTemplateContext.h"


@implementation SVTemplateContext

- (void)writeString:(NSString *)string;
{
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
}

@end
