//
//  SVArchivePage.h
//  Sandvox
//
//  Created by Mike on 20/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTPage.h"


@interface SVArchivePage : NSObject <SVPage>
{
  @private
    NSArray *_childPages;
    KTPage  *_collection;
}

- (id)initWithPages:(NSArray *)pages;
@property(nonatomic, retain, readonly) KTPage *collection;

- (NSURL *)URL;
- (NSString *)uploadPath;
- (NSString *)filename;

@end
