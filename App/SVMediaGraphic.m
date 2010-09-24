//
//  SVMediaGraphic.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"

#import "KTMaster.h"
#import "SVMediaGraphicInspector.h"
#import "SVMediaRecord.h"
#import "SVImage.h"
#import "KTPage.h"
#import "SVWebEditorHTMLContext.h"

#import "NSError+Karelia.h"


@interface SVMediaGraphic ()

@property(nonatomic, copy) NSString *externalSourceURLString;

@property(nonatomic, copy, readwrite) NSNumber *constrainedAspectRatio;

@end


#pragma mark -


@implementation SVMediaGraphic

#pragma mark Init

+ (id)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMediaGraphic *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaGraphic"
                                                           inManagedObjectContext:context];
    [result loadPlugIn];
    return result;
}

- (void)willInsertIntoPage:(KTPage *)page;
{
    // Placeholder image
    if (![self media])
    {
        SVMediaRecord *media = [[page master] makePlaceholdImageMediaWithEntityName:@"GraphicMedia"];
        [self setMedia:media];
        [self setTypeToPublish:[media typeOfFile]];
        
        [self makeOriginalSize];    // calling super will scale back down if needed
        [self setConstrainProportions:YES];
    }
    
    [super willInsertIntoPage:page];
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

- (void)didAddToPage:(id <SVPage>)page;
{
    [super didAddToPage:page];
    
    
    // Start off at a decent size.
    NSNumber *maxWidth = [NSNumber numberWithUnsignedInteger:490];
    if ([self isPagelet]) maxWidth = [NSNumber numberWithUnsignedInteger:200];
    
    if ([[self width] isGreaterThan:maxWidth])
    {
        [self setWidth:maxWidth];
    }
}

#pragma mark Plug-in

- (SVMediaPlugIn *)plugIn; { return (id)[super plugIn]; }

- (NSString *)plugInIdentifier; { return @"com.karelia.Sandvox.Image"; }

#pragma mark Placement

- (BOOL)isPagelet;
{
    // Images are no longer pagelets once you turn off all additional stuff like title & caption
    if ([[self placement] intValue] == SVGraphicPlacementInline &&
        ![self showsTitle] &&
        ![self showsIntroduction] &&
        ![self showsCaption])
    {
        return NO;
    }
    else
    {
        return [super isPagelet];
    }
}

#pragma mark Media

@dynamic media;
@dynamic isMediaPlaceholder;

- (void)setMediaWithURL:(NSURL *)URL;
{
    SVMediaRecord *media = nil;
    if (URL)
    {
        media = [SVMediaRecord mediaWithURL:URL
                                 entityName:@"GraphicMedia"
             insertIntoManagedObjectContext:[self managedObjectContext]
                                      error:NULL];
    }
    
    [self replaceMedia:media forKeyPath:@"media"];
}

@dynamic externalSourceURLString;

- (NSURL *)externalSourceURL
{
    NSString *string = [self externalSourceURLString];
    return (string) ? [NSURL URLWithString:string] : nil;
}
- (void)setExternalSourceURL:(NSURL *)URL
{
    if (URL) [self replaceMedia:nil forKeyPath:@"media"];
    
    [self setExternalSourceURLString:[URL absoluteString]];
}

- (NSURL *)sourceURL;
{
    NSURL *result = nil;
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        result = [media fileURL];
        if (!result) result = [media mediaURL];
    }
    else
    {
        result = [self externalSourceURL];
    }
    
    return result;
}

- (BOOL)hasFile; { return YES; }

+ (BOOL)acceptsType:(NSString *)uti; { return NO; }

+ (NSArray *)allowedFileTypes; { return nil; }

#pragma mark Media Conversion

@dynamic typeToPublish;

#pragma mark Size

- (void)setSize:(NSSize)size;
{
    if ([self constrainProportions])
    {
        CGFloat constraintRatio = [[self constrainedAspectRatio] floatValue];
        CGFloat aspectRatio = size.width / size.height;
        
        if (aspectRatio < constraintRatio)
        {
            [self setHeight:[NSNumber numberWithFloat:size.height]];
        }
        else
        {
            [self setWidth:[NSNumber numberWithFloat:size.width]];
        }
    }
    else
    {
        [self setWidth:[NSNumber numberWithFloat:size.width]];
        [self setHeight:[NSNumber numberWithFloat:size.height]];
    }
}

