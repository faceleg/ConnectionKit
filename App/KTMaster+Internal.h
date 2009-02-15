//
//  KTMaster+Internal.h
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTMaster.h"


@class KTCodeInjection;


@interface KTMaster (Internal)

- (KTDesign *)design;
- (void)setDesign:(KTDesign *)design;
- (void)setDesignBundleIdentifier:(NSString *)identifier;

#pragma mark Banner
- (NSString *)bannerCSSForPurpose:(KTHTMLGenerationPurpose)generationPurpose;

#pragma mark CSS
- (NSData *)publishedDesignCSSDigest;
- (void)setPublishedDesignCSSDigest:(NSData *)digest;

#pragma mark Site Outline
- (KTCodeInjection *)codeInjection;

@end
