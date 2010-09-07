//
//  SVQuickLookPreviewHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVQuickLookPreviewHTMLContext.h"


@implementation SVQuickLookPreviewHTMLContext

- (KTHTMLGenerationPurpose)generationPurpose;
{
    return kSVHTMLGenerationPurposeQuickLookPreview;
}

- (BOOL)isForQuickLook; { return YES; }

#pragma mark CSS

// Additional CSS should be written inline

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    NSString *css = [NSString stringWithContentsOfURL:cssURL
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
    if (css) [self addCSSString:css];
}

@end
