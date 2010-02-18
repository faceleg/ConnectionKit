//
//  SVPageletBody.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

@class SVBodyElement;
@class SVGraphic;


@interface SVBody : SVContentObject  

+ (SVBody *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;
+ (SVBody *)insertPageletBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;


@property(nonatomic, copy) NSString *string;
@property(nonatomic, copy) NSSet *attachments;


@end