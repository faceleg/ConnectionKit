//
//  SVDownloadSiteItem.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"
#import "KTHTMLEditorController.h"


@class SVMediaRecord;


@interface SVDownloadSiteItem : SVSiteItem <KTHTMLSourceObject>

@property(nonatomic, retain) SVMediaRecord *media;
@property(nonatomic, copy) NSString *filename;


#pragma mark Text edting

// Nil; not really stored.
@property(nonatomic, copy) NSNumber *contentType;

@property(nonatomic, copy) NSData *lastValidMarkupDigest;   // extensible property backed


@end
