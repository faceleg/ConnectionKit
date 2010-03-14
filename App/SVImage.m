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


@interface SVImage ()
@property(nonatomic, copy) NSString *sourceURLString;
@end


#pragma mark -


@implementation SVImage 

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
{
    SVImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                   inManagedObjectContext:[media managedObjectContext]];
    [result setMedia:media];
    
    CGSize size = [result originalSize];
    [result setWidth:[NSNumber numberWithFloat:size.width]];
    [result setHeight:[NSNumber numberWithFloat:size.height]];
    [result setConstrainProportions:[NSNumber numberWithBool:YES]];
    
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

#pragma mark Media

@dynamic media;
@dynamic sourceURLString;

- (NSURL *)sourceURL { return [NSURL URLWithString:[self sourceURLString]]; }
- (void)setSourceURL:(NSURL *)URL
{
    if (URL) [[self managedObjectContext] deleteObject:[self media]];
    [self setSourceURLString:[URL absoluteString]];
}

- (NSURL *)imagePreviewURL; // picks out URL from media, sourceURL etc.
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
        //result = [self sourceURL];
    }
    
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
    
    if ([[self constrainProportions] boolValue])
    {
        CGSize originalSize = [self originalSize];
        CGFloat height = originalSize.height * ([width floatValue] / originalSize.width);
        
        [self willChangeValueForKey:@"height"];
        [self setPrimitiveValue:[NSNumber numberWithFloat:height] forKey:@"height"];
        [self didChangeValueForKey:@"height"];
    }
}

@dynamic height;
- (void)setHeight:(NSNumber *)height;
{
    [self willChangeValueForKey:@"height"];
    [self setPrimitiveValue:height forKey:@"height"];
    [self didChangeValueForKey:@"height"];
    
    if ([[self constrainProportions] boolValue])
    {
        CGSize originalSize = [self originalSize];
        CGFloat width = originalSize.width * ([height floatValue] / originalSize.height);
        
        [self willChangeValueForKey:@"width"];
        [self setPrimitiveValue:[NSNumber numberWithFloat:width] forKey:@"width"];
        [self didChangeValueForKey:@"width"];
    }
}

@dynamic constrainProportions;

// TODO: We might want to cache this?

- (CGSize)originalSize;
{
    CIImage *image;
    NSURL *URL = [[self media] fileURL];
    if (URL)
    {
        image = [[CIImage alloc] initWithContentsOfURL:URL];
    }
    else
    {
        image = [[CIImage alloc] initWithData:[[self media] fileContents]];
    }
    CGSize result = [image extent].size;
    [image release];
    
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
    if ([self isPagelet] && [self link])
    {
        [context writeAnchorStartTagWithHref:[[self link] URLString] title:nil target:nil rel:nil];
    }
    
    // Actually write the image
    [context writeImageWithIdName:[self editingElementID]
                        className:[self className]
                              src:[context relativeURLStringOfURL:imageURL]
                              alt:alt 
                            width:[[self width] description]
                           height:[[self height] description]];
    
    [context addDependencyOnObject:self keyPath:@"className"];
    
    if ([self isPagelet] && [self link]) [context writeEndTag];
}

#pragma mark Editing

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
