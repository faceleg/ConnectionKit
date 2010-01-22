//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMedia.h"


@implementation SVMedia

- (id)initWithMediaFile:(KTMediaFile *)mediaFile;
{
    [self init];
    
    _mediaFile = [mediaFile retain];
    _preferredFilename = [[mediaFile preferredFilename] copy];
    
    return self;
}

- (void)dealloc
{
    [_mediaFile release];
    [super dealloc];
}

@synthesize mediaFile = _mediaFile;

@synthesize document = _document;


@synthesize filename = _filename;
@synthesize preferredFilename = _preferredFilename;

@end
