// 
//  SVMovie.m
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMovie.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"


@implementation SVMovie 

+ (SVMovie *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMovie *result = [NSEntityDescription insertNewObjectForEntityForName:@"Movie"
                                                    inManagedObjectContext:context];
    return result;
}

@dynamic posterFrame;

- (void)writeBody;
{
    [[SVHTMLContext currentContext] writeHTMLString:@"<p>[[MAKE ME WRITE SOME HTML!]]</p>"];
}

@end
