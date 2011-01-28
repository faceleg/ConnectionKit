//
//  KSGeometry.m
//  Sandvox
//
//  Created by Mike on 28/01/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KSGeometry.h"


@implementation KSGeometry

+ (NSRect)KSVerticallyUnionRect:(NSRect)aRect :(NSRect)bRect;
{
    NSRect result = aRect;
    
    if (bRect.origin.y < aRect.origin.y)
    {
        result.origin.y = bRect.origin.y;
    }
    
    result.size.height = MAX(NSMaxY(aRect), NSMaxY(bRect)) - NSMinY(result);
    
    return result;
}

@end
