//
//  KTMaster.h
//  Marvel
//
//  Created by Mike on 23/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTMaster : NSManagedObject {

}

- (NSString *)siteTitleText;

- (NSString *)copyrightHTML;

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

- (NSString *)masterCSSForPurpose:(int)generationPurpose;
- (NSString *)publishedMasterCSSPathRelativeToSite;
@end
