// 
//  SVImage.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImage.h"

#import "SVHTMLContext.h"
#import "SVImageDOMController.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"


@implementation SVImage 

@dynamic media;

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
    CIImage *image = [[CIImage alloc] initWithContentsOfURL:[[self media] fileURL]];
    CGSize result = [image extent].size;
    [image release];
    
    return result;
}

#pragma mark Other

@dynamic inlineGraphic;

#pragma mark HTML

- (void)writeHTML
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    NSURL *imageURL = [[self media] fileURL];
    
    [context writeImageWithIdName:[self editingElementID]
                        className:[self className]
                              src:[imageURL relativeString]
                              alt:nil 
                            width:[[self width] description]
                           height:[[self height] description]];
}

#pragma mark Editing

- (Class)DOMControllerClass { return [SVImageDOMController class]; }

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