- (BOOL)constrainProportions { return [self constrainedAspectRatio] != nil; }
- (void)setConstrainProportions:(BOOL)constrainProportions;
{
    if (constrainProportions)
    {
        CGFloat aspectRatio = [[self width] floatValue] / [[self height] floatValue];
        [self setConstrainedAspectRatio:[NSNumber numberWithFloat:aspectRatio]];
    }
    else
    {
        [self setConstrainedAspectRatio:nil];
    }
}

+ (NSSet *)keyPathsForValuesAffectingConstrainProportions;
{
    return [NSSet setWithObject:@"constrainedAspectRatio"];
}

@dynamic constrainedAspectRatio;

@dynamic naturalWidth;
@dynamic naturalHeight;

- (void)makeOriginalSize;
{
    BOOL constrainProportions = [self constrainProportions];
    [self setConstrainProportions:NO];  // temporarily turn off so we get desired size.
    
    CGSize size = [[self plugIn] originalSize];
    [self setWidth:[NSNumber numberWithFloat:size.width]];
    [self setHeight:[NSNumber numberWithFloat:size.height]];
    
    [self setConstrainProportions:constrainProportions];
}

#pragma mark Size, inherited

- (void)setWidth:(NSNumber *)width;
{
    [self willChangeValueForKey:@"width"];
    [self setPrimitiveValue:width forKey:@"width"];
    [self didChangeValueForKey:@"width"];
    
    NSNumber *aspectRatio = [self constrainedAspectRatio];
    if (aspectRatio)
    {
        NSUInteger height = ([width floatValue] / [aspectRatio floatValue]);
        
        [self willChangeValueForKey:@"height"];
        [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:height] forKey:@"height"];
        [self didChangeValueForKey:@"height"];
    }
}
- (BOOL)validateWidth:(NSNumber **)width error:(NSError **)error;
{
    // SVGraphic.width is optional. For media graphics it becomes compulsary
    BOOL result = (*width != nil);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"width is a mandatory property"];
    }
    
    return result;
}

- (void)setHeight:(NSNumber *)height;
{
    [self willChangeValueForKey:@"height"];
    [self setPrimitiveValue:height forKey:@"height"];
    [self didChangeValueForKey:@"height"];
    
    NSNumber *aspectRatio = [self constrainedAspectRatio];
    if (aspectRatio)
    {
        NSUInteger width = ([height floatValue] * [aspectRatio floatValue]);
        
        [self willChangeValueForKey:@"width"];
        [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:width] forKey:@"width"];
        [self didChangeValueForKey:@"width"];
    }
}
- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;
{
    // SVGraphic.width is optional. For media graphics it becomes compulsary
    BOOL result = (*height != nil);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"height is a mandatory property"];
    }
    
    return result;
}

#pragma mark Inspector

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = [[[SVMediaGraphicInspector alloc]
                                          initWithNibName:@"SVImage" bundle:nil]
                                         autorelease];
    
    return result;
}

- (Class)inspectorFactoryClass; { return [self class]; }

- (id)objectToInspect; { return self; }

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    SVMediaRecord *media = [self media];
    
    NSData *data = [NSData newDataWithContentsOfMedia:media];
    [propertyList setValue:data forKey:@"fileContents"];
    [data release];
    
    NSURL *URL = [self sourceURL];
    [propertyList setValue:[URL absoluteString] forKey:@"sourceURL"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Pull out image data
    NSData *data = [propertyList objectForKey:@"fileContents"];
    if (data)
    {
        NSString *urlString = [propertyList objectForKey:@"sourceURL"];
        NSURL *url = [NSURL URLWithString:urlString];
        
        SVMediaRecord *media = [SVMediaRecord mediaWithData:data
                                                        URL:url
                                                 entityName:@"GraphicMedia"
                             insertIntoManagedObjectContext:[self managedObjectContext]];
        
        [self setMedia:media];
    }
}

@end
