// 
//  SVTextAttachment.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVTextAttachment.h"

#import "SVGraphic.h"
#import "SVHTMLContext.h"
#import "SVRichText.h"
#import "SVTitleBox.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSError+Karelia.h"


@implementation SVTextAttachment 

+ (SVTextAttachment *)textAttachmentWithGraphic:(SVGraphic *)graphic;
{
    OBPRECONDITION(graphic);
    
    SVTextAttachment *result = [self insertNewTextAttachmentInManagedObjectContext:
                                [graphic managedObjectContext]];
    
    [result setValue:graphic forKey:@"graphic"];
    
    return result;
}

+ (SVTextAttachment *)insertNewTextAttachmentInManagedObjectContext:(NSManagedObjectContext *)context;
{
    return [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                         inManagedObjectContext:context];
}

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
- (BOOL)validateCausesWrap:(NSNumber **)causesWrap error:(NSError **)error;
{
    BOOL result = YES;
    
    BOOL wrap = [*causesWrap boolValue];
    if (wrap)
    {
        // Make sure the container supports wrapped images
        if (![[self body] attachmentsCanCauseWrap])
        {
            result = NO;
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSValidationNumberTooLargeError
                                    localizedDescription:@"Graphics in this text area cannot cause wrap"];
        }
    }
    else
    {
        // Only images and raw HTML support not causing wrap
        if (![[self graphic] canWriteHTMLInline])
        {
            result = NO;
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSValidationNumberTooSmallError
                                    localizedDescription:@"Graphic must cause wrap"];
        }
    }
    
    return result;
}

@dynamic wrap;
- (BOOL)validateWrap:(NSNumber **)wrap error:(NSError **)error;
{
    // By default, only certain wraps are supported
    switch ([*wrap intValue])
    {
        case SVGraphicWrapNone:
            if ([[self graphic] canWriteHTMLInline]) break;   // only images are allowed this
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSValidationNumberTooSmallError
                                    localizedDescription:@"SVGraphicWrapNone is not supported"];
            return NO;
    
        case SVGraphicWrapCenter:
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSManagedObjectValidationError
                                    localizedDescription:@"Wrap Center not supported"];
            return NO;
    }
    
    return YES;
}

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

+ (NSArray *)textAttachmentsFromPasteboard:(NSPasteboard *)pasteboard
            insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    if ([[pasteboard types] containsObject:kSVGraphicPboardType])
    {
        id plist = [pasteboard propertyListForType:kSVGraphicPboardType];
        if (plist)
        {
            // Create graphic
            SVGraphic *graphic = [[SVGraphic graphicsFromPasteboard:pasteboard 
                                     insertIntoManagedObjectContext:context] objectAtIndex:0];
            
            
            // Create attachment
            SVTextAttachment *attachment = [self insertNewTextAttachmentInManagedObjectContext:context];
            [attachment setGraphic:graphic];
            
            
            // Copy over placement as best as possible
            NSNumber *placement = [plist objectForKey:@"placement"];
            if ([placement intValue] == SVGraphicPlacementSidebar)
            {
                placement = [NSNumber numberWithInt:SVGraphicPlacementCallout];
            }
            if ([attachment validateValue:&placement forKey:@"placement" error:NULL])
            {
                [attachment setPlacement:placement];
            }
            
            
            // Copy over wrapping
            NSNumber *causesWrap = [plist objectForKey:@"causesWrap"];
            if (causesWrap) [attachment setCausesWrap:causesWrap];
            NSNumber *wrap = [plist objectForKey:@"wrap"];
            if (wrap) [attachment setWrap:wrap];
            
            
            return [NSArray arrayWithObject:attachment];
        }
    }
    
    return nil;
}

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
