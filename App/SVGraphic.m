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
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTitleBox.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSSortDescriptor+Karelia.h"
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

#pragma mark Title

@dynamic titleBox;

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

+ (NSString *)placeholderTitleText;
{
    return NSLocalizedString(@"Pagelet", "pagelet title placeholder");
}

#pragma mark Layout/Styling

@dynamic showBackground;
@dynamic showBorder;

#pragma mark Placement

@dynamic callout;
@dynamic textAttachment;

- (BOOL)canBePlacedInline; { return NO; }

#pragma mark Sidebar

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Graphic"
                                   inManagedObjectContext:context]];
    [request setSortDescriptors:[self pageletSortDescriptors]];
    
    NSArray *result = [context executeFetchRequest:request error:NULL];
    
    // Tidy up
    [request release];
    return result;
}

+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;
{
    NSArray *sortDescriptors = [self pageletSortDescriptors];
    NSArray *result = [[pagelets allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

+ (NSArray *)pageletSortDescriptors;
{
    static NSArray *result;
    if (!result)
    {
        result = [NSSortDescriptor sortDescriptorArrayWithKey:@"sortKey"
                                                    ascending:YES];
        [result retain];
        OBASSERT(result);
    }
    
    return result;
}

+ (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;
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

- (void)moveBeforeSidebarPagelet:(SVGraphic *)pagelet
{
    OBPRECONDITION(pagelet);
    
    NSArray *pagelets = [[self class] sortedPageletsInManagedObjectContext:[self managedObjectContext]];
    
    // Locate after pagelet
    NSUInteger index = [pagelets indexOfObject:pagelet];
    OBASSERT(index != NSNotFound);
    
    // Set our sort key to match
    NSNumber *pageletSortKey = [pagelet sortKey];
    OBASSERT(pageletSortKey);
    NSInteger previousSortKey = [pageletSortKey integerValue] - 1;
    [self setSortKey:[NSNumber numberWithInteger:previousSortKey]];
    
    // Bump previous pagelets along as needed
    for (NSUInteger i = index; i > 0; i--)  // odd handling of index so we can use an *unsigned* integer
    {
        SVGraphic *previousPagelet = [pagelets objectAtIndex:(i - 1)];
        if (previousPagelet != self)    // don't want to accidentally process self twice
        {
            previousSortKey--;
            
            if ([[previousPagelet sortKey] integerValue] > previousSortKey)
            {
                [previousPagelet setSortKey:[NSNumber numberWithInteger:previousSortKey]];
            }
            else
            {
                break;
            }
        }
    }
}

- (void)moveAfterSidebarPagelet:(SVGraphic *)pagelet;
{
    OBPRECONDITION(pagelet);
    
    NSArray *pagelets = [[self class] sortedPageletsInManagedObjectContext:[self managedObjectContext]];
    
    // Locate after pagelet
    NSUInteger index = [pagelets indexOfObject:pagelet];
    OBASSERT(index != NSNotFound);
    
    // Set our sort key to match
    NSNumber *pageletSortKey = [pagelet sortKey];
    OBASSERT(pageletSortKey);
    NSInteger nextSortKey = [pageletSortKey integerValue] + 1;
    [self setSortKey:[NSNumber numberWithInteger:nextSortKey]];
    
    // Bump following pagelets along as needed
    for (NSUInteger i = index+1; i < [pagelets count]; i++)
    {
        SVGraphic *nextPagelet = [pagelets objectAtIndex:i];
        if (nextPagelet != self)    // don't want to accidentally process self twice
        {
            nextSortKey++;
            
            if ([[nextPagelet sortKey] integerValue] < nextSortKey)
            {
                [nextPagelet setSortKey:[NSNumber numberWithInteger:nextSortKey]];
            }
            else
            {
                break;
            }
        }
    }
}

#pragma mark Validation

- (BOOL)validatePlacement:(NSError **)error
{
    // Used to insist that pagelets should always have a sidebar OR callout. Now, it should be OK for a pagelet not to appear anywhere since it can be filed away in the Page Inspector, ready to put back on a page.
    return YES;
}

- (BOOL)validateForInsert:(NSError **)error
{
    BOOL result = [super validateForInsert:error];
    if (result)
    {
        result = [self validatePlacement:error];
    }
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error
{
    BOOL result = [super validateForUpdate:error];
    if (result)
    {
        result = [self validatePlacement:error];
    }
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
    return [NSSet setWithObject:@"textAttachment.wrap"];
}

- (void)writeHTML
{
    if ([self isPagelet])
    {
        SVTemplate *template = [[self class] template];
        
        SVHTMLTemplateParser *parser =
        [[SVHTMLTemplateParser alloc] initWithTemplate:[template templateString]
                                             component:self];
        
        [parser parse];
        [parser release];
    }
    else
    {
       [self writeBody];
    }
}

- (void)writeBody;
{
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
}

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

- (NSString *)titleText	// get title, but without attributes
{
	return [[self titleBox] text];
}

- (void)setTitleText:(NSString *)value
{
	[self setTitle:value];
}

+ (NSSet *)keyPathsForValuesAffectingTitleText
{
    return [NSSet setWithObject:@"title"];
}

@end
