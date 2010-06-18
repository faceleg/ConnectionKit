//
//  SVMediaGatheringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGatheringHTMLContext.h"

#import "KTPublishingEngine.h"


@implementation SVMediaGatheringHTMLContext

- (id)initWithOutputWriter:(id <KSWriter>)writer;
{
    self = [super initWithOutputWriter:writer];
    return self;
}

- (void)dealloc;
{
    [super dealloc];
}

- (void)writeString:(NSString *)string;
{
    // Ignore
}

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL; { return nil; }   // ignore also

@end
