// 
//  SVTextAttachment.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextAttachment.h"

#import "SVGraphic.h"
#import "SVHTMLContext.h"

#import "NSError+Karelia.h"


@implementation SVTextAttachment 

- (void)writeHTML;
{
    NSString *string = [[[self paragraph] archiveString] substringWithRange:[self range]];
    [[SVHTMLContext currentContext] writeString:string];
}

#pragma mark Range

@dynamic body;
@dynamic pagelet;


- (NSRange)range;
{
    NSRange result = NSMakeRange([[self location] unsignedIntegerValue],
                                 [[self length] unsignedIntegerValue]);
    return result;
}

@dynamic length;
@dynamic location;

@dynamic placement;
@dynamic causesWrap;
@dynamic wrap;

- (BOOL)validatePlacement:(NSNumber **)placement error:(NSError **)error;
{
    BOOL result = YES;
    
    SVGraphicPlacement placementValue = [*placement integerValue];
    if (placementValue == SVGraphicPlacementInline)
    {
        result = [[self pagelet] canBePlacedInline];
        if (!result && error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationNumberTooSmallError localizedDescription:@"Can't place graphic inline"];
        }
    }
    
    return result;
}

@end
