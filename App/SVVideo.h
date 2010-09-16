//
//  SVVideo.h
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"
#import "SVEnclosure.h"
#import <QTKit/QTKit.h>

typedef enum {
	kPreloadMeta = -1,	// we don't really support this in the UI, but let's provide for it in the data model.
	kPreloadNone = 0,
	kPreloadAuto = 1
} PreloadState;

@class SVMediaRecord, KSSimpleURLConnection;



@interface SVVideo : SVMediaGraphic <SVEnclosure>
{
	QTMovie *_dimensionCalculationMovie;
	
	KSSimpleURLConnection *_dimensionCalculationConnection;
	
}
+ (SVVideo *)insertNewVideoInManagedObjectContext:(NSManagedObjectContext *)context;
+ (void)writeFallbackScriptOnce:(SVHTMLContext *)context;

- (void)setPosterFrameWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one

@property (retain) QTMovie *dimensionCalculationMovie;
@property (retain) KSSimpleURLConnection *dimensionCalculationConnection;

@property(nonatomic, retain) SVMediaRecord *posterFrame;

@property(nonatomic, copy) NSNumber *autoplay;
@property(nonatomic, copy) NSNumber *controller;	// BOOLs
@property(nonatomic, copy) NSNumber *loop;
@property(nonatomic, copy) NSNumber *preload;		// PreloadState

@property(nonatomic, copy) NSNumber *posterFrameType;

#pragma mark Publishing

@property(nonatomic, copy) NSString *codecType;	// Note: We don't have integer storageType; just use UTI

@end



