//
//  SVDownloadSiteItem.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"


@class SVMediaRecord;


@interface SVDownloadSiteItem : SVSiteItem

@property(nonatomic, retain) SVMediaRecord *media;
@property(nonatomic, copy) NSString *fileName;

@end
