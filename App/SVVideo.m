// 
//  SVMovie.m
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVVideo.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"


@implementation SVVideo 

+ (SVVideo *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVVideo *result = [NSEntityDescription insertNewObjectForEntityForName:@"Movie"
                                                    inManagedObjectContext:context];
    return result;
}

@dynamic posterFrame;

- (void)writeBody:(SVHTMLContext *)context;
{
    [context writeHTMLString:@"<p>[[MAKE ME WRITE SOME HTML!]]</p>"];
}

@end
