//
//  SVImageDOMController.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageDOMController.h"

#import "WebEditingKit.h"
#import "SVGraphicFactory.h"
#import "SVWebEditorHTMLContext.h"

#import "DOMNode+Karelia.h"

#import <QuartzCore/QuartzCore.h>


@implementation SVImageDOMController

#pragma mark Creation

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [super awakeFromHTMLContext:context];
    
    SVMediaGraphicDOMController *parent = (SVMediaGraphicDOMController *)[self parentWebEditorItem];
    OBASSERT([parent isKindOfClass:[SVMediaGraphicDOMController class]]);
    [parent setImageDOMController:self];
}

#pragma mark Element

- (NSString *)elementIdName;
{
    NSString *idName = [[self representedObject] elementIdName];
    NSString *result = (idName ? [@"image-" stringByAppendingString:idName] : nil);
    return result;
}

#pragma mark Selection

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, no. EXCEPT for inline, non-wrap-causing images
    BOOL result = NO;
    
    SVImage *image = [self representedObject];
    if ([image shouldWriteHTMLInline])
    {
        result = YES;
    }
    
    return result;
}

@end

