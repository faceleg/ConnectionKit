//
//  SVAudio.m
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAudio.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"


@implementation SVAudio

+ (SVAudio *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVAudio *result = [NSEntityDescription insertNewObjectForEntityForName:@"Movie"
                                                    inManagedObjectContext:context];
    return result;
}

@dynamic posterFrame;

- (void)writeBody:(SVHTMLContext *)context;
{
    [context writeHTMLString:@"<p>[[MAKE ME WRITE SOME HTML!]]</p>"];
}

@end
