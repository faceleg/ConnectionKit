//
//  SVIndexPlugIn.h
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVPageletPlugIn.h"


@interface SVIndexPlugIn : SVPlugIn
{
  @private
    id <SVPage> _collection;
}

@property(nonatomic, retain) id <SVPage> indexedCollection;

@end
