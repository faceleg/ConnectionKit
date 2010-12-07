//
//  SVDownloadSiteItem.h
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"
#import "KTHTMLEditorController.h"


@class SVMediaRecord;


@interface SVDownloadSiteItem : SVSiteItem <KTHTMLSourceObject>

@property(nonatomic, retain) SVMediaRecord *media;
@property(nonatomic, copy) NSString *fileName;


#pragma mark Text edting

// Nil if the doc type is not yet known. Once text has been edited in any way, should be filled in with some value. Back by extensible properties
@property(nonatomic, copy) NSNumber *docType;

@end
