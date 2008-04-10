//
//  KTMaster.h
//  Marvel
//
//  Created by Mike on 23/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KT.h"
#import "KTDocument.h"


@class KTDesign;
@class KTMediaContainer;


@interface KTMaster : NSManagedObject 
{
}

- (NSString *)siteTitleText;

- (NSString *)copyrightHTML;
- (void)setCopyrightHTML:(NSString *)copyrightHTML;
- (NSString *)defaultCopyrightHTML;

- (KTDesign *)design;
- (void)setDesign:(KTDesign *)design;

- (KTMediaContainer *)bannerImage;
- (void)setBannerImage:(KTMediaContainer *)banner;
- (void)setBannerImageFromSourceMedia:(KTMediaContainer *)media;

- (KTMediaContainer *)logoImage;
- (void)setLogoImage:(KTMediaContainer *)logo;

- (KTMediaContainer *)favicon;
- (void)setFavicon:(KTMediaContainer *)favicon;

- (KTTimestampType)timestampType;
- (void)setTimestampType:(KTTimestampType)timestampType;

- (NSString *)masterCSSForPurpose:(KTHTMLGenerationPurpose)generationPurpose;
- (NSString *)publishedMasterCSSPathRelativeToSite;

- (BOOL)hasCodeInjection;

@end
