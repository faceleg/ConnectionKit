//
//  KTStalenessHTMLParser.m
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTStalenessHTMLParser.h"


@implementation KTStalenessHTMLParser

/*	Locating localized strings is expensive and there's no point doing it for the staleness manager.
 */
- (NSString *)componentLocalizedString:(NSString *)tag { return @""; }

- (NSString *)componentTargetLocalizedString:(NSString *)tag { return @""; }

- (NSString *)mainBundleLocalizedString:(NSString *)tag { return @""; }


@end
