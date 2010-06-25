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
#import "SVRichText.h"
#import "SVTitleBox.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSError+Karelia.h"


@implementation SVTextAttachment 

#pragma mark Range

@dynamic body;
@dynamic graphic;


- (NSRange)range;
{
    NSRange result = NSMakeRange([[self location] unsignedIntegerValue],
                                 [[self length] unsignedIntegerValue]);
    return result;
}

- (void)setRange:(NSRange)range;
{
    [self setLocation:[NSNumber numberWithUnsignedInteger:range.location]];
    [self setLength:[NSNumber numberWithUnsignedInteger:range.length]];
}

@dynamic length;
@dynamic location;

#pragma mark Placement

@dynamic placement;

- (BOOL)validatePlacement:(NSNumber **)placement error:(NSError **)error;
{
    BOOL result = YES;
    
    
    if (result && [self body])
    {
        result = [[self body] validateAttachment:self placement:[*placement intValue] error:error];
    }
    
    
    return result;
}

#pragma mark Wrap

@dynamic causesWrap;
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

- (BOOL)wrapLeft
{
    BOOL result = ([[self causesWrap] boolValue] &&
                   [[self wrap] isEqualToNumber:SVContentObjectWrapFloatLeft]);
    return result;
}
- (void)setWrapLeft:(BOOL)floatLeft
{
    [self setWrap:(floatLeft ? SVContentObjectWrapFloatLeft : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapLeft
{
    return [NSSet setWithObjects:@"wrap", @"causesWrap", nil];
}

- (BOOL)wrapRight
{
    BOOL result = ([[self causesWrap] boolValue] &&
                   [[self wrap] isEqualToNumber:SVContentObjectWrapFloatRight]);
    return result;
}
- (void)setWrapRight:(BOOL)FloatRight
{
    [self setWrap:(FloatRight ? SVContentObjectWrapFloatRight : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapRight
{
    return [NSSet setWithObjects:@"wrap", @"causesWrap", nil];
}

- (BOOL)wrapLeftSplit
{
    BOOL result = ([[self causesWrap] boolValue] &&
                   [[self wrap] isEqualToNumber:SVContentObjectWrapBlockLeft]);
    return result;
}
- (void)setWrapLeftSplit:(BOOL)BlockLeft
{
    [self setWrap:(BlockLeft ? SVContentObjectWrapBlockLeft : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapLeftSplit
{
    return [NSSet setWithObjects:@"wrap", @"causesWrap", nil];
}

- (BOOL)wrapCenterSplit
{
    BOOL result = ([[self causesWrap] boolValue] &&
                   [[self wrap] isEqualToNumber:SVContentObjectWrapBlockCenter]);
    return result;
}
- (void)setWrapCenterSplit:(BOOL)BlockCenter
{
    [self setWrap:(BlockCenter ? SVContentObjectWrapBlockCenter : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapCenterSplit
{
    return [NSSet setWithObjects:@"wrap", @"causesWrap", nil];
}

- (BOOL)wrapRightSplit
{
    BOOL result = ([[self causesWrap] boolValue] &&
                   [[self wrap] isEqualToNumber:SVContentObjectWrapBlockRight]);
    return result;
}
- (void)setWrapRightSplit:(BOOL)BlockRight
{
    [self setWrap:(BlockRight ? SVContentObjectWrapBlockRight : SVContentObjectWrapNone)];
}
+ (NSSet *)keyPathsForValuesAffectingWrapRightSplit
{
    return [NSSet setWithObjects:@"wrap", @"causesWrap", nil];
}

#pragma mark Validation

- (BOOL)validateWrap:(NSNumber **)wrap error:(NSError **)outError;
{
    BOOL result = YES;
    
    // I've defined a constant for SVGraphicWrapCenter, but have no way to support it at the moment
    if ([*wrap integerValue] == SVGraphicWrapCenter)
    {
        result = NO;
        if (outError)
        {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSManagedObjectValidationError localizedDescription:@"Wrap Left not supported"];
        }
    }
    
    return result;
}

- (BOOL)validateForInsert:(NSError **)error;
{
    BOOL result = [super validateForInsert:error];
    if (result) result = [self validateWrapping:error];
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error;
{
    BOOL result = [super validateForUpdate:error];
    if (result) result = [self validateWrapping:error];
    return result;
}

- (BOOL)validateWrapping:(NSError **)outError;
{
    // If want to show title, cannot be inline
    BOOL result = YES;
    
    return result;
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    [propertyList setObject:[[self graphic] serializedProperties] forKey:@"graphic"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    
    // Graphic
    NSDictionary *serializedGraphic = [propertyList valueForKeyPath:@"graphic"];
    
    SVGraphic *graphic = [SVGraphic graphicWithSerializedProperties:serializedGraphic
                                     insertIntoManagedObjectContext:[self managedObjectContext]];

    [self setGraphic:graphic];
    
    // When graphic was copied out of sidebar etc., has no actual text attachment. So, fill in those nil values with sensible defaults
    if (![self causesWrap]) [self setCausesWrap:[NSNumber numberWithBool:YES]];
    if (![self placement]) [self setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    if (![self wrap]) [self setWrap:[NSNumber numberWithInteger:SVGraphicWrapRightSplit]];
}

@end
