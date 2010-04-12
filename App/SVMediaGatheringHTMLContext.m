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
    _mediaReps = [[NSMutableArray alloc] init];
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
                       width:(NSNumber *)width
                      height:(NSNumber *)height;
{
    SVMediaRepresentation *rep = [[SVMediaRepresentation alloc] initWithMediaRecord:media
                                                                              width:width
                                                                             height:height];
    
    [_mediaReps addObject:rep];
    [rep release];
}

@synthesize mediaRepresentations = _mediaReps;

@end
