//
//  KTMaster+Internal.h
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTMaster.h"


@interface KTMaster (Internal)

- (KTDesign *)design;
- (void)setDesign:(KTDesign *)design;
- (void)setDesignBundleIdentifier:(NSString *)identifier;

#pragma mark CSS
- (NSString *)masterCSSForPurpose:(KTHTMLGenerationPurpose)generationPurpose;

@end
