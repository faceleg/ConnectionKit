// 
//  SVGraphic.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

#import "SVHTMLTemplateParser.h"
#import "SVBody.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSString+Karelia.h"


@implementation SVGraphic

#pragma mark Placement

@dynamic wrap;

- (NSNumber *)wrapIsFloatOrBlock
{
    NSNumber *result = [self wrap];
    if (![result isEqualToNumber:SVContentObjectWrapNone])
    {
        result = [NSNumber numberWithBool:YES];
    }
    return result;
}

- (void)setWrapIsFloatOrBlock:(NSNumber *)useFloatOrBlock
{
    [self setWrap:useFloatOrBlock];
}

+ (NSSet *)keyPathsForValuesAffectingWrapIsFloatOrBlock
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsFloatLeft
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapFloatLeft];
    return result;
}
- (void)setWrapIsFloatLeft:(BOOL)floatLeft
{
    [self setWrap:(floatLeft ? SVContentObjectWrapFloatLeft : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsFloatLeft
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsFloatRight
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapFloatRight];
    return result;
}
- (void)setWrapIsFloatRight:(BOOL)FloatRight
{
    [self setWrap:(FloatRight ? SVContentObjectWrapFloatRight : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsFloatRight
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsBlockLeft
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapBlockLeft];
    return result;
}
- (void)setWrapIsBlockLeft:(BOOL)BlockLeft
{
    [self setWrap:(BlockLeft ? SVContentObjectWrapBlockLeft : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsBlockLeft
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsBlockCenter
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapBlockCenter];
    return result;
}
- (void)setWrapIsBlockCenter:(BOOL)BlockCenter
{
    [self setWrap:(BlockCenter ? SVContentObjectWrapBlockCenter : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsBlockCenter
{
    return [NSSet setWithObject:@"wrap"];
}

- (BOOL)wrapIsBlockRight
{
    BOOL result = [[self wrap] isEqualToNumber:SVContentObjectWrapBlockRight];
    return result;
}
- (void)setWrapIsBlockRight:(BOOL)BlockRight
{
    [self setWrap:(BlockRight ? SVContentObjectWrapBlockRight : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapIsBlockRight
{
    return [NSSet setWithObject:@"wrap"];
}

#pragma mark HTML

@dynamic elementID;
- (BOOL)shouldPublishEditingElementID { return YES; }

- (NSString *)className;
{
    NSString *result = nil;
    
    switch ([[self wrap] integerValue])
    {
        case SVGraphicWrapFloatLeft:
            result = @"narrow left";
            break;
        case SVGraphicWrapFloatRight:
            result = @"narrow right";
            break;
        case SVGraphicWrapBlockLeft:
            result = @"wide left";
            break;
        case SVGraphicWrapBlockCenter:
            result = @"wide center";
            break;
        case SVGraphicWrapBlockRight:
            result = @"wide right";
            break;
    }
    
    return result;
}

@end
