//
//  SVTextContentHTMLContext.m
//  Sandvox
//
//  Created by Mike on 04/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextContentHTMLContext.h"

#import "NSString+Karelia.h"


@implementation SVTextContentHTMLContext

- (void)writeText:(NSString *)string;
{
    // Don't escape the string; write it raw
    [super writeString:string];
}

- (void)writeHTMLString:(NSString *)html
{
    [self writeText:[html stringByConvertingHTMLToPlainText]];
}

- (void)writeNewline
{
    [super writeString:@"\n"];
}

// Ignore!
- (void)writeString:(NSString *)string { }

@end
