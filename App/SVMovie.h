//
//  SVMovie.h
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"


@class SVMediaRecord;


@interface SVMovie : SVMediaGraphic

+ (SVMovie *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;

@property(nonatomic, retain) SVMediaRecord *posterFrame;

@end



