// 
//  SVGraphic.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

#import "SVHTMLTemplateParser.h"
#import "SVRichText.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTitleBox.h"

#import "NSError+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSString+Karelia.h"


@implementation SVGraphic

#pragma mark Initialization

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // UID
    [self setPrimitiveValue:[NSString shortUUIDString] forKey:@"elementID"];
    
    
    // Title
    [self setTitle:[[self class] placeholderTitleText]];
}

- (void)awakeFromInsertIntoPage:(id <SVPage>)page; { }

#pragma mark Pagelet

- (BOOL)isPagelet;
{
    //  We are a pagelet UNLESS embedded inline in text
    BOOL result = YES;
    
    NSNumber *placement = [[self textAttachment] placement];
    if (placement)
    {
        SVGraphicPlacement placementValue = [placement integerValue];
        result = (placementValue != SVGraphicPlacementInline);
    }
    
    return result;
}

- (BOOL)isCallout;  // whether to generate enclosing <div class="callout"> etc.
{
    return ([self calloutWrapClassName] != nil);
}

- (NSString *)calloutWrapClassName; // nil if not a callout
{
    //  We are a callout if a floated pagelet
    NSString *result = nil;
    
    if ([self isPagelet])
    {
        SVGraphicWrap wrap = [[[self textAttachment] wrap] integerValue];
        if (wrap == SVGraphicWrapLeft)
        {
            result = @"left";
        }
        else if (wrap == SVGraphicWrapRight)
        {
            result = @"right";
        }
    }
    
    return result;
}

#pragma mark Title

@dynamic titleBox;

+ (NSString *)placeholderTitleText;
{
    return NSLocalizedString(@"Pagelet", "pagelet title placeholder");
}

#pragma mark Layout/Styling

@dynamic showBackground;
@dynamic showBorder;

#pragma mark Placement

@dynamic textAttachment;

- (BOOL)canBePlacedInline; { return NO; }

- (void)didPlaceInline:(BOOL)isInline; // turns off title, etc.
{
    if (isInline)
    {
        [[self titleBox] setHidden:[NSNumber numberWithBool:YES]];
    }
    else
    {
        [[self textAttachment] setCausesWrap:[NSNumber numberWithBool:YES]];
    }
}

- (void)detachFromBodyText; // deletes the corresponding text attachment and string if there is one.
{
    SVTextAttachment *attachment = [self textAttachment];
    if (attachment)
    {
        [attachment setGraphic:nil];    // so deleting it doesn't cascade and delete us too
        [[attachment body] deleteCharactersInRange:[attachment range]];
    }
}

- (BOOL)validateForInlinePlacement:(NSError **)error;
{
    BOOL result;
    
    if (!(result = ![self showsTitle]))
    {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                code:NSManagedObjectValidationError
                                localizedDescription:@"Graphics cannot show title while inline"];
    }
    
    return result;
}

#pragma mark Sidebar

+ (BOOL)validateSortKeyForPagelets:(NSSet **)pagelets error:(NSError **)error;
{
    BOOL result = YES;
    
    // All our pagelets should have unique sort keys
    NSSet *sortKeys = [*pagelets valueForKey:@"sortKey"];
    if ([sortKeys count] != [*pagelets count])
    {
        result = NO;
        if (error)
        {
            NSDictionary *info = [NSDictionary dictionaryWithObject:@"Pagelet sort keys are not unique" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSManagedObjectValidationError userInfo:info];
        }
    }
    
    return result;
}

@dynamic sortKey;

@dynamic sidebars;

#pragma mark Validation

