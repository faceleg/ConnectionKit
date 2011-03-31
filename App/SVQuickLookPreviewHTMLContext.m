//
//  SVQuickLookPreviewHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVQuickLookPreviewHTMLContext.h"

#import "KTDesign.h"
#import "KTMaster.h"
#import "SVSiteItem.h"

#import "NSString+Karelia.h"
#import "KSURLUtilities.h"


@implementation SVQuickLookPreviewHTMLContext

- (KTHTMLGenerationPurpose)generationPurpose;
{
    return kSVHTMLGenerationPurposeQuickLookPreview;
}

- (BOOL)isForQuickLook; { return YES; }

- (NSString *)relativeStringFromURL:(NSURL *)URL;
{
    if ([URL isFileURL])
    {
        // Files outside the package should be copied in
        NSURL *docURL = [[[self baseURL]    // perhaps a slightly hacky way to locate it!
                          ks_URLByDeletingLastPathComponent]
                         ks_URLByDeletingLastPathComponent];
                
        if (![URL ks_isSubpathOfURL:docURL])
        {
            NSString *result = [@"Resources" stringByAppendingPathComponent:
                                [URL ks_lastPathComponent]];
            
            return result;
        }
    }
    
    return [super relativeStringFromURL:URL];
}

#pragma mark CSS

- (NSURL *)addCSSWithURL:(NSURL *)cssURL;
{
    // CSS other than design should be written inline
    // Yes, this check should be done better than just the filename
    if ([[cssURL ks_lastPathComponent] isEqualToString:@"main.css"])
    {
        return [super addCSSWithURL:cssURL];
    }
    
    
    NSString *css = [NSString stringWithContentsOfURL:cssURL
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
    return [self addCSSString:css];
}

@end
