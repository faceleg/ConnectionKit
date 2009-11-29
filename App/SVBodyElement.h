//
//  SVBodyElement.h
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"


@class SVBody;


@interface SVBodyElement :  SVContentObject  

@property (nonatomic, retain) SVBody *enclosingBody;


// Shouldn't really have any need to set this yourself. Use a proper array controller instead please.
@property(nonatomic, copy) NSNumber *sortKey;


@end



