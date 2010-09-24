//
//  SVAudio.h
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaPlugIn.h"

#import "SVVideo.h"		// for PreloadState
#import "SVEnclosure.h"

@class SVMediaRecord;

@interface SVAudio : SVMediaPlugIn <SVEnclosure>

@property(nonatomic, copy) NSNumber *autoplay;
@property(nonatomic, copy) NSNumber *controller;	// BOOLs
@property(nonatomic, copy) NSNumber *loop;
@property(nonatomic, copy) NSNumber *preload;		// PreloadState

@property(nonatomic, copy) NSString *codecType;	// Like Video, we may be able to distinguish specific compatibility levels

@end



