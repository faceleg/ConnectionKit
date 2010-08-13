//
//  SVAudio.h
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"


@class SVMediaRecord;

@interface SVAudio : SVMediaGraphic

+ (SVAudio *)insertNewAudioInManagedObjectContext:(NSManagedObjectContext *)context;

@end



