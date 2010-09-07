//
//  SVQuickLookPreviewHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVQuickLookPreviewHTMLContext.h"

#import "KTDesign.h"
#import "KTMaster.h"
#import "SVSiteItem.h"

#import "NSURL+Karelia.h"


@implementation SVQuickLookPreviewHTMLContext

- (KTHTMLGenerationPurpose)generationPurpose;
{
    return kSVHTMLGenerationPurposeQuickLookPreview;
}

- (BOOL)isForQuickLook; { return YES; }

#pragma mark CSS

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    // CSS other than design should be written inline
    // Yes, this check should be done better than just the filename
    if ([[cssURL lastPathComponent] isEqualToString:@"main.css"])
    {
        return [super addCSSWithURL:cssURL];
    }
    
    
    NSString *css = [NSString stringWithContentsOfURL:cssURL
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
    if (css) [self addCSSString:css];
}

@end
