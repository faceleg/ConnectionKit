//
//  SVVideo.h
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"
#import <QTKit/QTKit.h>

@class SVMediaRecord, KSSimpleURLConnection;


@interface SVVideo : SVMediaGraphic
{
	QTMovie *_dimensionCalculationMovie;
	
	KSSimpleURLConnection *_dimensionCalculationConnection;
	
}
+ (SVVideo *)insertNewVideoInManagedObjectContext:(NSManagedObjectContext *)context;

- (void)setPosterFrameWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one

@property (retain) QTMovie *dimensionCalculationMovie;
@property (retain) KSSimpleURLConnection *dimensionCalculationConnection;

@property(nonatomic, retain) SVMediaRecord *posterFrame;

@property(nonatomic, copy) NSNumber *autoplay;
@property(nonatomic, copy) NSNumber *controller;	// BOOLs
@property(nonatomic, copy) NSNumber *loop;
@property(nonatomic, copy) NSNumber *preload;
@property(nonatomic, copy) NSNumber *videoWidth;
@property(nonatomic, copy) NSNumber *videoHeight;

#pragma mark Publishing

@property(nonatomic, copy) NSString *codecType;	// Note: We don't have integer storageType; just use UTI

@end



