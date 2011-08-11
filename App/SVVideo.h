//
//  SVVideo.h
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVAudioVisualPlugIn.h"
#import "SVEnclosure.h"
#import <QTKit/QTKit.h>

@class SVMediaRecord, KSSimpleURLConnection;

typedef enum { kPosterFrameTypeUndefined = 0, kPosterFrameTypeNone, kPosterFrameTypeAutomatic, kPosterTypeChoose } PosterFrameType;


@interface SVVideo : SVAudioVisualPlugIn
{
	BOOL _didInitializePropertiesWasCalled;
	QTMovie *_dimensionCalculationMovie;
	KSSimpleURLConnection *_dimensionCalculationConnection;	// load some remote data if we can't load as a QTMovie
	PosterFrameType _posterFrameType;
}

+ (void)writeFallbackScriptOnce:(SVHTMLContext *)context;

@property (nonatomic, retain) QTMovie *dimensionCalculationMovie;
@property (nonatomic, retain) KSSimpleURLConnection *dimensionCalculationConnection;

@property (nonatomic) PosterFrameType posterFrameType;

#pragma mark Publishing



@end