- (BOOL)validateForInsert:(NSError **)error
{
    BOOL result = [super validateForInsert:error];
    if (result && [self textAttachment]) result = [[self textAttachment] validateWrapping:error];
    
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error
{
    BOOL result = [super validateForUpdate:error];
    if (result && [self textAttachment]) result = [[self textAttachment] validateWrapping:error];
    
    return result;
}

#pragma mark HTML

- (NSString *)className;
{
    NSString *result = nil;
    
    SVTextAttachment *textAttachment = [self textAttachment];
    if ([[textAttachment causesWrap] boolValue])
    {
        switch ([[textAttachment wrap] integerValue])
        {
            case SVGraphicWrapLeft:
                result = @"narrow right";
                break;
            case SVGraphicWrapRight:
                result = @"narrow left";
                break;
            case SVGraphicWrapLeftSplit:
                result = @"wide right";
                break;
            case SVGraphicWrapCenterSplit:
                result = @"wide center";
                break;
            case SVGraphicWrapRightSplit:
                result = @"wide left";
                break;
        }
    }
    
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingClassName
{
    return [NSSet setWithObjects:@"textAttachment.causesWrap", @"textAttachment.wrap", nil];
}

- (void)writeHTML:(SVHTMLContext *)context
{
    // If the placement changes, want whole WebView to update
    [context addDependencyOnObject:self keyPath:@"textAttachment.placement"];
    
    
    // Possible callout. Could we push some of this logic of into -willBeginWritingGraphic: etc?
    NSString *calloutWrap = [self calloutWrapClassName];
    if (calloutWrap) [context writeCalloutStartTagsWithAlignmentClassName:calloutWrap];
    
    
    // Alert context. Must happen *after* enclosing callout is written
    [context willBeginWritingGraphic:self];
    
    
    if ([self isPagelet])
    {
        // Pagelet
        SVTemplate *template = [[self class] template];
        
        SVHTMLTemplateParser *parser =
        [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                             component:self];
        
        [parser parse];
        [parser release];
    }
    else
    {
        [self writeBody:context];
    }
    
    
    // Finish up
    [context didEndWritingGraphic];
    if (calloutWrap) [context writeCalloutEnd];
}

- (void)writeBody:(SVHTMLContext *)context;
{
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
}

// For the benefit of pagelet HTML template
- (void)writeBody { [self writeBody:[SVHTMLContext currentContext]]; }

+ (SVTemplate *)template;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"PageletTemplate.html"] retain];
    }
    
    return result;
}

@dynamic elementID;
- (NSString *)editingElementID { return [self elementID]; }
- (BOOL)shouldPublishEditingElementID { return YES; }

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return nil; }

#pragma mark Serialization

+ (id)graphicWithSerializedProperties:(id)properties
       insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSString *entityName = [properties objectForKey:@"entity"];
    
    SVGraphic *result = [NSEntityDescription
                          insertNewObjectForEntityForName:entityName
                          inManagedObjectContext:context];
    
    [result awakeFromPropertyList:properties];
    
    return result;
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    // Don't deserialzed element ID as it means we have two of them!
    NSString *ID = [self elementID];
    [super awakeFromPropertyList:propertyList];
    
    [self willChangeValueForKey:@"elementID"];
    [self setPrimitiveValue:ID forKey:@"elementID"];
    [self didChangeValueForKey:@"elementID"];
    
    
    // Restore title
    [[self titleBox] awakeFromPropertyList:[propertyList objectForKey:@"titleBox"]];
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    [propertyList setObject:[[self entity] name] forKey:@"entity"];
    
    [propertyList setValue:[[self titleBox] serializedProperties]   // might be nil in a subclass
                    forKey:@"titleBox"];  
}

#pragma mark SVPageletPlugInContainer

- (NSString *)title	// get title, but without attributes
{
	return [[self titleBox] text];
}

- (void)setTitle:(NSString *)title;
{
    SVTitleBox *text = [self titleBox];
    if (!text)
    {
        text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletTitle" inManagedObjectContext:[self managedObjectContext]];
        [self setTitleBox:text];
    }
    [text setText:title];
}

+ (NSSet *)keyPathsForValuesAffectingTitle
{
    return [NSSet setWithObject:@"titleBox.text"];
}

- (BOOL)showsTitle { return ![[[self titleBox] hidden] boolValue]; }
- (void)setShowsTitle:(BOOL)show { [[self titleBox] setHidden:[NSNumber numberWithBool:!show]]; }

- (BOOL)isBordered { return [[self showBorder] boolValue]; }
- (void)setBordered:(BOOL)border { [self setShowBorder:[NSNumber numberWithBool:border]]; }

@end


#pragma mark -


@implementation SVGraphic (Deprecated)

#pragma mark Title

- (NSString *)titleHTMLString
{
    return [[self titleBox] textHTMLString];
}

+ (NSSet *)keyPathsForValuesAffectingTitleHTMLString
{
    return [NSSet setWithObject:@"titleBox.textHTMLString"];
}

@end
