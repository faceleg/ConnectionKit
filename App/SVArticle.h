//
//  SVArticle.h
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVRichText.h"

#import "Sandvox.h"


@class KTPage;

@interface SVArticle : SVRichText

+ (SVArticle *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;

@property (nonatomic, retain, readonly) KTPage *page;


#pragma mark HTML
- (NSUInteger)writeEarlyCallouts:(SVHTMLContext *)context;

@end



