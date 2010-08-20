//
//  SVArchivePage.h
//  Sandvox
//
//  Created by Mike on 20/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTPage.h"


@interface SVArchivePage : NSObject <SVPage>
{
  @private
    KTPage  *_collection;
}

- (id)initWithCollection:(KTPage *)collection;
@property(nonatomic, retain, readonly) KTPage *collection;


@end
