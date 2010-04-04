// 
//  SVImage.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImage.h"

#import "SVApplicationController.h"
#import "SVImageDOMController.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"


@interface SVImage ()

@property(nonatomic, copy) NSString *externalSourceURLString;

@property(nonatomic, copy) NSNumber *constrainedAspectRatio;

@end


#pragma mark -


@implementation SVImage 

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
{
    OBPRECONDITION(media);
    
    SVImage *result = [self insertNewImageInManagedObjectContext:[media managedObjectContext]];
    [result setMedia:media];
    
    CGSize size = [result originalSize];
    [result setWidth:[NSNumber numberWithFloat:size.width]];
    [result setHeight:[NSNumber numberWithFloat:size.height]];
    [result setConstrainProportions:YES];
    
    return result;
}

+ (SVImage *)insertNewImageInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Use same format & compression as last image
    BOOL prefersPNG = [[NSUserDefaults standardUserDefaults] boolForKey:kSVPrefersPNGImageFormatKey];
    if (prefersPNG)
    {
        [self setStorageType:[NSNumber numberWithInteger:NSPNGFileType]];
    }
}

- (void)awakeFromInsertIntoPage:(id <SVPage>)page;
{
    [super awakeFromInsertIntoPage:page];
    
    
    // Start off at a decent size.
    NSNumber *maxWidth = [NSNumber numberWithUnsignedInteger:490];
    if ([self isPagelet]) maxWidth = [NSNumber numberWithUnsignedInteger:200];
    
    if ([[self width] isGreaterThan:maxWidth])
    {
        [self setWidth:maxWidth];
    }
}

#pragma mark Media

@dynamic media;

- (void)setMediaWithURL:(NSURL *)URL;
{
    SVMediaRecord *media = nil;
    if (URL)
    {
        media = [SVMediaRecord mediaWithURL:URL
                                 entityName:@"ImageMedia"
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

- (NSURL *)sourceURL  // for bindings
{
    NSURL *result = nil;
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        result = [media fileURL];
        if (!result) result = [[media fileURLResponse] URL];
        [[SVHTMLContext currentContext] addMedia:media];
    }
    else
    {
        result = [self externalSourceURL];
    }
    
    return result;
}

- (void)setSourceURL:(NSURL *)URL;
{
    [self setExternalSourceURL:URL];
}

- (NSURL *)imagePreviewURL; // picks out URL from media, sourceURL etc.
{    
    SVMediaRecord *media = [self media];
    if (media) [[SVHTMLContext currentContext] addMedia:media];
    
    NSURL *result = [self sourceURL];
    if (!result)
    {
        result = [self placeholderImageURL];
    }
    
    return result;
}

- (NSURL *)placeholderImageURL; // the fallback when no media or external source is chose
{
    NSURL *result = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    return result;
}

#pragma mark Metrics

@dynamic alternateText;

#pragma mark Placement

- (BOOL)canBePlacedInline; { return YES; }

#pragma mark Size

@dynamic width;
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

@dynamic height;
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

- (CGSize)originalSize;
{
    CGSize result = CGSizeMake(200.0f, 128.0f);
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        CIImage *image = [CIImage imageWithIMBImageItem:media];
        result = [image extent].size;
    }
    
    return result;
}

#pragma mark Link

@dynamic link;

#pragma mark Publishing

@dynamic storageType;
@dynamic compressionFactor;

#pragma mark HTML

- (void)writeBody
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    // src=
    NSURL *imageURL = [self imagePreviewURL];
    
    // alt=
    NSString *alt = [self alternateText];
    if (!alt) alt = @"";
    
    // Link
    BOOL isPagelet = [self isPagelet];
    if (isPagelet && [self link])
    {
        [context writeAnchorStartTagWithHref:[[self link] URLString] title:nil target:nil rel:nil];
    }
    
    // Actually write the image
    [context writeImageWithIdName:[self editingElementID]
                        className:(isPagelet ? nil : [self className])
                              src:[context relativeURLStringOfURL:imageURL]
                              alt:alt 
                            width:[[self width] description]
                           height:[[self height] description]];
    
    [context addDependencyOnObject:self keyPath:@"media"];
    [context addDependencyOnObject:self keyPath:@"className"];
    
    if ([self isPagelet] && [self link]) [context writeEndTag];
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return [self media]; }
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObject:@"media"]; }

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    SVMediaRecord *media = [self media];
    
    NSData *data = [media fileContents];
    [propertyList setValue:data forKey:@"fileContents"];
    
    NSURL *URL = [self imagePreviewURL];
    [propertyList setValue:URL forKey:@"sourceURL"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Pull out image data
    NSData *data = [propertyList objectForKey:@"fileContents"];
    if (data)
    {
        NSURLResponse *response = [[NSURLResponse alloc]
                                   initWithURL:[propertyList objectForKey:@"sourceURL"]
                                   MIMEType:nil
                                   expectedContentLength:[data length]
                                   textEncodingName:nil];
        
        SVMediaRecord *media = [SVMediaRecord mediaWithFileContents:data
                                                        URLResponse:response
                                                         entityName:@"ImageMedia"
                                     insertIntoManagedObjectContext:[self managedObjectContext]];
        [response release];
        
        [self setMedia:media];
    }
}

@end
