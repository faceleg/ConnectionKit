//
//  SVMediaGatheringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGatheringHTMLContext.h"

#import "SVMediaRepresentation.h"


@implementation SVMediaGatheringHTMLContext

- (id)initWithStringWriter:(id <KSStringWriter>)writer;
{
    self = [super initWithStringWriter:writer];
    _mediaReps = [[NSMutableSet alloc] init];
    return self;
}

- (void)dealloc;
{
    [_mediaReps release];
    [super dealloc];
}

- (void)writeString:(NSString *)string;
{
    // Ignore
}

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSString *)width
                      height:(NSString *)height;
{
    SVMediaRepresentation *rep = [[SVMediaRepresentation alloc] initWithMediaRecord:media];
    [_mediaReps addObject:rep];
}

@synthesize mediaRepresentations = _mediaReps;

@end
