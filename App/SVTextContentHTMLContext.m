//
//  SVTextContentHTMLContext.m
//  Sandvox
//
//  Created by Mike on 04/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVTextContentHTMLContext.h"

#import "NSString+Karelia.h"
#import "KSStringHTMLEntityUnescaping.h"


@implementation SVTextContentHTMLContext

- (void)writeCharacters:(NSString *)string;
{
    // Don't escape the string; write it raw
    [super writeString:string];
}

- (void)writeHTMLString:(NSString *)html
{
    [self writeCharacters:[html stringByConvertingHTMLToPlainText]];
}

- (void)startNewline
{
    [super writeString:@"\n"];
}

// Ignore!
- (void)writeString:(NSString *)string { }

- (BOOL)isForPublishing; { return NO; }

- (NSURL *)addThumbnailMedia:(SVMedia *)media width:(NSUInteger)width height:(NSUInteger)height type:(NSString *)type scalingSuffix:(NSString *)suffix options:(SVPageImageRepresentationOptions)options pushSizeToCurrentElement:(BOOL)push;
{
    // Irrelevant to text content
    return nil;
}

@end
