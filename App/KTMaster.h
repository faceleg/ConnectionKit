//
//  KTMaster.h
//  Marvel
//
//  Created by Mike on 23/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTManagedObject.h"

#import "KT.h"
#import "KTHTMLParser.h"


@class KTDesign;
@class KTMediaContainer;


@interface KTMaster : KTManagedObject 

- (NSString *)siteTitleText;
- (void)setSiteTitleHTML:(NSString *)value;

- (NSString *)copyrightHTML;
- (void)setCopyrightHTML:(NSString *)copyrightHTML;
- (NSString *)defaultCopyrightHTML;

- (NSURL *)designDirectoryURL;

- (KTMediaContainer *)bannerImage;
- (void)setBannerImage:(KTMediaContainer *)banner;
- (KTMediaContainer *)scaledBanner;

- (KTMediaContainer *)logoImage;
- (void)setLogoImage:(KTMediaContainer *)logo;

- (KTMediaContainer *)favicon;
- (void)setFavicon:(KTMediaContainer *)favicon;

#pragma mark Timestamp
- (KTTimestampType)timestampType;
- (void)setTimestampType:(KTTimestampType)timestampType;

- (NSDateFormatterStyle)timestampFormat;
- (void)setTimestampFormat:(NSDateFormatterStyle)format;

#pragma mark Language
- (NSString *)language;

- (BOOL)hasCodeInjection;

#pragma mark Placeholder
- (KTMediaContainer *)placeholderImage;

@end


@interface KTMaster (PluginAPI)
- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse;
@end
